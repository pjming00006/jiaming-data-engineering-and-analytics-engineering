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

# IAM role for Glue
resource "aws_iam_role" "glue_service_role" {
  name          = "glue-dbt-role"
  description   = "Allow Glue to assume this role for crawler and other data resources required by DBT"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "glue.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
})
}

# Role policy attachment for dbt
resource "aws_iam_role_policy_attachment" "athena_dbt_analytics_policy_glue_service_role_attachment" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = aws_iam_policy.athena_dbt_analytics_policy.arn
}