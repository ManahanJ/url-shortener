# Backup and Restore Runbook - URL Shortener

## Overview

This runbook covers all backup and restore procedures for the URL Shortener service, including automated daily backups, manual backup creation, and disaster recovery procedures.

## Backup Strategy

### Automated Backups

**Database (RDS PostgreSQL):**
- **Frequency:** Daily at 3:00 AM UTC
- **Retention:** 7 days
- **Verification:** Daily automated restore test via Lambda

**Redis (ElastiCache):**
- **Frequency:** Daily during maintenance window
- **Retention:** 5 days
- **Type:** Cluster snapshots

**Application Code:**
- **Method:** Git repositories with tagged releases
- **Backup:** Automated via GitHub/GitLab

**Infrastructure Configuration:**
- **Method:** Terraform state files
- **Backup:** S3 with versioning enabled

## Daily Backup Verification

### Automated Verification Process

The backup verification Lambda function runs daily at 6:00 AM UTC and:

1. Identifies the latest automated database snapshot
2. Creates a test restore instance
3. Validates data integrity
4. Cleans up test resources
5. Sends notification of results

### Manual Verification

**Check Latest Database Backup:**
```bash
# List recent automated snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier dev-urlshortener \
  --snapshot-type automated \
  --max-items 7 \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
  --output table

# Verify backup completed successfully
aws rds describe-db-snapshots \
  --db-snapshot-identifier rds:dev-urlshortener-$(date +%Y-%m-%d) \
  --query 'DBSnapshots[0].Status'
```

**Check Redis Backup:**
```bash
# List recent Redis snapshots
aws elasticache describe-snapshots \
  --replication-group-id dev-redis \
  --max-items 5 \
  --query 'Snapshots[*].[SnapshotName,SnapshotStatus,NodeSnapshots[0].SnapshotCreateTime]' \
  --output table
```

**Verify Backup Verification Lambda:**
```bash
# Check recent Lambda executions
aws logs filter-log-events \
  --log-group-name /aws/lambda/dev-backup-verify \
  --start-time $(date -d '24 hours ago' +%s)000 \
  --query 'events[*].[eventId,message]' \
  --output table
```

## Manual Backup Procedures

### Create Manual Database Backup

**Before Major Changes:**
```bash
# Create manual snapshot before deployment
aws rds create-db-snapshot \
  --db-instance-identifier dev-urlshortener \
  --db-snapshot-identifier dev-urlshortener-manual-$(date +%Y%m%d-%H%M) \
  --tags Key=Purpose,Value=PreDeployment Key=CreatedBy,Value=manual

# Wait for completion
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier dev-urlshortener-manual-$(date +%Y%m%d-%H%M)
```

**For Compliance/Archival:**
```bash
# Create long-term retention snapshot
aws rds create-db-snapshot \
  --db-instance-identifier dev-urlshortener \
  --db-snapshot-identifier dev-urlshortener-archive-$(date +%Y%m%d) \
  --tags Key=Retention,Value=LongTerm Key=Purpose,Value=Compliance
```

### Create Manual Redis Backup

```bash
# Create Redis snapshot
aws elasticache create-snapshot \
  --replication-group-id dev-redis \
  --snapshot-name dev-redis-manual-$(date +%Y%m%d-%H%M) \
  --tags Key=Purpose,Value=Manual Key=CreatedBy,Value=operator
```

## Restore Procedures

### Database Point-in-Time Recovery

**Restore to Specific Time:**
```bash
# Restore to exact timestamp
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier dev-urlshortener \
  --target-db-instance-identifier dev-urlshortener-pitr-$(date +%Y%m%d) \
  --restore-time "2024-01-15T14:30:00.000Z" \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name dev-urlshortener-subnet-group \
  --tags Key=Purpose,Value=PITR Key=SourceTime,Value=2024-01-15T14:30:00

# Monitor restore progress
aws rds describe-db-instances \
  --db-instance-identifier dev-urlshortener-pitr-$(date +%Y%m%d) \
  --query 'DBInstances[0].DBInstanceStatus'
```

### Database Restore from Snapshot

