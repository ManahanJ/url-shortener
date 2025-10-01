# Redis module - Day 1 stub
# TODO: Implement full ElastiCache stack in Day 2

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Placeholder for ElastiCache Redis - will be implemented in Day 2
resource "null_resource" "redis_placeholder" {
  triggers = {
    environment   = var.environment
    node_type    = var.node_type
  }
}