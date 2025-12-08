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

resource "aws_iam_policy" "emr_service_role_policy" {
  name = "AmazonEMR-ServiceRole-Policy"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CreateInNetwork",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:RunInstances",
                "ec2:CreateFleet",
                "ec2:CreateLaunchTemplate",
                "ec2:CreateLaunchTemplateVersion"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:subnet/${var.emr_public_subnet_id}",
                "arn:aws:ec2:*:*:security-group/${aws_security_group.emr_master_sg.id}",
                "arn:aws:ec2:*:*:security-group/${aws_security_group.emr_core_sg.id}",
                "arn:aws:ec2:*:*:instance/*",
                "arn:aws:ec2:*:*:volume/*"
            ]
        },
        {
            "Sid": "ManageSecurityGroups",
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:security-group/${aws_security_group.emr_master_sg.id}",
                "arn:aws:ec2:*:*:security-group/${aws_security_group.emr_core_sg.id}"
            ]
        },
        {
            "Sid": "CreateDefaultSecurityGroupInVPC",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSecurityGroup"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:vpc/${var.emr_vpc_id}"
            ]
        },
        {
            "Sid": "PassRoleForEC2",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::${var.account_id}:role/service-role/AmazonEMR-InstanceProfile-20251113T214243",
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": "ec2.amazonaws.com"
                }
            }
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "emr_service_role_policy_emr_service_role_attachment" {
  role       = var.emr_service_role_name
  policy_arn = aws_iam_policy.emr_service_role_policy.arn
}
