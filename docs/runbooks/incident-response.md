# Incident Response Runbook - URL Shortener

## Overview

This runbook provides step-by-step procedures for responding to incidents affecting the URL Shortener service. All incidents should be handled with urgency while maintaining security and data integrity.

## Incident Classification

### Severity Levels

**P0 - Critical**
- Complete service outage
- Data loss or corruption
- Security breach
- *Response Time: 15 minutes*

**P1 - High**
- Significant service degradation
- Database connection issues
- Cache failures affecting performance
- *Response Time: 1 hour*

**P2 - Medium**
- Minor service degradation
- Non-critical feature failures
- Performance issues
- *Response Time: 4 hours*

**P3 - Low**
- Cosmetic issues
- Documentation updates needed
- *Response Time: Next business day*

## Emergency Contacts

```
Incident Commander: [TO BE CONFIGURED]
Database Admin: [TO BE CONFIGURED]
Infrastructure Team: [TO BE CONFIGURED]
Security Team: [TO BE CONFIGURED]
```

## Common Incident Types

### 1. Database Connection Failures

**Symptoms:**
- Application health check fails
- "database connection refused" errors
- High database connection count alarms

**Investigation Steps:**
1. Check RDS instance status:
   ```bash
   aws rds describe-db-instances --db-instance-identifier dev-urlshortener
   ```

2. Verify security group rules:
   ```bash
   aws ec2 describe-security-groups --group-ids sg-xxxxx
   ```

3. Check CloudWatch metrics:
   - DatabaseConnections
   - CPUUtilization
   - FreeableMemory

**Resolution Steps:**
1. **If RDS is down:**
   ```bash
   # Check for automated backups
   aws rds describe-db-snapshots --db-instance-identifier dev-urlshortener

   # If needed, restore from latest snapshot
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier dev-urlshortener-restore \
     --db-snapshot-identifier rds:dev-urlshortener-YYYY-MM-DD-HH-MM
   ```

2. **If connection pool exhausted:**
   ```bash
   # Restart application instances
   docker compose restart app

   # Or in production, restart ECS tasks
   aws ecs update-service --cluster url-shortener --service app --force-new-deployment
   ```

3. **If security group misconfigured:**
   ```bash
   # Add application subnet access
   aws ec2 authorize-security-group-ingress \
     --group-id sg-xxxxx \
     --protocol tcp \
     --port 5432 \
     --cidr 10.0.10.0/24
   ```

### 2. Redis Cache Failures

**Symptoms:**
- Increased database load
- Slower response times
- Redis connection errors in logs

**Investigation Steps:**
1. Check ElastiCache cluster status:
   ```bash
   aws elasticache describe-replication-groups --replication-group-id dev-redis
   ```

2. Review CloudWatch metrics:
   - CPUUtilization
   - DatabaseMemoryUsagePercentage
   - CurrConnections

**Resolution Steps:**
1. **If Redis is down:**
   ```bash
   # Check recent snapshots
   aws elasticache describe-snapshots --replication-group-id dev-redis

   # Create new cluster from snapshot if needed
   aws elasticache create-replication-group \
     --replication-group-id dev-redis-restore \
     --snapshot-name dev-redis-snapshot-xxx
   ```

2. **If memory issues:**
   ```bash
   # Scale up node type (requires maintenance window)
   aws elasticache modify-replication-group \
     --replication-group-id dev-redis \
     --cache-node-type cache.r6g.large \
     --apply-immediately
   ```

3. **Application graceful degradation:**
   - Application should continue working without Redis
   - Verify degraded mode in health check
   - Monitor increased database load

### 3. Application Performance Issues

**Symptoms:**
- High response times
- Timeout errors
- CPU/Memory alarms

**Investigation Steps:**
1. Check application logs:
   ```bash
   # Local development
   make dev-logs

   # Production
   aws logs get-log-events --log-group-name /aws/ecs/url-shortener
   ```

2. Review metrics:
   - Response time percentiles
   - Error rates
   - Resource utilization

**Resolution Steps:**
1. **Scale application:**
   ```bash
   # Increase ECS service desired count
   aws ecs update-service \
     --cluster url-shortener \
     --service app \
     --desired-count 3
   ```

2. **Restart unhealthy instances:**
   ```bash
   # Force new deployment
   aws ecs update-service \
     --cluster url-shortener \
     --service app \
     --force-new-deployment
   ```

### 4. Security Incidents

**Symptoms:**
- Unusual traffic patterns
- Failed authentication attempts
- Suspicious database queries

