import json
import os
import boto3
from datetime import datetime, timezone
from decimal import Decimal
import logging

# Set up logging for CloudWatch
# Use logging.INFO or logging.DEBUG based on verbosity needs
logger = logging.getLogger()
logger.setLevel(logging.INFO) 

# --- Initialization (Runs once during Cold Start) ---
firehose_client = boto3.client('firehose')
FIREHOSE_STREAM_NAME_JSON = os.environ['FIREHOSE_DELIVERY_STREAM_JSON_NAME']
FIREHOSE_STREAM_NAME_PARQUET = os.environ['FIREHOSE_DELIVERY_STREAM_PARQUET_NAME']

# Custom encoder to handle Decimal types (common from DynamoDB Numbers)
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            # Convert Decimal to float/int to match standard JSON number types
            return int(obj) if obj % 1 == 0 else float(obj)
        return json.JSONEncoder.default(self, obj)

# --- Helper Function for DDB Deserialization ---
# Recursively unwraps DDB's verbose JSON structure (e.g., {"S": "value"})
def deserialize_ddb_item(ddb_item):
    if not ddb_item:
        return {}
        
    deserialized_item = {}
    
    for key, value in ddb_item.items():
        if 'S' in value:
            deserialized_item[key] = value['S']
        elif 'N' in value:
            # Keep as Decimal object; DecimalEncoder handles final serialization
            deserialized_item[key] = Decimal(value['N']) 
        elif 'M' in value:
            # Handle nested Maps (Objects)
            deserialized_item[key] = deserialize_ddb_item(value['M'])
        elif 'L' in value:
            # Handle Lists/Arrays
            deserialized_item[key] = [deserialize_ddb_attribute(v) for v in value['L']]
        # Add other types (B, BOOL, NULL) as needed, but skipping for simplicity here
    return deserialized_item

# Helper for list items that may contain nested DDB types
def deserialize_ddb_attribute(ddb_attr):
    if 'S' in ddb_attr: return ddb_attr['S']
    if 'N' in ddb_attr: return Decimal(ddb_attr['N'])
    if 'M' in ddb_attr: return deserialize_ddb_item(ddb_attr['M'])
    if 'L' in ddb_attr: return [deserialize_ddb_attribute(v) for v in ddb_attr['L']]
    return None

def lambda_handler(event, context):
    """
    Transforms DynamoDB stream records into a consistent structure with nested JSON 
    for flexible attributes, then sends a batch to Firehose.
    """
    transformed_records = []
    current_time_utc = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    
    # Log the total number of records received in this batch
    logger.info(f"Received {len(event['Records'])} records from DynamoDB Stream.")

    for record in event['Records']:
        event_name = record['eventName']
        
        # Determine Change Data Capture (CDC) Type
        cdc_type = {'INSERT': 'I', 'MODIFY': 'U', 'REMOVE': 'D'}.get(event_name, 'U')
            
        # We focus on NewImage for INSERT/MODIFY. For DELETE, we capture Keys only.
        new_image_data = record['dynamodb'].get('NewImage')
        
        # Use Keys for DELETE events
        source_data = new_image_data if new_image_data else record['dynamodb'].get('Keys')

        if not source_data:
            continue
            
        # 1. Deserialize the entire DDB item into standard Python dictionary
        user_data = deserialize_ddb_item(source_data)
        
        # --- Create the Consistent Output Schema (Core Fields) ---
        
        # 2. Extract core, known fields (Partition Key and new control fields)
        core_user_id = user_data.pop('user_id', None)
        
        if not core_user_id:
            # Log the dropped record and continue
            logger.warning(f"Skipping record with missing user_id. Event: {event_name}")
            continue
            
        # Initialize the fixed, high-level schema fields
        output_record = {
            'user_id': core_user_id,
            'cdc_type': cdc_type,
            'processing_timestamp': current_time_utc,
            # 3. Store remaining attributes as a semi-structured JSON field
            'user_attributes': user_data
        }
        
        # --- PROFESSIONAL LOGGING: Log the final transformed record ---
        # Note: We use the json.dumps method to correctly format the output record for logging.
        logger.info(f"Processed Record (Type={cdc_type}, ID={core_user_id}): {json.dumps(output_record, cls=DecimalEncoder)}")


        # 4. Serialize the entire output record to JSON and Append Newline
        # The nested 'user_attributes' field will be serialized automatically into the JSON string
        json_data = json.dumps(output_record, cls=DecimalEncoder) + '\n'
        
        # 5. Prepare for Firehose PutRecordBatch API call
        transformed_records.append({
            'Data': json_data.encode('utf-8')
        })

    # Send transformed batch to Kinesis Firehose
    if transformed_records:
        try:
            response = firehose_client.put_record_batch(
                DeliveryStreamName=FIREHOSE_STREAM_NAME_JSON,
                Records=transformed_records
            )
            # Log success and any failed records
            failed_count = response.get('JSON FailedPutCount', 0)
            if failed_count > 0:
                logger.error(f"JSON Firehose delivery failed for {failed_count} records.")
            else:
                logger.info(f"Successfully delivered {len(transformed_records)} records to JSON Firehose.")

        except Exception as e:
            logger.error(f"CRITICAL: Error putting records to JSON Firehose: {e}")
            raise

        try:
            response = firehose_client.put_record_batch(
                DeliveryStreamName=FIREHOSE_STREAM_NAME_PARQUET,
                Records=transformed_records
            )
            # Log success and any failed records
            failed_count = response.get('PARQUET FailedPutCount', 0)
            if failed_count > 0:
                logger.error(f"PARQUET Firehose delivery failed for {failed_count} records.")
            else:
                logger.info(f"Successfully delivered {len(transformed_records)} records to PARQUET Firehose.")

        except Exception as e:
            logger.error(f"CRITICAL: Error putting records to PARQUET Firehose: {e}")
            raise

    return {'statusCode': 200, 'body': f"Processed {len(event['Records'])} records."}
