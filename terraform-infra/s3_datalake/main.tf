# s3 bucket
resource "aws_s3_bucket" "etl_s3_bucket" {
  bucket = var.etl_s3_bucket_name
}

# s3 bucket notification to EventBridge - this is for the dbt analytics project
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket      = aws_s3_bucket.etl_s3_bucket.id
  eventbridge = true
}

# S3 Best Practice: Block all public access for security
resource "aws_s3_bucket_public_access_block" "data_lake_acl" {
  bucket = aws_s3_bucket.etl_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "etl_s3_bucket_arn" {
  value = aws_s3_bucket.etl_s3_bucket.arn
}