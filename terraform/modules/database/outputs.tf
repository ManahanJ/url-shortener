output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = "localhost:5432" # Placeholder for Day 1
  sensitive   = true
}

output "db_port" {
  description = "RDS instance port"
  value       = 5432
}

output "db_name" {
  description = "Database name"
  value       = var.db_name
}