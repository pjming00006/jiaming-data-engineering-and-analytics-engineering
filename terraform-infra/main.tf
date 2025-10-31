terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }

    archive = {
      source = "hashicorp/archive"
      version = ">= 2.2.0"
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
}

module "dbt_analytics" {
    source = "./dbt_analytics"
    project_aws_region = var.aws_region
    project_etl_s3_bucket_name = var.etl_s3_bucket_name
    glue_service_role_name = module.iam.glue_service_role_name
    glue_service_role_arn = module.iam.glue_service_role_arn
    lambda_service_role_name = module.iam.lambda_service_role_name
    lambda_service_role_arn = module.iam.lambda_service_role_arn
    lambda_root_path = var.lambda_root_path
    lambda_staged_files_path = var.lambda_staged_files_path
    aws_account_id = data.aws_caller_identity.current.account_id
}