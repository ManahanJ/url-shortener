# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a complete URL shortener service in Go demonstrating Infrastructure as Code (IaC) and production-ready development practices. The project uses:

- **Go HTTP Service** with gin framework for REST API
- **PostgreSQL** as the database (AWS RDS for production, Docker for local development)
- **Redis** for caching and rate limiting (AWS ElastiCache for production, Docker for local)
- **Terraform** for infrastructure provisioning
- **Flyway** for database schema migrations
- **Docker Compose** for local development environment

## Architecture

The project follows a layered approach:

1. **Application Layer** (`cmd/`, `internal/`): Go HTTP service with REST API handlers
2. **Infrastructure Layer** (`terraform/`): AWS RDS, ElastiCache, security groups, IAM roles, backup automation
3. **Schema Layer** (`migrations/`): Flyway migration scripts managing database schema evolution
4. **Local Development** (`docker-compose.yml`): Containerized PostgreSQL, Redis, and Go app with hot reload
5. **Automation** (`scripts/`, `Makefile`): Backup scripts, linting, testing, development environment setup

Core database schema centers around a `urls` table with columns:
- `id` (SERIAL PRIMARY KEY)
- `original_url` (TEXT)
- `short_code` (VARCHAR(10) UNIQUE)
- `created_at`, `updated_at` (TIMESTAMP WITH TIME ZONE)

## Development Commands

### Local Environment Setup
```bash
# Start local PostgreSQL database
docker-compose up -d postgres

# Run all migrations
docker-compose --profile migration run --rm flyway migrate

# Check migration status
docker-compose --profile migration run --rm flyway info

# Reset database (development only)
docker-compose --profile migration run --rm flyway clean
docker-compose --profile migration run --rm flyway migrate

# Quick setup script
chmod +x scripts/dev-setup.sh
./scripts/dev-setup.sh
```

### Infrastructure Management
```bash
# Initialize and deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# Manual database backup
./scripts/backup.sh
```

### Database Migration Patterns
- Migration files follow Flyway naming: `V{version}__{description}.sql`
- All migrations in `migrations/` directory
- Use descriptive names: `V1__create_tables.sql`, `V2__add_index.sql`
- Test locally before production deployment

### Production Migration Deployment
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

## Project Structure Guidelines

Expected directory structure:
```
url-shortener/
├── README.md                    # Comprehensive project documentation
├── docker-compose.yml           # Local development environment
├── flyway.conf                 # Flyway configuration for local development
├── migrations/                 # Database schema migrations
│   ├── V1__create_tables.sql
│   └── V2__add_index.sql
├── scripts/                    # Automation and helper scripts
│   ├── backup.sh              # Manual backup script
│   ├── dev-setup.sh           # Local environment setup
│   └── reset-db.sh            # Database reset utility
└── terraform/                 # Infrastructure as Code
    ├── main.tf               # Provider configuration
    ├── variables.tf          # Input variables
    ├── outputs.tf           # Output values
    ├── rds.tf              # RDS instance configuration
    ├── backup.tf           # Backup automation
    ├── iam.tf              # IAM roles and policies
    └── networking.tf       # VPC, subnets, security groups
```

## Development Workflow

1. **Schema Changes**: Create new migration files with incremental version numbers
2. **Local Testing**: Test migrations against local Docker PostgreSQL instance
3. **Infrastructure Changes**: Modify Terraform configurations and plan changes before applying
4. **Production Deployment**: Deploy infrastructure first, then apply migrations

## Key Configuration Files

- `docker-compose.yml`: Local PostgreSQL setup with Flyway service
- `flyway.conf`: Database connection configuration for local development
- `terraform/rds.tf`: Main RDS instance configuration with backup settings
- `scripts/dev-setup.sh`: Automated local environment initialization

## Important Notes

- Database uses PostgreSQL 15.4 for consistency between local and production environments
- All migrations should be tested locally before production deployment
- Backup strategy includes both automated daily backups (7-day retention) and manual backup scripts
- Local development uses `urlshortener` database with `postgres` user
- Production uses separate application user with limited privileges