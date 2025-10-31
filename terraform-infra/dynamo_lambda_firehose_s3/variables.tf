variable "project_aws_region" {
  description = "AWS region for this project"
  type        = string
}

variable "project_etl_s3_bucket_name" {
  description = "s3 bucket name"
  type        = string
}

variable "project_etl_s3_bucket_arn" {
  description = "s3 bucket arn"
  type        = string
}

variable "firehose_service_role_name" {
  type        = string
}

variable "firehose_service_role_arn" {
  type        = string
}

variable "lambda_service_role_name" {
  type        = string
}

variable "lambda_service_role_arn" {
  type        = string
}

variable "project_tag_name" {
  description = "tags for AWS resources under this project"
  type        = string
  default     = "ddb-lambda-firehose-s3-etl-poc-project"
}

variable "lambda_root_path" {
  type = string
}

variable "lambda_staged_files_path" {
  type = string
}

variable "aws_account_id" {
  type = string
}