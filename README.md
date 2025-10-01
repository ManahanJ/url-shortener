# URL Shortener Service

A production-minded TinyURL-style service in Go demonstrating Infrastructure as Code (IaC), caching strategies, rate limiting, schema migrations, and comprehensive developer experience.

## Project Overview

This project implements a complete URL shortener service showcasing modern DevOps and software engineering practices:

- **Go HTTP Service** with health, shorten, and resolve endpoints
- **PostgreSQL Database** with Flyway migrations for schema management
- **Redis Cache** for fast URL resolution and rate limiting
- **Infrastructure as Code (IaC)** with Terraform for AWS deployment
- **Comprehensive Developer Experience** with linting, testing, pre-commit hooks
- **Local Development** support with Docker Compose
- **Automated backup strategy** with cloud-native features

## Architecture

- **Application**: Go HTTP service with gin framework
- **Database**: PostgreSQL (AWS RDS for production, Docker for local)
- **Cache**: Redis (AWS ElastiCache for production, Docker for local)
- **Migration Tool**: Flyway for schema versioning
- **Infrastructure**: Terraform for AWS resources
- **Local Development**: Docker Compose with hot reload
- **Rate Limiting**: Redis-backed sliding window rate limiter
- **Backup Strategy**: Daily automated backups with 7-day retention + manual backup scripts

## Implementation Guide

### 1. Terraform Infrastructure Overview

The Terraform configuration should include these key files:

```
terraform/
├── main.tf              # Provider and main resources
├── variables.tf         # Input variables
├── outputs.tf          # Output values
├── rds.tf              # RDS instance and related resources
├── iam.tf              # IAM roles and policies
├── backup.tf           # Backup configuration
└── networking.tf       # VPC, subnets, security groups
```

**Key Resources:**
- `aws_db_instance` - PostgreSQL RDS instance
- `aws_db_subnet_group` - Database subnet group
- `aws_security_group` - Database security group
- `aws_db_parameter_group` - Database parameter group
- `aws_iam_role` - Backup execution role
- `aws_lambda_function` - Manual backup function
- `aws_cloudwatch_event_rule` - Backup scheduling

### 2. Example Terraform RDS Configuration

```hcl
# terraform/rds.tf
resource "aws_db_instance" "url_shortener_db" {
  identifier = "url-shortener-db"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type         = "gp2"
  storage_encrypted    = true

  db_name  = "urlshortener"
  username = var.db_master_username
  password = var.db_master_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = false
  final_snapshot_identifier = "url-shortener-db-final-snapshot"

  tags = {
    Name = "URL Shortener Database"
    Environment = var.environment
  }
}

resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "url-shortener-db-params"

  parameter {
    name  = "log_statement"
    value = "all"
  }
}

# Create application user
resource "postgresql_role" "app_user" {
  name     = "app_user"
  login    = true
  password = var.app_db_password
}

resource "postgresql_grant" "app_user_tables" {
  database    = aws_db_instance.url_shortener_db.db_name
  role        = postgresql_role.app_user.name
  schema      = "public"
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE"]
}
```

### 3. Backup Strategy Implementation

```bash
#!/bin/bash
# scripts/backup.sh - Manual backup script

DB_HOST="${DB_HOST:-your-rds-endpoint}"
DB_NAME="${DB_NAME:-urlshortener}"
DB_USER="${DB_USER:-postgres}"
BACKUP_BUCKET="${BACKUP_BUCKET:-your-backup-bucket}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="urlshortener_backup_${TIMESTAMP}.sql"

echo "Creating database backup..."
pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" > "/tmp/$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Uploading backup to S3..."
    aws s3 cp "/tmp/$BACKUP_FILE" "s3://$BACKUP_BUCKET/backups/$BACKUP_FILE"

    echo "Cleaning up local backup file..."
    rm "/tmp/$BACKUP_FILE"

    echo "Backup completed successfully: $BACKUP_FILE"
else
    echo "Backup failed!"
    exit 1
fi
```

**Terraform Lambda for Automated Backups:**

```hcl
# terraform/backup.tf
resource "aws_lambda_function" "backup_function" {
  filename         = "backup_lambda.zip"
  function_name    = "url-shortener-backup"
  role            = aws_iam_role.lambda_backup_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      DB_HOST = aws_db_instance.url_shortener_db.endpoint
      S3_BUCKET = aws_s3_bucket.backup_bucket.bucket
    }
  }
}

resource "aws_cloudwatch_event_rule" "daily_backup" {
  name                = "daily-backup"
  description         = "Trigger backup daily"
  schedule_expression = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
}
```

### 4. Flyway Migration Scripts

