# Networking module - Day 1 stub
# TODO: Implement full networking stack in Day 2

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Placeholder VPC - will be implemented in Day 2
resource "null_resource" "networking_placeholder" {
  triggers = {
    environment = var.environment
  }
}

# For Day 1, we'll use data sources to reference default VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = data.aws_vpc.default.id
}