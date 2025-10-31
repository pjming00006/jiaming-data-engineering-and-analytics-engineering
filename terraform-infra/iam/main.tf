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