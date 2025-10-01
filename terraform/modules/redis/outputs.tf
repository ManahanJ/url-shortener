output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = "localhost:6379" # Placeholder for Day 1
  sensitive   = true
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = 6379
}