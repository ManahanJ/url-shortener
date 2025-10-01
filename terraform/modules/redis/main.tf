# Secure Redis Module - Day 2 Implementation
# ElastiCache Redis with encryption at rest and in transit

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Subnet group for Redis cluster - private subnets only
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.environment}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.environment}-redis-subnet-group"
    Type = "cache"
  })
}

# Security group for Redis - no public access
resource "aws_security_group" "redis" {
  name_prefix = "${var.environment}-redis-"
  vpc_id      = var.vpc_id
  description = "Security group for Redis cluster - private access only"

  ingress {
    description     = "Redis from application security group only"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  egress {
    description = "No outbound access needed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-redis-sg"
    Type = "cache"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# KMS Key for Redis encryption
resource "aws_kms_key" "redis" {
  description             = "KMS key for Redis encryption - ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.environment}-redis-key"
    Type = "cache"
  })
}

resource "aws_kms_alias" "redis" {
  name          = "alias/${var.environment}-redis-key"
  target_key_id = aws_kms_key.redis.key_id
}

# Redis parameter group for optimization
resource "aws_elasticache_parameter_group" "main" {
  family = "redis7.x"
  name   = "${var.environment}-redis-params"

  # Optimize for cache workload
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  parameter {
    name  = "tcp-keepalive"
    value = "60"
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-redis-params"
    Type = "cache"
  })
}

# Redis replication group with encryption
resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.environment}-redis"
  description                = "Redis cluster for ${var.environment} environment"

  # Redis configuration
  node_type            = var.node_type
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.main.name

  # Cluster configuration
  num_cache_clusters = var.num_cache_nodes

  # Multi-AZ for production
  automatic_failover_enabled = var.environment == "prod" ? true : false
  multi_az_enabled          = var.environment == "prod" ? true : false

  # Network configuration - PRIVATE ONLY
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  # Encryption configuration - REQUIRED
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id                 = aws_kms_key.redis.arn

  # Auth token for additional security
  auth_token                 = var.auth_token
  auth_token_update_strategy = "ROTATE"

  # Backup configuration
  snapshot_retention_limit = var.backup_retention_days
  snapshot_window         = var.backup_window
  maintenance_window      = var.maintenance_window

  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  # Notifications
  notification_topic_arn = aws_sns_topic.redis_alerts.arn

  # Engine version and updates
  engine_version       = "7.0"
  auto_minor_version_upgrade = true

  tags = merge(var.common_tags, {
    Name = "${var.environment}-redis"
    Type = "cache"
  })

  depends_on = [aws_cloudwatch_log_group.redis_slow]
}

# CloudWatch Log Group for Redis slow logs
resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/redis/${var.environment}/slow-log"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.environment}-redis-slow-logs"
    Type = "cache"
  })
}

# SNS Topic for Redis alerts
resource "aws_sns_topic" "redis_alerts" {
  name = "${var.environment}-redis-alerts"

  tags = merge(var.common_tags, {
    Name = "${var.environment}-redis-alerts"
    Type = "monitoring"
  })
}

# CloudWatch Alarms for Redis monitoring
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${var.environment}-redis-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Redis CPU utilization"
  alarm_actions       = [aws_sns_topic.redis_alerts.arn]

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.main.replication_group_id}-001"
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-redis-cpu-alarm"
    Type = "monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${var.environment}-redis-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Redis memory utilization"
  alarm_actions       = [aws_sns_topic.redis_alerts.arn]

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.main.replication_group_id}-001"
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-redis-memory-alarm"
    Type = "monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "redis_connections" {
  alarm_name          = "${var.environment}-redis-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "This metric monitors Redis connection count"
  alarm_actions       = [aws_sns_topic.redis_alerts.arn]

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.main.replication_group_id}-001"
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-redis-connections-alarm"
    Type = "monitoring"
  })
}

# Redis backup monitoring
resource "aws_cloudwatch_metric_alarm" "redis_backup_failed" {
  alarm_name          = "${var.environment}-redis-backup-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ReplicationLag"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "30"
  alarm_description   = "This metric monitors Redis replication lag"
  alarm_actions       = [aws_sns_topic.redis_alerts.arn]

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.main.replication_group_id}-001"
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-redis-replication-alarm"
    Type = "monitoring"
  })
}