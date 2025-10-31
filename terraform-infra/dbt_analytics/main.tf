resource "aws_glue_catalog_database" "glub_db_dbt_analytics" {
  name = "dbt-analytics"
  description = "Poc Database for DBT analytics"
}

resource "aws_athena_workgroup" "athena_workgroup_dbt_analytics" {
  name = "athena-workgroup-dbt-analytics"

  configuration {
    enforce_workgroup_configuration = true
    # Do not set output_location as it would overwrite DBT's output structure
    # result_configuration {
    #   output_location = "s3://${var.project_etl_s3_bucket_name}/${var.athena_query_output_prefix}"
    # }

    # 10485760 is the smallest possible value
    bytes_scanned_cutoff_per_query = 10485760

  }
  description = "Athena workgroup for analytics (managed results + per-query cap)"
  state = "ENABLED"
}

resource "aws_iam_policy" "athena_dbt_analytics_policy" {
  name        = "dbt-dev-analytics-policy"
  description = "IAM Policy for dbt developers to run models against Athena and Glue."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "GlueCatalogAccess",
        Effect = "Allow",
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:CreateDatabase",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          # Allows reading the catalog metadata for dbt operations
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchGetPartition",
          "glue:BatchCreatePartition"
        ],
        Resource = [
          "arn:aws:glue:${var.project_aws_region}:${var.aws_account_id}:catalog",
          "arn:aws:glue:${var.project_aws_region}:${var.aws_account_id}:database/${aws_glue_catalog_database.glub_db_dbt_analytics.name}", 
          # Gives DBT access to read source tables from other databases
          "arn:aws:glue:${var.project_aws_region}:${var.aws_account_id}:database/*",
          # Gives permissions to work with tables
          "arn:aws:glue:${var.project_aws_region}:${var.aws_account_id}:table/${aws_glue_catalog_database.glub_db_dbt_analytics.name}/*"
        ]
      },
      {
        Sid    = "AthenaExecution",
        Effect = "Allow",
        Action = [
          "athena:StartQueryExecution",
          "athena:StopQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:ListQueryExecutions",
          "athena:GetWorkGroup",
        ],
        Resource = "arn:aws:athena:${var.project_aws_region}:${var.aws_account_id}:workgroup/${aws_athena_workgroup.athena_workgroup_dbt_analytics.name}"
      },
      {
        Sid    = "S3DataAccess",
        Effect = "Allow",
        Action = [
          "s3:GetObject",     
          "s3:ListBucket",    
          "s3:PutObject",     
          "s3:DeleteObject", 
          "s3:GetBucketLocation"
        ],
        Resource = [
          "arn:aws:s3:::${var.project_etl_s3_bucket_name}",
          "arn:aws:s3:::${var.project_etl_s3_bucket_name}/*"
        ]
      },
      {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "logs:PutLogEvents"
            ],
            "Resource": [
                # Ensure least privilege - only allow write to specific CloudWatch ARN
                "arn:aws:logs:${var.project_aws_region}:${var.aws_account_id}:log-group:/aws-glue/crawlers:log-stream:*",
            ]
        },
    ]
  })
}

resource "aws_iam_policy" "start_all_crawler_policy" {
  # This policy allows AWS lambda to write to a specific firehose stream
  name = "startAllCrawlerPolicy"
  path = "/service-role/"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {   
            "Effect": "Allow",
            "Action": "glue:StartCrawler",
            "Resource": "*"
        }
    ]
})
}

# Role policy attachment for dbt
resource "aws_iam_role_policy_attachment" "athena_dbt_analytics_policy_glue_service_role_attachment" {
  role       = var.glue_service_role_name
  policy_arn = aws_iam_policy.athena_dbt_analytics_policy.arn
}

# Role policy attachment for lambda to start crawler
resource "aws_iam_role_policy_attachment" "start_crawler_policy_lambda_service_role_attachment" {
  role       = var.lambda_service_role_name
  policy_arn = aws_iam_policy.start_all_crawler_policy.arn
}

# Package the Lambda function code
data "archive_file" "trigger_crawler_function_file" {
  type        = "zip"
  source_file = "${var.lambda_root_path}/trigger_crawler_user_parquet.py"
  output_path = "${var.lambda_staged_files_path}/trigger_crawler_user_parquet.zip"
}

# Lambda function to trigger crawler
resource "aws_lambda_function" "lambda_trigger_crawler" {
  filename         = data.archive_file.trigger_crawler_function_file.output_path
  function_name    = "trigger_crawler_user_parquet"
  role             = var.lambda_service_role_arn
  handler          = "trigger_crawler_user_parquet.lambda_handler"
  source_code_hash = data.archive_file.trigger_crawler_function_file.output_base64sha256

  architectures    = ["arm64"]

  runtime = "python3.13"

  environment {
    variables = {
      USER_PARQUET_GLUE_CRAWLER_NAME = "${aws_glue_crawler.glue_crawler_ddb_user_parquet.name}",
    }
  }
}

resource "aws_cloudwatch_event_rule" "user_parquet_s3_file_drop_rule" {
  name        = "suser_parquet_s3_file_drop_trigger"
  description = "Trigger Lambda when file is uploaded to specific S3 prefix"
  event_pattern = jsonencode({
    "source" : ["aws.s3"],
    "detail-type" : ["Object Created"],
    "detail" : {
      "bucket" : {
        "name" : [var.project_etl_s3_bucket_name]
      },
      "object" : {
        "key" : [{
          "prefix" : "${var.ddb_user_parquet_s3_drop_location}/"
        }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.user_parquet_s3_file_drop_rule.name
  arn       = aws_lambda_function.lambda_trigger_crawler.arn
}

# Give EventBridge permission to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_trigger_crawler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.user_parquet_s3_file_drop_rule.arn
}