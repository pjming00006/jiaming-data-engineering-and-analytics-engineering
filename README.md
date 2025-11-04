Project 1: ETL pipeline to move data from AWS DynamoDB to S3

Project Highlights:
1. Light weight arthitecture: dynamodb table -> dynamodb streams -> AWS Lambda transformation -> AWS firehose buffering -> s3 destination with date partitions -> Glue catalog and crawler -> Athena DBT Analytics
2. Event driven triggers:
   2a. Dynamodb Streams trigger Lambda function for processing records
   2b. New file creations in s3 trigger Lambda function to start crawler
3. Fully managed infrastructure using Terraform, including soure databases, all event triggers, and destination data catalog

Project 2: ETL pipeline to move data from AWS DocumentDB(Mongo) to S3 uinsg Data Migration Services(DMS)

Project Highlights:
Fully managed infrastructure using Terraform, including VPC, subnets, source/target/network endpoints, DocumentDB clusters, DMS instance
