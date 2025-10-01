variable "environment" {
  description = "Environment name"
  type        = string
}

variable "node_type" {
  description = "The compute and memory capacity of the nodes"
  type        = string
}

variable "num_cache_nodes" {
  description = "The initial number of cache nodes"
  type        = number
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Application security group ID"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "auth_token" {
  description = "Auth token for Redis authentication"
  type        = string
  sensitive   = true
  default     = null
}

variable "backup_retention_days" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 5
}

variable "backup_window" {
  description = "Daily time range for backups in UTC (HH:MM-HH:MM)"
  type        = string
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  description = "Weekly time range for maintenance in UTC (ddd:HH:MM-ddd:HH:MM)"
  type        = string
  default     = "sun:05:00-sun:09:00"
}