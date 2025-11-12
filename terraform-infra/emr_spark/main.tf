resource "aws_security_group" "emr_master_sg" {
  name   = "emr-master-sg"
  vpc_id = var.emr_vpc_id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "core_to_master" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.emr_core_sg.id
  security_group_id        = aws_security_group.emr_master_sg.id
}

resource "aws_security_group_rule" "master_to_core" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.emr_master_sg.id
  security_group_id        = aws_security_group.emr_core_sg.id
}
