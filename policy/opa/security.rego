# OPA Security Policies for URL Shortener Infrastructure
# Enforces security best practices across all Terraform resources

package terraform.security

import rego.v1

# DENY rule: No public ingress allowed
deny contains msg if {
    input.resource_changes[_].type == "aws_security_group"
    rule := input.resource_changes[_].change.after.ingress[_]

    # Check for public access patterns
    public_access_detected(rule)

    msg := sprintf("Security group '%s' has public ingress access. CIDR blocks must not include 0.0.0.0/0 or ::/0", [
        input.resource_changes[_].address
    ])
}

# DENY rule: RDS instances must not be publicly accessible
deny contains msg if {
    input.resource_changes[_].type == "aws_db_instance"
    instance := input.resource_changes[_].change.after
    instance.publicly_accessible == true

    msg := sprintf("RDS instance '%s' must not be publicly accessible", [
        input.resource_changes[_].address
    ])
}

# DENY rule: All data stores must be encrypted at rest
deny contains msg if {
    input.resource_changes[_].type == "aws_db_instance"
    instance := input.resource_changes[_].change.after
    instance.storage_encrypted != true

    msg := sprintf("RDS instance '%s' must have storage encryption enabled", [
        input.resource_changes[_].address
    ])
}

# DENY rule: ElastiCache clusters must be encrypted
deny contains msg if {
    input.resource_changes[_].type == "aws_elasticache_replication_group"
    cluster := input.resource_changes[_].change.after

    # Check encryption at rest
    not cluster.at_rest_encryption_enabled

    msg := sprintf("ElastiCache cluster '%s' must have encryption at rest enabled", [
        input.resource_changes[_].address
    ])
}

# DENY rule: ElastiCache clusters must have transit encryption
deny contains msg if {
    input.resource_changes[_].type == "aws_elasticache_replication_group"
    cluster := input.resource_changes[_].change.after

    # Check encryption in transit
    not cluster.transit_encryption_enabled

    msg := sprintf("ElastiCache cluster '%s' must have encryption in transit enabled", [
        input.resource_changes[_].address
    ])
}

# DENY rule: S3 buckets must have encryption enabled
deny contains msg if {
    input.resource_changes[_].type == "aws_s3_bucket"
    bucket := input.resource_changes[_].change.after

    # Must have a corresponding server-side encryption configuration
    bucket_name := bucket.bucket
    not has_s3_encryption(bucket_name)

    msg := sprintf("S3 bucket '%s' must have server-side encryption configured", [
        input.resource_changes[_].address
    ])
}

# DENY rule: KMS keys must have rotation enabled
deny contains msg if {
    input.resource_changes[_].type == "aws_kms_key"
    key := input.resource_changes[_].change.after
    key.enable_key_rotation != true

    msg := sprintf("KMS key '%s' must have automatic key rotation enabled", [
        input.resource_changes[_].address
    ])
}

# DENY rule: Lambda functions must not have public access
deny contains msg if {
    input.resource_changes[_].type == "aws_lambda_permission"
    permission := input.resource_changes[_].change.after
    permission.principal == "*"

    msg := sprintf("Lambda permission '%s' must not allow public access (principal: '*')", [
        input.resource_changes[_].address
    ])
}

# Helper function to detect public access in security group rules
public_access_detected(rule) if {
    rule.cidr_blocks[_] == "0.0.0.0/0"
}

public_access_detected(rule) if {
    rule.ipv6_cidr_blocks[_] == "::/0"
}

# Helper function to check if S3 bucket has encryption
has_s3_encryption(bucket_name) if {
    input.resource_changes[_].type == "aws_s3_bucket_server_side_encryption_configuration"
    encryption := input.resource_changes[_].change.after
    encryption.bucket == bucket_name
}

# WARN rule: RDS instances should use latest engine version
warn contains msg if {
    input.resource_changes[_].type == "aws_db_instance"
    instance := input.resource_changes[_].change.after
    instance.engine == "postgres"

    # Check if using recommended version (15.4 or later)
    version_parts := split(instance.engine_version, ".")
    major := to_number(version_parts[0])
    minor := to_number(version_parts[1])

    not version_is_recommended(major, minor)

    msg := sprintf("RDS instance '%s' should use PostgreSQL 15.4 or later (currently %s)", [
        input.resource_changes[_].address,
        instance.engine_version
    ])
}

# WARN rule: Security groups should have description
warn contains msg if {
    input.resource_changes[_].type == "aws_security_group"
    sg := input.resource_changes[_].change.after

    # Check if description is missing or generic
    not sg.description

    msg := sprintf("Security group '%s' should have a meaningful description", [
        input.resource_changes[_].address
    ])
}

warn contains msg if {
    input.resource_changes[_].type == "aws_security_group"
    sg := input.resource_changes[_].change.after

    # Check for generic descriptions
    generic_descriptions := [
        "Security group",
        "Managed by Terraform",
        "Default security group"
    ]

    sg.description
    sg.description == generic_descriptions[_]

    msg := sprintf("Security group '%s' should have a meaningful description (current: '%s')", [
        input.resource_changes[_].address,
        sg.description
    ])
}

# Helper function to check if PostgreSQL version is recommended
version_is_recommended(major, minor) if {
    major > 15
}

version_is_recommended(major, minor) if {
    major == 15
    minor >= 4
}