terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source for current AWS account info
data "aws_caller_identity" "current" {}

# Common tags
locals {
  common_tags = {
    Project     = "url-shortener"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# VPC and networking
module "networking" {
  source = "../../modules/networking"

  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = data.aws_availability_zones.available.names
  common_tags        = local.common_tags
}

# RDS PostgreSQL instance
module "database" {
  source = "../../modules/database"

  environment          = var.environment
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password

  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  app_security_group_id = module.networking.app_security_group_id

  common_tags = local.common_tags
}

# ElastiCache Redis instance
module "redis" {
  source = "../../modules/redis"

  environment     = var.environment
  node_type       = var.redis_node_type
  num_cache_nodes = var.redis_num_cache_nodes

  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  app_security_group_id = module.networking.app_security_group_id

  common_tags = local.common_tags
}