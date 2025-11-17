from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import boto3

# Function to read and print S3 file
def read_s3_file():
    s3 = boto3.client('s3')
    bucket_name = 'your-bucket-name'
    key = 'path/to/your/file.txt'
    
    obj = s3.get_object(Bucket=bucket_name, Key=key)
    content = obj['Body'].read().decode('utf-8')
    print("File content:\n", content)

# DAG definition
with DAG(
    dag_id='s3_read_test',
    start_date=datetime(2025, 11, 16),
    schedule_interval=None,  # manual trigger
    catchup=False,
) as dag:

    task_read_s3 = PythonOperator(
        task_id='read_s3_file',
        python_callable=read_s3_file
    )

    task_read_s3
