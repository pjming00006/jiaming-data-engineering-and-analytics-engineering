resource "aws_glue_catalog_database" "glub_db_ddb_lambda_firehose_s3_poc" {
  name = "ddb-lambda-firehose-s3-etl-poc-db"
  description = "PoC database for ddb - lambda - firehose - s3 project"
}

resource "aws_glue_catalog_table" "glub_table_user_parquent" {
  name          = "user_parquet"
  database_name = aws_glue_catalog_database.glub_db_ddb_lambda_firehose_s3_poc.name
  description   = "ddb user table schema in parquet"
  table_type    = "EXTERNAL_TABLE"

  parameters    = {
    classification = "parquet"
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }

  storage_descriptor {
    compressed = false
    input_format              = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format             = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    location                  = "s3://etl-poc-2025-b8a9c11/dynamo-lambda-firehose-s3-etl-parquet/"
    additional_locations      = []
    bucket_columns            = []
    number_of_buckets         = 0
    parameters                = {}
    stored_as_sub_directories = false

    columns {
      name       = "user_id"
      parameters = {}
      type       = "string"
    }

    columns {
      name       = "cdc_type"
      parameters = {}
      type       = "string"
    }

    columns {
      name       = "processing_timestamp"
      parameters = {}
      type       = "string"
    }

    columns {
      name       = "user_attributes"
      parameters = {}
      type       = "string"
    }

    ser_de_info {
      parameters = {
        "serialization.format" = "1"
      }
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }
  }
}

resource "aws_iam_policy" "glue_permission_policy" {
  # This policy allows AWS lambda to write to a specific firehose stream
  name = "glue_get_database_and_table"
  path = "/service-role/"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                      "glue:GetDatabase",
                      "glue:GetTable",
                      "glue:GetTableVersion",
                      "glue:GetTableVersions",
            ],
            "Resource": [
              "arn:aws:glue:${var.project_aws_region}:${var.aws_account_id}:catalog",
              "arn:aws:glue:${var.project_aws_region}:${var.aws_account_id}:database/${aws_glue_catalog_database.glub_db_ddb_lambda_firehose_s3_poc.name}",
              "arn:aws:glue:${var.project_aws_region}:${var.aws_account_id}:table/${aws_glue_catalog_database.glub_db_ddb_lambda_firehose_s3_poc.name}/${aws_glue_catalog_table.glub_table_user_parquent.name}",
            ]

        }
    ]
})
}

# Role policy attachment for firehose for Glue permissions
resource "aws_iam_role_policy_attachment" "glue_permission_policy_firehose_service_role_attachment" {
  role       = aws_iam_role.firehose_service_role_lambda.name
  policy_arn = aws_iam_policy.glue_permission_policy.arn
}


resource "aws_kinesis_firehose_delivery_stream" "lambda-to-s3-parquet-stream" {
  name        = "lambda-to-s3-parquet-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_service_role_lambda.arn
    # bucket_arn          = aws_s3_bucket.etl_s3_bucket.arn
    bucket_arn          = var.project_etl_s3_bucket_arn
    error_output_prefix = "error-data/"
    prefix              = "dynamo-lambda-firehose-s3-etl-parquet/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    buffering_interval  = 60
    buffering_size      = 64

    data_format_conversion_configuration {
      input_format_configuration {
        deserializer {
          open_x_json_ser_de {}
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {}
        }
      }

      schema_configuration {
        database_name = aws_glue_catalog_database.glub_db_ddb_lambda_firehose_s3_poc.name
        table_name = aws_glue_catalog_table.glub_table_user_parquent.name
        role_arn = aws_iam_role.firehose_service_role_lambda.arn
      }
    }
  }

}