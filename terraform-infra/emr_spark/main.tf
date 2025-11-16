# EMR primary node security group. The ingress and egress rules are created specific to the VPC and subnet, managed by EMR
resource "aws_security_group" "emr_master_sg" {
  name        = "ElasticMapReduce-master"
  vpc_id      = var.emr_vpc_id
  description = "Master group for Elastic MapReduce created on 2025-11-11T21:31:43.452Z"

  lifecycle {
    ignore_changes = [ 
      egress,
      ingress
      ]
  }
}

# EMR core node security group. The ingress and egress rules are created specific to the VPC and subnet, managed by EMR
resource "aws_security_group" "emr_core_sg" {
  name        = "ElasticMapReduce-slave"
  vpc_id      = var.emr_vpc_id
  description = "Slave group for Elastic MapReduce created on 2025-11-11T21:31:43.452Z"

    lifecycle {
    ignore_changes = [ 
      egress,
      ingress
      ]
  }
}