**Standard Restore Process:**
```bash
# 1. List available snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier dev-urlshortener \
  --snapshot-type automated \
  --max-items 10

# 2. Choose snapshot and restore
SNAPSHOT_ID="rds:dev-urlshortener-2024-01-15-06-00"
RESTORE_INSTANCE="dev-urlshortener-restore-$(date +%Y%m%d)"

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier $RESTORE_INSTANCE \
  --db-snapshot-identifier $SNAPSHOT_ID \
  --db-instance-class db.t3.micro \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name dev-urlshortener-subnet-group \
  --tags Key=Purpose,Value=Restore Key=SourceSnapshot,Value=$SNAPSHOT_ID

# 3. Wait for restore to complete
aws rds wait db-instance-available --db-instance-identifier $RESTORE_INSTANCE

# 4. Get connection endpoint
aws rds describe-db-instances \
  --db-instance-identifier $RESTORE_INSTANCE \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

### Redis Restore from Snapshot

```bash
# 1. List available snapshots
aws elasticache describe-snapshots \
  --replication-group-id dev-redis

# 2. Create new cluster from snapshot
SNAPSHOT_NAME="dev-redis-snapshot-2024-01-15"
NEW_CLUSTER="dev-redis-restore-$(date +%Y%m%d)"

aws elasticache create-replication-group \
  --replication-group-id $NEW_CLUSTER \
  --description "Restored from $SNAPSHOT_NAME" \
  --snapshot-name $SNAPSHOT_NAME \
  --cache-node-type cache.t3.micro \
  --security-group-ids sg-xxxxx \
  --subnet-group-name dev-redis-subnet-group

# 3. Wait for cluster to be available
aws elasticache describe-replication-groups \
  --replication-group-id $NEW_CLUSTER \
  --query 'ReplicationGroups[0].Status'
```

### Application Restore

**Rollback to Previous Version:**
```bash
# 1. Identify target version
git log --oneline -10

# 2. For container deployment
PREVIOUS_VERSION="v1.2.3"
docker build -t url-shortener:$PREVIOUS_VERSION .
docker tag url-shortener:$PREVIOUS_VERSION url-shortener:latest

# 3. For ECS deployment
aws ecs update-service \
  --cluster url-shortener \
  --service app \
  --task-definition url-shortener:REVISION_NUMBER

# 4. Verify rollback
curl -s https://url-shortener.example.com/health | jq .version
```

## Disaster Recovery Procedures

### Complete Environment Recreation

**Prerequisites:**
- Terraform state backup available
- Latest database snapshot identified
- DNS/Domain access maintained

**Step 1: Infrastructure Recovery**
```bash
# 1. Initialize Terraform from backup
cd terraform/envs/prod
terraform init -backend-config="bucket=url-shortener-terraform-state-backup"

# 2. Import existing resources or recreate
terraform plan
terraform apply

# 3. Verify infrastructure is ready
aws ecs describe-clusters --clusters url-shortener
```

**Step 2: Database Recovery**
```bash
# 1. Restore database from latest backup
LATEST_SNAPSHOT=$(aws rds describe-db-snapshots \
  --db-instance-identifier prod-urlshortener \
  --snapshot-type automated \
  --max-items 1 \
  --query 'DBSnapshots[0].DBSnapshotIdentifier' \
  --output text)

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier prod-urlshortener \
  --db-snapshot-identifier $LATEST_SNAPSHOT
```

**Step 3: Cache Recovery**
```bash
# 1. Restore Redis cluster
LATEST_REDIS_SNAPSHOT=$(aws elasticache describe-snapshots \
  --replication-group-id prod-redis \
  --max-items 1 \
  --query 'Snapshots[0].SnapshotName' \
  --output text)

aws elasticache create-replication-group \
  --replication-group-id prod-redis \
  --snapshot-name $LATEST_REDIS_SNAPSHOT
```

**Step 4: Application Deployment**
```bash
# 1. Deploy latest stable version
aws ecs update-service \
  --cluster url-shortener \
  --service app \
  --task-definition url-shortener:latest

# 2. Verify application health
curl -s https://url-shortener.example.com/health
```

## Data Validation Procedures

### Database Integrity Checks

**After Restore Validation:**
```sql
-- Connect to restored database
psql -h RESTORED_ENDPOINT -U postgres -d urlshortener

-- 1. Check record counts
SELECT
    'urls' as table_name,
    COUNT(*) as record_count,
    MAX(created_at) as latest_record
FROM urls;

-- 2. Verify data integrity
SELECT
    COUNT(*) as total_urls,
    COUNT(DISTINCT short_code) as unique_codes,
    COUNT(CASE WHEN created_at > NOW() - INTERVAL '24 hours' THEN 1 END) as recent_urls
FROM urls;

-- 3. Check for data corruption
SELECT short_code, COUNT(*)
FROM urls
GROUP BY short_code
HAVING COUNT(*) > 1;

-- 4. Verify constraints
SELECT
    conname as constraint_name,
    contype as constraint_type
