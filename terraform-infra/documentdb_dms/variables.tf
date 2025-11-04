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

variable "dms_service_role_id" {
  type = string
}

variable "dms_service_role_name" {
  type = string
}

variable "dms_service_role_arn" {
  type = string
}

variable "dms_subnet_group_ids" {
  type = list
}

variable "aws_account_id" {
  type = string
}

variable "AWS_DOCDB_USERNAME" {
    type = string
    sensitive = true
    default = "my_docdb_username"
}

variable "AWS_DOCDB_PASSWORD" {
    type = string
    sensitive = true
    default = "my_docdb_password"
}

variable "utils_file_path" {
  type = string
  default = "../utils"
}

variable "current_ip_address" {
  type = string
}

variable "docdb_vpc_id" {
  type = string
}

variable "docdb_vpc_public_subnet_id" {
  type = string
}

variable "docdb_vpc_private_subnet_id" {
  type = string
}

variable "project_tag" {
  type = string
}