# IAM role for firehose
resource "aws_iam_role" "firehose_service_role_lambda" {
  name = "KinesisFirehoseServiceRole-lambda"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "firehose.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
  })
}

output "firehose_service_role_name" {
  value = aws_iam_role.firehose_service_role_lambda.name
}

output "firehose_service_role_arn" {
  value = aws_iam_role.firehose_service_role_lambda.arn
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_service_role" {
  name          = "lambda-dynamoDB-firehose-poc-role"
  description   = "Allows Lambda functions to call AWS services on your behalf, and send data to firehose"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
  })
}

output "lambda_service_role_name" {
  value = aws_iam_role.lambda_service_role.name
}

output "lambda_service_role_arn" {
  value = aws_iam_role.lambda_service_role.arn
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


output "glue_service_role_name" {
  value = aws_iam_role.glue_service_role.name
}

output "glue_service_role_arn" {
  value = aws_iam_role.glue_service_role.arn
}

# IAM role for dms - documentdb -> dms -> s3 pipeline
resource "aws_iam_role" "dms_service_role" {
  name = "dms-service-role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": ["dms.amazonaws.com", "dms.us-east-1.amazonaws.com"]
            },
            "Action": "sts:AssumeRole"
        },
    ]
  })
}

# This IAM role is required for DMS to create a aws_dms_replication_subnet_group
# The name dms-vpc-role is required and cannot be changed
resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "dms.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        },
    ]
  })
}


resource "aws_iam_role_policy_attachment" "vpc_management_dms_vpc_role_attachment" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

output "dms_service_role_id" {
  value = aws_iam_role.dms_service_role.id
}

output "dms_service_role_name" {
  value = aws_iam_role.dms_service_role.name
}

output "dms_service_role_arn" {
  value = aws_iam_role.dms_service_role.arn
}


# IAM role for EMR
resource "aws_iam_role" "emr_service_role" {
  name = "emr-service-role"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "elasticmapreduce.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        },
    ]
  })
}

resource "aws_iam_policy" "emr_service_pass_role_to_ec2_policy" {
  # This policy allows AWS lambda to write to a specific firehose stream
  name = "emr_service_pass_role_to_ec2_policy"
  path = "/service-role/"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PassRoleForEC2",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::${var.account_id}:role/service-role/${aws_iam_role.emr_ec2_instance_role.name}",
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": "ec2.amazonaws.com"
                }
            }
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "emr_service_permission_emr_service_role_attachment" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

resource "aws_iam_role_policy_attachment" "emr_policy_v2_emr_service_role_attachment" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRServicePolicy_v2"
}

resource "aws_iam_role_policy_attachment" "pass_role_emr_service_role_attachment" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = aws_iam_policy.emr_service_pass_role_to_ec2_policy.arn
}

# IAM role for EC2 instances used by EMR
resource "aws_iam_role" "emr_ec2_instance_role" {
  name = "emr-ec2-instance-role"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
})
}

resource "aws_iam_role_policy_attachment" "emr_ec2_permission_emr_ec2_instance_role_attachment" {
  role       = aws_iam_role.emr_ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

# Wrapper for the IAM role. EC2 would use this
resource "aws_iam_instance_profile" "emr_ec2_instance_profile" {
  name = "emr_ec2_instance_profile"
  role = aws_iam_role.emr_ec2_instance_role.name
}

# IAM for using emr steps
resource "aws_iam_role" "emr_step_role" {
  name = "emr-step-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" = "Allow"
        "Principal" = { 
          "Service" = "elasticmapreduce.amazonaws.com"
        },
        "Action"   = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "emr_step_permission_emr_step_role_attachment" {
  role       = aws_iam_role.emr_step_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}