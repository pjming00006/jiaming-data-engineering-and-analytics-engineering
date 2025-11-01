resource "aws_glue_crawler" "glue_crawler_ddb_user_parquet" {
  database_name = aws_glue_catalog_database.glub_db_dbt_analytics.name
  name          = "glue-crawler-ddb-user-parquet"
  role          = var.glue_service_role_arn

  configuration = jsonencode({
    CreatePartitionIndex = true
    Version              = 1
  })

  s3_target {
    path = "s3://${var.project_etl_s3_bucket_name}/dynamo-lambda-firehose-s3-etl-parquet/"
  }

  tags = {
    project = var.project_tag
  }
}