terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # version = "~> 5.92"
      version = "~> 6.10"
    }

    archive = {
      source = "hashicorp/archive"
      version = ">= 2.2.0"
    }

    external = {
      source = "hashicorp/external"
      version = ">= 2.3.5"
    }
  }

  required_version = ">= 1.2"
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

module "s3_datalake" {
  source = "./s3_datalake"
  etl_s3_bucket_name = var.etl_s3_bucket_name
}

module "iam" {
  source = "./iam"
}

data "external" "myipaddr" {
program = ["bash", "-c", "curl -s 'https://api.ipify.org?format=json'"]
}

module "dynamodb_etl" {
    source = "./dynamodb_etl"
    project_aws_region = var.aws_region
    project_etl_s3_bucket_name = var.etl_s3_bucket_name
    project_etl_s3_bucket_arn = module.s3_datalake.etl_s3_bucket_arn
    firehose_service_role_name =  module.iam.firehose_service_role_name
    firehose_service_role_arn = module.iam.firehose_service_role_arn
    lambda_service_role_name = module.iam.lambda_service_role_name
    lambda_service_role_arn = module.iam.lambda_service_role_arn
    lambda_root_path = var.lambda_root_path
    lambda_staged_files_path = var.lambda_staged_files_path
    aws_account_id = data.aws_caller_identity.current.account_id
    project_tag = var.project_tag
}

module "dbt_analytics" {
    source = "./dbt_analytics"
    project_aws_region = var.aws_region
    project_etl_s3_bucket_name = var.etl_s3_bucket_name
    ddb_user_parquet_s3_drop_location = module.dynamodb_etl.ddb_user_parquet_s3_drop_location
    glue_service_role_name = module.iam.glue_service_role_name
    glue_service_role_arn = module.iam.glue_service_role_arn
    lambda_service_role_name = module.iam.lambda_service_role_name
    lambda_service_role_arn = module.iam.lambda_service_role_arn
    lambda_root_path = var.lambda_root_path
    lambda_staged_files_path = var.lambda_staged_files_path
    aws_account_id = data.aws_caller_identity.current.account_id
    project_tag = var.project_tag
}

module "documentdb_dms" {
  source = "./documentdb_dms"
  project_aws_region =  var.aws_region
  project_etl_s3_bucket_name =  var.etl_s3_bucket_name
  project_etl_s3_bucket_arn = module.s3_datalake.etl_s3_bucket_arn
  dms_service_role_id = module.iam.dms_service_role_id
  dms_service_role_name = module.iam.dms_service_role_name
  aws_account_id = data.aws_caller_identity.current.account_id
  project_tag = var.project_tag
  current_ip_address = data.external.myipaddr.result.ip
  docdb_vpc_id = module.vpc.docdb_vpc_id
  docdb_vpc_public_subnet_id = module.vpc.docdb_vpc_public_subnet_id
  docdb_vpc_private_subnet_id = module.vpc.docdb_vpc_private_subnet_id
  utils_file_path = var.utils_file_path
}

module "vpc" {
  source = "./vpc"
}