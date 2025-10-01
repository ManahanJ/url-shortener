output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "database_port" {
  description = "RDS instance port"
  value       = module.database.db_port
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.redis.redis_endpoint
  sensitive   = true
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = module.redis.redis_port
}