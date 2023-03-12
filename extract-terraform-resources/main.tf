########################################################################################################################
# Providers                                                                                                            #
########################################################################################################################
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = aws_eks_cluster.aws_eks.arn
  #host                   = data.aws_eks_cluster.aws_eks.endpoint
  #cluster_ca_certificate = base64decode(aws_eks_cluster.aws_eks.certificate_authority[0].data)
  #token                  = data.aws_eks_cluster_auth.aws_eks.token
}

provider "kubectl" {
  config_path    = "~/.kube/config"
  config_context = aws_eks_cluster.aws_eks.arn
  #host                   = data.aws_eks_cluster.aws_eks.endpoint
  #cluster_ca_certificate = base64decode(aws_eks_cluster.aws_eks.certificate_authority[0].data)
  #token                  = data.aws_eks_cluster_auth.aws_eks.token
  #load_config_file       = false
}

provider "aws" {
  #access_key = var.aws_access_key
  #secret_key = var.aws_secret_key
  region     = local.region
}


provider "aws" {
  alias      = "us-east-1"
  #access_key = var.aws_access_key
  #secret_key = var.aws_secret_key
  region     = "us-east-1"
}


########################################################################################################################
# Datasources                                                                                                          #
########################################################################################################################
data "aws_eks_cluster" "aws_eks" {
  name = local.eks_cluster_name

  depends_on = [aws_eks_cluster.aws_eks, aws_eks_node_group.node]
}

data "aws_eks_cluster_auth" "aws_eks" {
  name = local.eks_cluster_name

  depends_on = [aws_eks_cluster.aws_eks, aws_eks_node_group.node]
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}


########################################################################################################################
# VPC                                                                                                                  #
########################################################################################################################
resource "aws_vpc" "default" {
  cidr_block           = local.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    {
      Name        = "${local.name}/VPC",
      Project     = var.project,
      Environment = local.environment
    },
    var.tags
  )
}

locals {
  action=file("${path.module}/action.txt")
}


########################################################################################################################
# flow log                                                                                                             #
########################################################################################################################
/*
## CloudWatch Logging
resource "aws_flow_log" "alero" {
  iam_role_arn    = aws_iam_role.alero_flow_log.arn
  log_destination = aws_cloudwatch_log_group.alero_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.default.id
}

resource "aws_cloudwatch_log_group" "alero_flow_log" {
  name = "${local.name}-flow-log"
}

resource "aws_iam_role" "alero_flow_log" {
  name = "${local.name}-flow-log"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "alero_flow_log" {
  name = "${local.name}-flow-log"
  role = aws_iam_role.alero_flow_log.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
*/

## S3 Logging
resource "aws_flow_log" "alero_s3_flow_log" {
  log_destination      = module.alero_flow_log_bucket.bucket.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.default.id

  tags = merge(
  {
    Name        = "${local.name}-s3-flow-log",
    Project     = var.project,
    Environment = local.environment
  },
  var.tags
  )
}


########################################################################################################################
# key_pair                                                                                                             #
########################################################################################################################
resource "tls_private_key" "alero_key_pair" {
  algorithm = "RSA"
}

module "alero_key_pair" {
  source = "terraform-aws-modules/key-pair/aws"
  key_name   = local.name
  public_key = tls_private_key.alero_key_pair.public_key_openssh

  tags = merge(
  {
    Project     = var.project,
    Environment = local.environment
  },
  var.tags
  )
}

resource "aws_ebs_encryption_by_default" "ebs_encryption" {
  enabled = true
}