FROM pg_constraint
WHERE conrelid = 'urls'::regclass;
```

**Performance Validation:**
```sql
-- Test query performance
EXPLAIN ANALYZE SELECT * FROM urls WHERE short_code = 'test123';

-- Check index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE tablename = 'urls';
```

### Application Validation

**End-to-End Testing:**
```bash
#!/bin/bash
# Post-restore validation script

ENDPOINT="https://url-shortener.example.com"

# 1. Health check
echo "Testing health endpoint..."
curl -s $ENDPOINT/health | jq .

# 2. Create short URL
echo "Testing URL creation..."
RESPONSE=$(curl -s -X POST $ENDPOINT/shorten \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com/test"}')

SHORT_CODE=$(echo $RESPONSE | jq -r .short_code)
echo "Created short code: $SHORT_CODE"

# 3. Test resolution
echo "Testing URL resolution..."
curl -I $ENDPOINT/$SHORT_CODE

# 4. Test rate limiting
echo "Testing rate limiting..."
for i in {1..15}; do
  curl -s -o /dev/null -w "%{http_code} " $ENDPOINT/health
done
echo
```

## Backup Monitoring and Alerting

### CloudWatch Alarms

**Backup Failure Detection:**
```bash
# Create alarm for failed backup verification
aws cloudwatch put-metric-alarm \
  --alarm-name "backup-verification-failed" \
  --alarm-description "Backup verification Lambda failed" \
  --metric-name "Errors" \
  --namespace "AWS/Lambda" \
  --statistic "Sum" \
  --period 86400 \
  --threshold 1 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --dimensions Name=FunctionName,Value=dev-backup-verify \
  --alarm-actions arn:aws:sns:region:account:backup-alerts
```

### Daily Backup Report

**Automated Report Generation:**
```bash
#!/bin/bash
# Daily backup status report

echo "=== Daily Backup Status Report ==="
echo "Date: $(date)"
echo

# Database backups
echo "Database Backups (Last 3 days):"
aws rds describe-db-snapshots \
  --db-instance-identifier dev-urlshortener \
  --snapshot-type automated \
  --max-items 3 \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
  --output table

# Redis backups
echo "Redis Backups (Last 3 days):"
aws elasticache describe-snapshots \
  --replication-group-id dev-redis \
  --max-items 3 \
  --query 'Snapshots[*].[SnapshotName,SnapshotStatus,NodeSnapshots[0].SnapshotCreateTime]' \
  --output table

# Backup verification status
echo "Backup Verification (Last 24 hours):"
aws logs filter-log-events \
  --log-group-name /aws/lambda/dev-backup-verify \
  --start-time $(date -d '24 hours ago' +%s)000 \
  --filter-pattern "Backup verification" \
  --query 'events[*].message' \
  --output text
```

## Retention Policies

### Automatic Cleanup

**Database Snapshots:**
- Automated backups: 7 days (RDS managed)
- Manual snapshots: Review monthly, delete after 90 days
- Archive snapshots: Keep for 1 year for compliance

**Redis Snapshots:**
- Automated backups: 5 days (ElastiCache managed)
- Manual snapshots: Review monthly, delete after 30 days

**Cleanup Script:**
```bash
#!/bin/bash
# Monthly cleanup of old manual snapshots

# Delete old manual database snapshots (>90 days)
aws rds describe-db-snapshots \
  --snapshot-type manual \
  --query "DBSnapshots[?SnapshotCreateTime<='$(date -d '90 days ago' --iso-8601)'].DBSnapshotIdentifier" \
  --output text | \
while read snapshot; do
  if [[ $snapshot == *"manual"* ]]; then
    echo "Deleting old snapshot: $snapshot"
    aws rds delete-db-snapshot --db-snapshot-identifier $snapshot
  fi
done

# Delete old manual Redis snapshots (>30 days)
aws elasticache describe-snapshots \
  --query "Snapshots[?SnapshotCreateTime<='$(date -d '30 days ago' --iso-8601)'].SnapshotName" \
  --output text | \
while read snapshot; do
  if [[ $snapshot == *"manual"* ]]; then
    echo "Deleting old Redis snapshot: $snapshot"
    aws elasticache delete-snapshot --snapshot-name $snapshot
  fi
done
```

## Emergency Contacts

**Backup Issues:**
- Database Admin: [TO BE CONFIGURED]
- Infrastructure Team: [TO BE CONFIGURED]
- AWS Support: [SUPPORT CASE REQUIRED]

**Escalation Path:**
1. Infrastructure Team (0-30 minutes)
2. Database Admin (30-60 minutes)
3. AWS Support (if infrastructure issue)
4. Management (if business impact > 2 hours)