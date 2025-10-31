variable "project_aws_region" {
  description = "AWS region for this project"
  type        = string
}

variable "project_etl_s3_bucket_name" {
  description = "s3 bucket name"
  type        = string
}

variable "ddb_user_parquet_s3_drop_location" {
  type = string
}

variable "lambda_root_path" {
  type = string
}

variable "glue_service_role_name" {
  type = string
}

variable "glue_service_role_arn" {
  type = string
}

variable "lambda_service_role_name" {
  type = string
}

variable "lambda_service_role_arn" {
  type = string
}

variable "lambda_staged_files_path" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "athena_query_output_prefix" {
  type = string
  default = "dbt-analytics-queries/"
}