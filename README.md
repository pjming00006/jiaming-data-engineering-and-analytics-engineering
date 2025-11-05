**Quick Links:**

If you're interested in learning about Jiaming's skills and expertise in:
1. **Data modeling(star schema) and DBT ELT workflows**, check out these [DBT models](https://github.com/pjming00006/jiaming-data-engineering-and-analytics-engineering/tree/main/dbt-analytics/athena_dbt_analytics/models/curated). The DBT curated zone illustrates Slowly Changing Dimension type 1 and type 2
2. **Developing backend batch ETL workflows using fully managed AWS services**, check this [DynamoDB stream to S3 project](https://github.com/pjming00006/jiaming-data-engineering-and-analytics-engineering/tree/main/terraform-infra/dynamodb_etl) 
3. **Provisioning and manageing cloud infrastructure resources for DE workflows**, explore this [DocumentDB DMS project](https://github.com/pjming00006/jiaming-data-engineering-and-analytics-engineering/tree/main/terraform-infra/documentdb_dms) where everything from VPC, subnets, security groups, clusters, replication instances, and endpoints are created and managed with least privilage principles

   

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
