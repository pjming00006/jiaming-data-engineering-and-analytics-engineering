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

variable "aws_account_id" {
  type = string
}

variable "project_tag" {
  type = string
}