# Import the VPC id as variable
# Import proper username and password
# Add EC2 setup scripts

resource "aws_secretsmanager_secret" "docdb_cluster_user_secret" {
  name        = "docdb-client-user-secrets"
  description = "Password for DocumentDB cluster."
}

resource "aws_secretsmanager_secret_version" "docdb_password_version" {
  secret_id     = aws_secretsmanager_secret.docdb_cluster_user_secret.id
  secret_string = jsonencode({
    username = "${var.AWS_DOCDB_USERNAME}"
    password = "${var.AWS_DOCDB_PASSWORD}"
  })
}

resource "aws_security_group" "ec2_ssh_sg" {
  name        = "ec2_ssh_security_group"
  description = "Security group allowing ssh trafic to EC2 instance"
  vpc_id      = var.docdb_vpc_id

  ingress {
    description = ""
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.current_ip_address}/32"]
  }
}

# New sg that bundles inbound and outbound together
resource "aws_security_group" "docdb_sg" {
  name        = "docdb_security_group"
  description = "Security group allowing port 27017 for both inbound and outbound TCP"
  vpc_id      = var.docdb_vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 27017
    to_port          = 27017
    protocol         = "tcp"
    cidr_blocks      = []
    self             = true
  }
}

resource "aws_docdb_subnet_group" "docdb_subnet_group" {
  name       = "docdb-subnet-group"
  subnet_ids = [var.docdb_vpc_public_subnet_id, var.docdb_vpc_private_subnet_id]

  tags = {
    Name = "docdb-subnet-group"
  }
}

resource "aws_docdb_cluster" "docdb" {
  cluster_identifier      = "docdb-cluster"
  engine                  = "docdb"
  master_username         = jsondecode(aws_secretsmanager_secret_version.docdb_password_version.secret_string)["username"]
  master_password         = jsondecode(aws_secretsmanager_secret_version.docdb_password_version.secret_string)["password"]
  skip_final_snapshot     = true
  db_subnet_group_name  = aws_docdb_subnet_group.docdb_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.docdb_sg.id]
  backup_retention_period = 1

  cluster_members         = ["docdb-cluster-instance-1"]
  deletion_protection     = false
  storage_encrypted       = true

  serverless_v2_scaling_configuration {
    max_capacity = 1
    min_capacity = 0.5
  }

  lifecycle {
    ignore_changes = [cluster_members]
  }
}

resource "aws_docdb_cluster_instance" "docdb_cluster_instances" {
  cluster_identifier = aws_docdb_cluster.docdb.id
  instance_class     = "db.serverless"
  promotion_tier     = 1
}

resource "aws_instance" "docdb_client" {
  ami                         = "ami-0e7ccba13ea56beac"
  instance_type               = "t3.nano"
  key_name                    = "docdb-ec2-key"
  vpc_security_group_ids      = [aws_security_group.ec2_ssh_sg.id, aws_security_group.docdb_sg.id]
  subnet_id                   = var.docdb_vpc_public_subnet_id
  associate_public_ip_address = true
  user_data_base64 = base64encode(file("${var.utils_file_path}/docdb_ec2_client_setup.sh"))
  user_data_replace_on_change = true
}

# Policy for DMS to interact with s3
resource "aws_iam_policy" "dms_s3_permission_policy" {
  name = "dms_s3_permission_policy"
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
        # {
        #     "Sid": "",
        #     "Effect": "Allow",
        #     "Action": [
        #         "logs:PutLogEvents"
        #     ],
        #     "Resource": [
        #         # Ensure least privilege - only allow write to specific CloudWatch ARN
        #         "arn:aws:logs:${var.project_aws_region}:${var.aws_account_id}:log-group:/aws/dms/${aws_kinesis_firehose_delivery_stream.lambda-to-s3-json-stream.name}:log-stream:*",
        #         "arn:aws:logs:${var.project_aws_region}:${var.aws_account_id}:log-group:/aws/dms/${aws_kinesis_firehose_delivery_stream.lambda-to-s3-parquet-stream.name}:log-stream:*"
        #     ]
        # },
    ]
  })
}

resource "aws_iam_policy" "dms_secrets_policy" {
  name = "dms_secrets_policy"
  path = "/service-role/"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Resource": [
          "${aws_secretsmanager_secret.docdb_cluster_user_secret.arn}"
        ]
      }
    ]
  })
}

# Role policy attachment for DMS
resource "aws_iam_role_policy_attachment" "dms_s3_permission_policy_dms_service_role_attachment" {
  role       = var.dms_service_role_name
  policy_arn = aws_iam_policy.dms_s3_permission_policy.arn
}

resource "aws_iam_role_policy_attachment" "dms_secrets_policy_dms_service_role_attachment" {
  role       = var.dms_service_role_name
  policy_arn = aws_iam_policy.dms_secrets_policy.arn
}