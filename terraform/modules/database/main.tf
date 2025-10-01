# RDS PostgreSQL Database Module with Backup and Security
# Day 2: Production-ready with encryption, backups, and monitoring

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# DB Subnet Group for private subnets
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-${var.db_name}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.db_name}-subnet-group"
    Type = "database"
  })
}

# DB Parameter Group for PostgreSQL optimization
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${var.environment}-${var.db_name}-params"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries taking more than 1 second
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.db_name}-params"
    Type = "database"
  })
}

# Security Group for RDS - No public access
resource "aws_security_group" "rds" {
  name_prefix = "${var.environment}-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS PostgreSQL - private access only"

  ingress {
    description = "PostgreSQL from application subnets only"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.app_subnet_cidrs
  }

  egress {
    description = "No outbound access needed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-rds-sg"
    Type = "database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption - ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.environment}-rds-key"
    Type = "database"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.environment}-rds-key"
  target_key_id = aws_kms_key.rds.key_id
}

# RDS Instance with encryption and automated backups
resource "aws_db_instance" "main" {
  identifier = "${var.environment}-${var.db_name}"

  # Engine configuration
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  # Storage configuration with encryption
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_encrypted     = true
  kms_key_id           = aws_kms_key.rds.arn
  storage_type         = "gp3"

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network configuration - PRIVATE ONLY
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Backup configuration - Daily with 7-day retention
  backup_retention_period = 7
  backup_window          = "03:00-04:00" # UTC - 11 PM EST
  maintenance_window     = "Sun:04:00-Sun:05:00"
  copy_tags_to_snapshot  = true

  # Enhanced monitoring and performance insights
  monitoring_interval             = 60
  monitoring_role_arn            = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled   = true
  performance_insights_retention_period = 7

  # Security and compliance
  parameter_group_name = aws_db_parameter_group.main.name
  deletion_protection  = var.environment == "prod" ? true : false
  skip_final_snapshot  = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${var.environment}-${var.db_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Logging
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.db_name}"
    Type = "database"
  })

  depends_on = [aws_cloudwatch_log_group.rds]
}

# CloudWatch Log Group for RDS logs
resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/instance/${var.environment}-${var.db_name}/postgresql"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.environment}-rds-logs"
    Type = "database"
  })
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.environment}-rds-monitoring-role"
    Type = "database"
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Backup verification Lambda function
resource "aws_lambda_function" "backup_verify" {
  filename         = "${path.module}/backup_verify.zip"
  function_name    = "${var.environment}-backup-verify"
  role            = aws_iam_role.backup_verify_lambda.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 300

  environment {
    variables = {
      DB_IDENTIFIER = aws_db_instance.main.identifier
      ENVIRONMENT   = var.environment
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-backup-verify"
    Type = "backup"
  })

  depends_on = [data.archive_file.backup_verify]
}

# Lambda deployment package
data "archive_file" "backup_verify" {
  type        = "zip"
  output_path = "${path.module}/backup_verify.zip"
  source {
    content = templatefile("${path.module}/backup_verify.py", {
      db_identifier = "${var.environment}-${var.db_name}"
    })
    filename = "index.py"
  }
}

# IAM Role for backup verification Lambda
resource "aws_iam_role" "backup_verify_lambda" {
  name = "${var.environment}-backup-verify-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.environment}-backup-verify-lambda-role"
    Type = "backup"
  })
}

resource "aws_iam_role_policy" "backup_verify_lambda" {
  name = "${var.environment}-backup-verify-lambda-policy"
  role = aws_iam_role.backup_verify_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBSnapshots",
          "rds:DescribeDBInstances",
          "rds:RestoreDBInstanceFromDBSnapshot",
          "rds:DeleteDBInstance"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.backup_alerts.arn
      }
    ]
  })
}

# EventBridge rule for daily backup verification
resource "aws_cloudwatch_event_rule" "backup_verify" {
  name                = "${var.environment}-backup-verify"
  description         = "Trigger backup verification daily"
  schedule_expression = "cron(0 6 * * ? *)" # 6 AM UTC daily

  tags = merge(var.common_tags, {
    Name = "${var.environment}-backup-verify-schedule"
    Type = "backup"
  })
}

resource "aws_cloudwatch_event_target" "backup_verify" {
  rule      = aws_cloudwatch_event_rule.backup_verify.name
  target_id = "BackupVerifyLambdaTarget"
  arn       = aws_lambda_function.backup_verify.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_verify.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.backup_verify.arn
}

# SNS Topic for backup alerts
resource "aws_sns_topic" "backup_alerts" {
  name = "${var.environment}-backup-alerts"

  tags = merge(var.common_tags, {
    Name = "${var.environment}-backup-alerts"
    Type = "monitoring"
  })
}

# CloudWatch Alarms for database monitoring
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.environment}-database-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.backup_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-database-cpu-alarm"
    Type = "monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "${var.environment}-database-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "This metric monitors RDS connection count"
  alarm_actions       = [aws_sns_topic.backup_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-database-connections-alarm"
    Type = "monitoring"
  })
}