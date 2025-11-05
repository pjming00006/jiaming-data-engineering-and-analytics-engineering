resource "aws_security_group" "emr_master_sg" {
  name   = "emr-master-sg"
  vpc_id = var.emr_vpc_id

  # Allow outbound to all (workers, S3)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "emr_core_sg" {
  name   = "emr-core-sg"
  vpc_id = var.emr_vpc_id

  # Allow outbound to master SG
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.emr_master_sg.id]
  }
}
