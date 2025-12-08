variable "emr_vpc_id" {
  type = string
}

variable "emr_public_subnet_id" {
  type = string
}

variable "account_id" {
  type = string
}

variable "emr_service_role_name" {
  type = string
}

variable "emr_ec2_instance_role_arn" {
  type = string
}

variable "emr_ec2_instance_role_name" {
  type = string
}

variable "project_etl_s3_bucket_name" {
  type = string
}