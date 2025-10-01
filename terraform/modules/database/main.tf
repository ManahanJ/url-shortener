# Database module - Day 1 stub
# TODO: Implement full RDS stack in Day 2

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Placeholder for RDS instance - will be implemented in Day 2
resource "null_resource" "database_placeholder" {
  triggers = {
    environment = var.environment
    db_name     = var.db_name
  }
}