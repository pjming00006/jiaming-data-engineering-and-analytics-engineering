# If an resource is imported, the local name change would trigger a re-creation of the resource becuae terraform sees it as old resource deprecation
# terraform state mv aws_iam_policy.policy aws_iam_policy.firehose_permission_policy

resource "aws_iam_policy" "firehose_permission_policy" {
  # This policy allows AWS firehose to write to specific s3 bucket and CloudWatch. No Lambda invocation permission needed because firehose is on the receiving end
  name = "KinesisFirehoseServicePolicy-lambda-to-s3"
  path = "/service-role/"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {  
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::${var.project_etl_s3_bucket_name}",
                "arn:aws:s3:::${var.project_etl_s3_bucket_name}/*"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "logs:PutLogEvents"
            ],
            "Resource": [
                # Ensure least privilege - only allow write to specific CloudWatch ARN
                "arn:aws:logs:${var.project_aws_region}:${var.aws_account_id}:log-group:/aws/kinesisfirehose/${aws_kinesis_firehose_delivery_stream.lambda-to-s3-json-stream.name}:log-stream:*",
            ]
        },
    ]
})
}

resource "aws_iam_policy" "lambda_permission_policy" {
  # This policy allows AWS lambda to write to a specific firehose stream
  name = "lambda-write-to-firehose-lambda-to-s3-json-stream"
  path = "/service-role/"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "firehose:PutRecordBatch",
            "Resource": "arn:aws:firehose:${var.project_aws_region}:${var.aws_account_id}:deliverystream/${aws_kinesis_firehose_delivery_stream.lambda-to-s3-json-stream.name}"
        }
    ]
})
}

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

# Role policy attachment for firehose
resource "aws_iam_role_policy_attachment" "firehose_permission_policy_firehose_service_role_lambda_attachment" {
  role       = aws_iam_role.firehose_service_role_lambda.name
  policy_arn = aws_iam_policy.firehose_permission_policy.arn
}

# Role policy attachment for lambda for lambda permissions
resource "aws_iam_role_policy_attachment" "AWSLambdaDynamoDBExecutionRole_lambda_service_role_attachment" {
  role       = aws_iam_role.firehose_service_role_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaDynamoDBExecutionRole"
}

# Role policy attachment for lambda for firehose permissions
resource "aws_iam_role_policy_attachment" "lambda_permission_policy_lambda_service_role_attachment" {
  role       = aws_iam_role.lambda_service_role.name
  policy_arn = aws_iam_policy.lambda_permission_policy.arn
}

resource "aws_s3_bucket" "etl_s3_bucket" {
  bucket = var.project_etl_s3_bucket_name
}

# S3 Best Practice: Block all public access for security
resource "aws_s3_bucket_public_access_block" "data_lake_acl" {
  bucket = aws_s3_bucket.etl_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "dynamodb_user_table" {
  name             = "user"
  hash_key         = "user_id"
  billing_mode     = "PAY_PER_REQUEST" # On-Demand (low cost)
  table_class      = "STANDARD"

  attribute {
    name = "user_id"
    type = "S" # String
  }

  # Enable DynamoDB Streams for Change Data Capture (CDC)
  stream_enabled   = true
  # NEW_AND_OLD_IMAGES is required to fully capture changes for DDB->Lambda transform
  stream_view_type = "NEW_AND_OLD_IMAGES"
}


resource "aws_kinesis_firehose_delivery_stream" "lambda-to-s3-json-stream" {
  name        = "lambda-to-s3-json-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_service_role_lambda.arn
    bucket_arn          = aws_s3_bucket.etl_s3_bucket.arn
    error_output_prefix = "error-data/"
    prefix              = "dynamo-lambda-firehose-s3-etl-json/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    buffering_interval  = 60
    buffering_size      = 1
  }
}

# Package the Lambda function code
data "archive_file" "example" {
  type        = "zip"
  source_file = "${var.lambda_root_path}/dynamodb-to-firehose-user-poc.py"
  output_path = "${var.lambda_staged_files_path}/dynamodb-to-firehose-user-poc.zip"
}

# Lambda function
resource "aws_lambda_function" "lambda-process-ddb-stream" {
  filename         = data.archive_file.example.output_path
  function_name    = "dynamodb-to-firehose-user-poc"
  role             = aws_iam_role.lambda_service_role.arn
  handler          = "dynamodb-to-firehose-user-poc.lambda_handler"
  source_code_hash = data.archive_file.example.output_base64sha256

  architectures    = ["arm64"]

  runtime = "python3.13"

  environment {
    variables = {
      FIREHOSE_DELIVERY_STREAM_NAME = "${aws_kinesis_firehose_delivery_stream.lambda-to-s3-json-stream.name}"
    }
  }
}