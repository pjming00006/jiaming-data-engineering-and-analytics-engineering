resource "aws_vpc" "docdb_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "poc-vpc"
  }
}

# Create an Internet Gateway for outbound internet access
resource "aws_internet_gateway" "docdb_vpc_igw" {
  vpc_id = aws_vpc.docdb_vpc.id

  tags = {
    Name = "poc-igw"
  }
}

# Create a public subnet
resource "aws_subnet" "docdb_vpc_public_subnet" {
  vpc_id                  = aws_vpc.docdb_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true  # auto-assign public IPs to EC2s

  tags = {
    Name = "poc-public-subnet"
  }
}

# Private subnet for DocumentDB
resource "aws_subnet" "docdb_vpc_private_subnet" {
  vpc_id                  = aws_vpc.docdb_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "poc-private-subnet"
  }
}

# Create a route table for the subnet
resource "aws_route_table" "docdb_vpc_public_subnet_route_table" {
  vpc_id = aws_vpc.docdb_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.docdb_vpc_igw.id
  }

  tags = {
    Name = "poc-public-rt"
  }
}

# Associate subnet with route table
resource "aws_route_table_association" "docdb_vpc_subnet_assoc" {
  subnet_id      = aws_subnet.docdb_vpc_public_subnet.id
  route_table_id = aws_route_table.docdb_vpc_public_subnet_route_table.id
}

output "docdb_vpc_id" {
    value = aws_vpc.docdb_vpc.id
}

output "docdb_vpc_public_subnet_id" {
    value = aws_subnet.docdb_vpc_public_subnet.id
}

output "docdb_vpc_private_subnet_id" {
    value = aws_subnet.docdb_vpc_private_subnet.id
}