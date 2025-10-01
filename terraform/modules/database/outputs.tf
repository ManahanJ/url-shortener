# Database Module Outputs - Day 2 Enhanced
# Comprehensive outputs for monitoring and connectivity

# Core Database Information
output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "db_endpoint" {
  description = "RDS instance endpoint for application connections"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "Database master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

# Network Information
output "db_security_group_id" {
  description = "Security group ID for database access"
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "Database subnet group name"
  value       = aws_db_subnet_group.main.name
}

# Encryption and Security
output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = aws_kms_key.rds.id
}

output "kms_key_arn" {
  description = "KMS key ARN used for encryption"
  value       = aws_kms_key.rds.arn
}

output "kms_alias_name" {
  description = "KMS key alias for easy reference"
  value       = aws_kms_alias.rds.name
}

# Monitoring and Alerting
output "sns_topic_arn" {
  description = "SNS topic ARN for backup alerts"
  value       = aws_sns_topic.backup_alerts.arn
}

output "backup_verify_lambda_arn" {
  description = "Backup verification Lambda function ARN"
  value       = aws_lambda_function.backup_verify.arn
}

output "backup_verify_schedule_arn" {
  description = "EventBridge rule ARN for backup verification schedule"
  value       = aws_cloudwatch_event_rule.backup_verify.arn
}

# CloudWatch Resources
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for RDS logs"
  value       = aws_cloudwatch_log_group.rds.name
}

output "cpu_alarm_arn" {
  description = "CloudWatch alarm ARN for high CPU utilization"
  value       = aws_cloudwatch_metric_alarm.database_cpu.arn
}

output "connections_alarm_arn" {
  description = "CloudWatch alarm ARN for high connection count"
  value       = aws_cloudwatch_metric_alarm.database_connections.arn
}

# Backup Information
output "backup_retention_period" {
  description = "Backup retention period in days"
  value       = aws_db_instance.main.backup_retention_period
}

output "backup_window" {
  description = "Backup window in UTC"
  value       = aws_db_instance.main.backup_window
}

output "maintenance_window" {
  description = "Maintenance window"
  value       = aws_db_instance.main.maintenance_window
}

# Performance and Monitoring
output "performance_insights_enabled" {
  description = "Whether Performance Insights is enabled"
  value       = aws_db_instance.main.performance_insights_enabled
}

output "monitoring_role_arn" {
  description = "IAM role ARN for enhanced monitoring"
  value       = aws_iam_role.rds_monitoring.arn
}

# Connection String Template (for documentation)
output "connection_string_template" {
  description = "Template for database connection string"
  value       = "postgres://${aws_db_instance.main.username}:PASSWORD@${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}?sslmode=require"
  sensitive   = true
}

# Environment Information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "deletion_protection_enabled" {
  description = "Whether deletion protection is enabled"
  value       = aws_db_instance.main.deletion_protection
}

output "multi_az_enabled" {
  description = "Whether Multi-AZ deployment is enabled"
  value       = aws_db_instance.main.multi_az
}

output "storage_encrypted" {
  description = "Whether storage encryption is enabled"
  value       = aws_db_instance.main.storage_encrypted
}

# Tags
output "applied_tags" {
  description = "Tags applied to the database instance"
  value       = aws_db_instance.main.tags_all
}