**V1__create_tables.sql:**
```sql
-- V1__create_tables.sql
CREATE TABLE urls (
    id SERIAL PRIMARY KEY,
    original_url TEXT NOT NULL,
    short_code VARCHAR(10) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add check constraint to ensure URLs are not empty
ALTER TABLE urls ADD CONSTRAINT urls_original_url_not_empty
    CHECK (LENGTH(TRIM(original_url)) > 0);

-- Add check constraint for short_code format
ALTER TABLE urls ADD CONSTRAINT urls_short_code_format
    CHECK (short_code ~ '^[a-zA-Z0-9]+$');
```

**V2__add_index.sql:**
```sql
-- V2__add_index.sql
CREATE INDEX idx_urls_short_code ON urls(short_code);

-- Add index on created_at for analytics queries
CREATE INDEX idx_urls_created_at ON urls(created_at);

-- Add partial index for frequently accessed URLs
CREATE INDEX idx_urls_recent ON urls(created_at)
    WHERE created_at > (CURRENT_TIMESTAMP - INTERVAL '30 days');
```

### 5. Local Development with Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:15.4
    container_name: url_shortener_db
    environment:
      POSTGRES_DB: urlshortener
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: localdev123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - url_shortener_network

  flyway:
    image: flyway/flyway:9.22
    container_name: url_shortener_flyway
    volumes:
      - ./migrations:/flyway/sql
      - ./flyway.conf:/flyway/conf/flyway.conf
    depends_on:
      - postgres
    networks:
      - url_shortener_network
    profiles:
      - migration

volumes:
  postgres_data:

networks:
  url_shortener_network:
    driver: bridge
```

**Flyway Configuration (flyway.conf):**
```properties
flyway.url=jdbc:postgresql://postgres:5432/urlshortener
flyway.user=postgres
flyway.password=localdev123
flyway.locations=filesystem:/flyway/sql
flyway.baselineOnMigrate=true
```

### 6. Migration Commands

**Local Development:**
```bash
# Start PostgreSQL
docker-compose up -d postgres

# Run migrations
docker-compose --profile migration run --rm flyway migrate

# Check migration status
docker-compose --profile migration run --rm flyway info

# Reset database (development only)
docker-compose --profile migration run --rm flyway clean
docker-compose --profile migration run --rm flyway migrate
```

**Production Deployment:**
```bash
# Using Flyway CLI
flyway -url=jdbc:postgresql://your-rds-endpoint:5432/urlshortener \
       -user=flyway_user \
       -password=$FLYWAY_PASSWORD \
       -locations=filesystem:./migrations \
       migrate

# Using Docker
docker run --rm -v $(pwd)/migrations:/flyway/sql \
  flyway/flyway:9.22 \
  -url=jdbc:postgresql://your-rds-endpoint:5432/urlshortener \
  -user=flyway_user \
  -password=$FLYWAY_PASSWORD \
  migrate
```

### 7. Development Scripts

Create a `scripts/` directory with helper scripts:

```bash
# scripts/dev-setup.sh
#!/bin/bash
echo "Starting local development environment..."
docker-compose up -d postgres
sleep 10
echo "Running migrations..."
docker-compose --profile migration run --rm flyway migrate
echo "Development environment ready!"

# scripts/reset-db.sh
#!/bin/bash
echo "Resetting local database..."
docker-compose --profile migration run --rm flyway clean
docker-compose --profile migration run --rm flyway migrate
echo "Database reset complete!"
```

## Best Practices & Production Readiness

### Security
- Store sensitive values in AWS Secrets Manager/Parameter Store
- Use IAM roles instead of hardcoded credentials
- Enable SSL/TLS for database connections
- Implement least-privilege access principles
- Regular security updates for all components

### Monitoring & Observability
- Enable CloudWatch monitoring for RDS
- Set up alerts for backup failures
- Monitor migration execution
- Log all database operations

### Performance
- Implement connection pooling
- Monitor query performance
- Set appropriate database parameters
- Regular VACUUM and ANALYZE operations

### Development Workflow
- Use feature branches for schema changes
- Test migrations on staging environment
- Implement rollback procedures
- Document all schema changes

## Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd url-shortener
   ```

2. **Set up local development**
   ```bash
   chmod +x scripts/dev-setup.sh
   ./scripts/dev-setup.sh
   ```

3. **Deploy to AWS**
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

4. **Run production migrations**
   ```bash
   ./scripts/deploy-migrations.sh production
   ```

## Project Structure

```
url-shortener/
├── README.md
├── docker-compose.yml
├── flyway.conf
├── migrations/
│   ├── V1__create_tables.sql
│   └── V2__add_index.sql
├── scripts/
│   ├── backup.sh
│   ├── dev-setup.sh
│   └── reset-db.sh
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── rds.tf
    ├── backup.tf
    └── iam.tf
```

## Contributing

1. Create feature branch for schema changes
2. Test locally with Docker Compose
3. Submit PR with migration scripts
4. Deploy to staging for testing
5. Deploy to production after approval