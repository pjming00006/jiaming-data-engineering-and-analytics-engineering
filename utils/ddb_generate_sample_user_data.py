import json
import random
from datetime import datetime, timedelta
import pprint

RECORD_COUNTS = 25
DDB_TABLE_NAME = 'user'
DDB_REQUEST_TYPE = 'PutRequest'
OUTPUT_FILENAME = '../data/ddb_user_insert_data.json'

pk_col = 'user_id'
attr_cols = [
    {'name': 'program_start_date', 'type': 'S',    'min': '2020-01-01', 'max': '2025-10-01'}, 
    {'name': 'partner_id',         'type': 'S',    'min': 2000, 'max': 2005}, 
    {'name': 'program_id',         'type': 'S',    'min': 90, 'max': 110}, 
    {'name': 'client_name',        'type': 'S',    'min': None, 'max': None}, 
    {'name': 'test_status',        'type': 'BOOL', 'min': None, 'max': None},
             ]

def generate_random_pk(n, min_val, max_val):
    # PK cannot be duplicates
    if n > (max_val - min_val):
        raise ValueError('Range size is smaller than required count')
    
    return random.sample(range(min_val, max_val + 1), n)

def generate_random_attr(attr_name, min_val=None, max_val=None):
    if attr_name == 'program_start_date':
        min_date = datetime.strptime(min_val, "%Y-%m-%d").date()
        max_date = datetime.strptime(max_val, "%Y-%m-%d").date()
        date_diff = (max_date - min_date).days
        rand_day = random.randint(0, date_diff)
        return str(min_date + timedelta(days=rand_day))
    elif attr_name in ['partner_id', 'program_id']:
        return str(random.randint(min_val, max_val))
    elif attr_name == 'test_status':
        return random.choice([True, False])
    elif attr_name == 'client_name':
        return random.choice(['aws', 'azure', 'gcp', 'ali cloud', 'oracle cloud'])
    

if __name__ == '__main__':
    print(f"Generating {RECORD_COUNTS} sample records...")

    pks = generate_random_pk(RECORD_COUNTS, 101, 200)
    data_out = []
    for pk in pks:
        item = {
            DDB_REQUEST_TYPE: {
                "Item": {
                    pk_col: {"S": str(pk)}
                }
            }
        }

        for attr in attr_cols:
            attr_name = attr['name']
            val = generate_random_attr(attr_name, attr['min'], attr['max'])
            item[DDB_REQUEST_TYPE]['Item'][attr_name] = {attr['type']: val}
        
        data_out.append(item)

    complete_request_body = {DDB_TABLE_NAME: data_out}
    # pprint.pprint(complete_request_body)

    try:
        with open(OUTPUT_FILENAME, 'w') as f:
            # json.dump(data_to_save, file_object, optional_formatting_arguments)
            json.dump(complete_request_body, f, indent=4)
            
        print(f"Successfully saved data to {OUTPUT_FILENAME}")

    except IOError as e:
        print(f"An error occurred while writing to the file: {e}")