**IMMEDIATE ACTIONS:**
1. **Isolate affected systems:**
   ```bash
   # Block suspicious IP ranges
   aws ec2 authorize-security-group-ingress \
     --group-id sg-xxxxx \
     --protocol tcp \
     --port 443 \
     --cidr 0.0.0.0/0 \
     --source-group sg-blocked-ips
   ```

2. **Enable additional logging:**
   ```bash
   # Enable VPC Flow Logs if not already enabled
   aws ec2 create-flow-logs \
     --resource-type VPC \
     --resource-ids vpc-xxxxx \
     --traffic-type ALL
   ```

3. **Contact security team immediately**
4. **Preserve evidence:**
   - Take EBS snapshots
   - Export CloudWatch logs
   - Document timeline

## Backup and Recovery Procedures

### Database Recovery

**Full Database Restore:**
1. Identify recovery point:
   ```bash
   aws rds describe-db-snapshots \
     --db-instance-identifier dev-urlshortener \
     --snapshot-type automated \
     --max-items 10
   ```

2. Create test restore (validate before production):
   ```bash
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier dev-urlshortener-test \
     --db-snapshot-identifier rds:dev-urlshortener-2024-01-15-06-00
   ```

3. Validate data integrity:
   ```sql
   -- Connect to test instance and verify
   SELECT COUNT(*) FROM urls;
   SELECT MAX(created_at) FROM urls;
   ```

4. If validation passes, promote test instance or create production restore

**Point-in-Time Recovery:**
```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier dev-urlshortener \
  --target-db-instance-identifier dev-urlshortener-pitr \
  --restore-time 2024-01-15T14:30:00.000Z
```

### Application Recovery

**Rollback Deployment:**
```bash
# ECS service rollback
aws ecs update-service \
  --cluster url-shortener \
  --service app \
  --task-definition url-shortener:PREVIOUS_REVISION

# Docker Compose rollback
git checkout PREVIOUS_COMMIT
make dev-stop && make dev-start
```

## Post-Incident Actions

### 1. Service Restoration Verification
- [ ] All health checks passing
- [ ] Key metrics within normal ranges
- [ ] End-to-end testing completed
- [ ] Performance baselines restored

### 2. Communication
- [ ] Incident resolved notification sent
- [ ] Status page updated
- [ ] Stakeholders notified

### 3. Documentation
- [ ] Incident timeline documented
- [ ] Root cause analysis completed
- [ ] Lessons learned captured
- [ ] Runbook updates identified

### 4. Follow-up Actions
- [ ] Prevention measures implemented
- [ ] Monitoring improvements added
- [ ] Process improvements documented
- [ ] Training needs identified

## Monitoring and Alerting

### Critical Alerts That Require Immediate Response

**Database Alerts:**
- `dev-database-high-cpu` > 80%
- `dev-database-high-connections` > 20
- Database instance state != "available"

**Redis Alerts:**
- `dev-redis-high-cpu` > 80%
- `dev-redis-high-memory` > 80%
- `dev-redis-high-connections` > 50

**Application Alerts:**
- Health check failures
- High error rates (> 5%)
- Response time > 2 seconds

**Infrastructure Alerts:**
- VPC Flow Logs showing unusual traffic
- Failed backup verification
- Security group changes

### Alert Response Matrix

| Alert | Severity | Response Time | Action |
|-------|----------|---------------|--------|
| Database Down | P0 | 15 min | Follow database recovery procedure |
| Redis Down | P1 | 1 hour | Verify graceful degradation, restore if needed |
| High CPU | P2 | 4 hours | Investigate cause, scale if needed |
| Backup Failed | P1 | 1 hour | Investigate and manually trigger backup |

## Tools and Access

### Required Access
- AWS Console with appropriate IAM permissions
- Database connection strings (stored in secure location)
- SSH keys for bastion access (if applicable)
- Docker/ECS deployment permissions

### Useful Commands
```bash
# Quick health check
curl -s https://url-shortener.example.com/health | jq .

# Application logs
aws logs tail /aws/ecs/url-shortener --follow

# Database connection test
psql $DATABASE_URL -c "SELECT 1;"

# Redis connection test
redis-cli -h $REDIS_HOST ping
```

### Emergency Procedures

**If all else fails - Complete Service Restart:**
1. Scale down application to 0
2. Wait 2 minutes for connections to drain
3. Scale back up to desired capacity
4. Verify health checks pass

**Data Loss Scenario:**
1. Stop all writes immediately
2. Assess scope of data loss
3. Restore from most recent backup
4. Implement additional monitoring
5. Conduct thorough post-incident review