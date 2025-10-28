variable "aws_region" {
  description = "AWS region for this project"
  type        = string
  default     = "us-east-1"
}

variable "etl_s3_bucket_name" {
  description = "s3 bucket name"
  type        = string
  default     = "etl-poc-2025-b8a9c11"
}

variable "lambda_root_path" {
  description = "value"
  type = string
  default = "../lambda"
}

variable "lambda_staged_files_path" {
  description = "value"
  type = string
  default = "../lambda/staged_files"
}