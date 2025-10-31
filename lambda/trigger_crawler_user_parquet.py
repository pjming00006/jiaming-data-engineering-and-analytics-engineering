import json
import boto3
import os

glue_client = boto3.client('glue')

CRAWLER_NAME = os.environ['USER_PARQUET_GLUE_CRAWLER_NAME']

def lambda_handler(event, context):
    print("Received S3 event: " + json.dumps(event, indent=2))

    try:
        response = glue_client.start_crawler(Name=CRAWLER_NAME)
        print(f"Successfully started Glue Crawler '{CRAWLER_NAME}'. Response: {response}")
        return {
            'statusCode': 200,
            'body': json.dumps('Glue Crawler started successfully')
        }
    except glue_client.exceptions.CrawlerRunningException:
        # Handle case where crawler is already running
        print(f"Glue Crawler '{CRAWLER_NAME}' is already running. Skipping trigger.")
        return {
            'statusCode': 200,
            'body': json.dumps('Glue Crawler already running')
        }
    except Exception as e:
        print(f"Error starting Glue Crawler: {e}")
        raise e
