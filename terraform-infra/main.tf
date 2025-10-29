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

module "dynamo_lambda_firehose_s3" {
    source = "./dynamo_lambda_firehose_s3"
    project_aws_region = var.aws_region
    project_etl_s3_bucket_name = var.etl_s3_bucket_name
    lambda_root_path = var.lambda_root_path
    lambda_staged_files_path = var.lambda_staged_files_path
    aws_account_id = data.aws_caller_identity.current.account_id
}

module "dbt_analytics" {
    source = "./dbt_analytics"
    project_aws_region = var.aws_region
    project_etl_s3_bucket_name = var.etl_s3_bucket_name
    aws_account_id = data.aws_caller_identity.current.account_id
}