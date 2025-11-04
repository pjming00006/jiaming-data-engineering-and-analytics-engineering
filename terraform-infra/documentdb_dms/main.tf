/*
Resource Overview: In this project, the main target is to configure a DocumentDB cluster and and Data Migration Service instance to migrate data to s3. In addition,
we need to be able to connect to the DocumentDB cluster and write some sample data into the database

Prerequisites Overview:
1. DocumentDB is not a service fully managed by AWS; therefore, we would need to manage our own network and compute infrastructures
2. DocumentDB does not allow direct access from the Internet; therefore, we would need a EC2 instance within the same VPC to serve as DB client
3. Similarly, DMS resources must be placed within the same network; for best practices, DMS instances shouldn't be exposed to public subnets

Prerequisites Details:
1. A dedicated VPC for the project
2. The VPC should have 1 public subnet and at least 2 private subnet. DocumentDB cluster and its instance(minnimum 1) reside in each of the private subnets
3. A VPC security group allowing inbound traffic to port 27017(mongodb), and inbound traffic for ssh(port 22) from user ip
4  An VPC s3 endpoint allowing DMS to interact with s3 within the private subnet
5. A DocumentDB cluster and 1 storage instance. Use provisioned resources, for ease of testing. The cluster uses the VPC created
6. An EC2 instance using the same VPC. Use an older version of Ubuntu for mongo compatibility
7. DMS source and target endpoint for DocumentDB cluster and s3
8. DMS replication instance lieveraging the endpoints; use provisioned resources for ease of testing
9. The actual replication task is not managed here since it's created by the replication instance; delete it after use to prevent recurring costs

Resource dependencies:
- For s3 bucket and related resources, see terraform-infra/s3_datalake
- For networking resources like VPC and subnets, see terraform-infra/vpc
- For IAM service role resources, see terraform-infra/iam(policy and attachment are managed under project module instead)
*/

locals {
  high_cost_resource_tag = "High Cost"
}

resource "aws_secretsmanager_secret" "docdb_cluster_user_secret" {
  name        = "docdb-client-user-secrets"
  description = "Password for DocumentDB cluster."
}

resource "aws_secretsmanager_secret_version" "docdb_password_version" {
  secret_id     = aws_secretsmanager_secret.docdb_cluster_user_secret.id
  secret_string = jsonencode({
    username    = "${var.AWS_DOCDB_USERNAME}"
    password    = "${var.AWS_DOCDB_PASSWORD}"
    engine      = "docdb",
    port        = 27017,
    dbname      = "mydb"
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
    cidr_blocks = ["${var.current_ip_address}/32"] # Allowing ssh from current ip
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
  deletion_protection     = false
  storage_encrypted       = true

  lifecycle {
    ignore_changes = [master_username, master_password]
  }

  tags = {
    project = var.project_tag
    cost    = local.high_cost_resource_tag
  }
}

# Cluster member(s)
resource "aws_docdb_cluster_instance" "docdb_instance_1" {
  identifier          = "docdb-cluster-instance-1"
  cluster_identifier  = aws_docdb_cluster.docdb.id
  instance_class      = "db.t3.medium"      # choose any supported provisioned instance class
  engine              = "docdb"

  tags = {
    project = var.project_tag
    cost    = local.high_cost_resource_tag
  }
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

  tags = {
    project = var.project_tag
    cost    = local.high_cost_resource_tag
  }
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
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        "Resource": [
          "${aws_secretsmanager_secret.docdb_cluster_user_secret.arn}",
          "*"
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

# Configure a subnet group for dms
resource "aws_dms_replication_subnet_group" "dms_subnet_group" {
  replication_subnet_group_id = "dms-subnet-group"
  subnet_ids = var.dms_subnet_group_ids
  replication_subnet_group_description = "DMS subnet group for serverless instance"
}

resource "aws_dms_s3_endpoint" "s3_target_endpoint" {
  endpoint_id      = "s3-target-endpoint"
  endpoint_type    = "target"
  bucket_name      = var.project_etl_s3_bucket_name
  service_access_role_arn = var.dms_service_role_arn

  # Additional settings for format, compression, folder prefix
  bucket_folder    = "documentdb_user_setting"
  data_format      = "csv"
  compression_type = "gzip"
}

resource "aws_dms_endpoint" "docdb_source_endpoint" {
  endpoint_id                     = "docdb-source-endpoint"
  endpoint_type                   = "source"
  engine_name                     = "docdb"

  port                            = 27017
  ssl_mode                        = "verify-full"
  certificate_arn                 = "arn:aws:dms:us-east-1:906180857104:cert:U56ZCBG3DBEZHNYXPZXW6EEEOE"
  database_name                   = "mydb"
  server_name                     = aws_docdb_cluster.docdb.endpoint
  username                        = jsondecode(aws_secretsmanager_secret_version.docdb_password_version.secret_string)["username"]
  password                        = jsondecode(aws_secretsmanager_secret_version.docdb_password_version.secret_string)["password"]
}

resource "aws_vpc_endpoint" "etl_vpc_s3_endpoint" {
  vpc_id            = var.docdb_vpc_id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"

  private_dns_enabled = false

  tags = {
    Name = "dms-s3-private-endpoint"
  }
}

resource "aws_dms_replication_instance" "dms_docdb_instance" {
  replication_instance_id   = "docdb-dms-replication-instance"
  replication_instance_class = "dms.t3.micro"
  publicly_accessible       = true
  vpc_security_group_ids    = [aws_security_group.docdb_sg.id]
  replication_subnet_group_id = aws_dms_replication_subnet_group.dms_subnet_group.id

  tags = {
    project = var.project_tag
    cost    = local.high_cost_resource_tag
  }
}
