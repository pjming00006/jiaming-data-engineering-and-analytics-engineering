resource "aws_vpc" "de_etl_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "de-etl-vpc"
  }
}

# Create an Internet Gateway for outbound internet access
resource "aws_internet_gateway" "de_etl_vpc_igw" {
  vpc_id = aws_vpc.de_etl_vpc.id

  tags = {
    Name = "de-etl-igw"
  }
}

# Create a public subnet
resource "aws_subnet" "de_etl_vpc_public_subnet" {
  vpc_id                  = aws_vpc.de_etl_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true  # auto-assign public IPs to EC2s

  tags = {
    Name = "de-etl-public-subnet"
  }
}

# Private subnet for DocumentDB
resource "aws_subnet" "de_etl_vpc_private_subnet" {
  vpc_id                  = aws_vpc.de_etl_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "de-etl-private-subnet_1"
  }
}

# Second private subnet required for a minimum dms poc
resource "aws_subnet" "de_etl_vpc_private_subnet_2" {
  vpc_id                  = aws_vpc.de_etl_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = false

  tags = {
    Name = "de-etl-private-subnet_2"
  }
}

# Create a route table for the subnet
resource "aws_route_table" "de_etl_vpc_public_subnet_route_table" {
  vpc_id = aws_vpc.de_etl_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.de_etl_vpc_igw.id
  }

  tags = {
    Name = "de-etl-public-rt"
  }
}

resource "aws_route_table" "de_etl_vpc_private_subnet_route_table" {
  vpc_id = aws_vpc.de_etl_vpc.id

  tags = {
    Name = "de-etl-private-rt"
  }
}

# Associate subnet with route table
resource "aws_route_table_association" "docdb_vpc_subnet_assoc" {
  subnet_id      = aws_subnet.de_etl_vpc_public_subnet.id
  route_table_id = aws_route_table.de_etl_vpc_public_subnet_route_table.id
}

resource "aws_vpc_endpoint" "etl_vpc_s3_endpoint" {
  vpc_id            = aws_vpc.de_etl_vpc.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.de_etl_vpc_private_subnet_route_table.id
  ]

  private_dns_enabled = false

  tags = {
    Name = "s3-private-endpoint"
  }
}

output "docdb_vpc_id" {
    value = aws_vpc.de_etl_vpc.id
}

output "de_etl_vpc_public_subnet_id" {
    value = aws_subnet.de_etl_vpc_public_subnet.id
}

output "de_etl_vpc_private_subnet_id" {
    value = aws_subnet.de_etl_vpc_private_subnet.id
}

output "private_subnet_ids" {
  value = [aws_subnet.de_etl_vpc_private_subnet.id, aws_subnet.de_etl_vpc_private_subnet_2.id]
}