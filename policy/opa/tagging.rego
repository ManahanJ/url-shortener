# OPA Tagging Policies for URL Shortener Infrastructure
# Enforces consistent tagging across all AWS resources

package terraform.tagging

import rego.v1

# Required tags for all resources
required_tags := {
    "Environment",
    "Project",
    "Owner",
    "CostCenter"
}

# Resources that support tags
taggable_resources := {
    "aws_db_instance",
    "aws_db_subnet_group",
    "aws_db_parameter_group",
    "aws_security_group",
    "aws_elasticache_replication_group",
    "aws_elasticache_subnet_group",
    "aws_vpc",
    "aws_subnet",
    "aws_internet_gateway",
    "aws_nat_gateway",
    "aws_route_table",
    "aws_s3_bucket",
    "aws_kms_key",
    "aws_lambda_function",
    "aws_cloudwatch_log_group",
    "aws_sns_topic",
    "aws_iam_role"
}

# DENY rule: All taggable resources must have required tags
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type in taggable_resources
    tags := object.get(resource.change.after, "tags", {})

    missing_tags := required_tags - {tag | tags[tag]}
    count(missing_tags) > 0

    msg := sprintf("Resource '%s' is missing required tags: %s", [
        resource.address,
        missing_tags
    ])
}

# DENY rule: Environment tag must have valid value
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type in taggable_resources
    tags := object.get(resource.change.after, "tags", {})

    environment := tags.Environment
    environment != null

    # Valid environments
    valid_environments := {"dev", "staging", "prod"}
    not environment in valid_environments

    msg := sprintf("Resource '%s' has invalid Environment tag '%s'. Must be one of: %s", [
        resource.address,
        environment,
        valid_environments
    ])
}

# DENY rule: Project tag must be set to url-shortener
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type in taggable_resources
    tags := object.get(resource.change.after, "tags", {})

    project := tags.Project
    project != null
    project != "url-shortener"

    msg := sprintf("Resource '%s' has incorrect Project tag '%s'. Must be 'url-shortener'", [
        resource.address,
        project
    ])
}

# WARN rule: Resources should have Name tag for easy identification
warn contains msg if {
    resource := input.resource_changes[_]
    resource.type in taggable_resources
    tags := object.get(resource.change.after, "tags", {})

    not tags.Name

    msg := sprintf("Resource '%s' should have a Name tag for easy identification", [
        resource.address
    ])
}

# WARN rule: CostCenter should follow proper format
warn contains msg if {
    resource := input.resource_changes[_]
    resource.type in taggable_resources
    tags := object.get(resource.change.after, "tags", {})

    cost_center := tags.CostCenter
    cost_center != null

    # CostCenter should be numeric (engineering departments typically use numbers)
    not regex.match("^[0-9]{3,4}$", cost_center)

    msg := sprintf("Resource '%s' CostCenter tag '%s' should be 3-4 digit number (e.g., '1001')", [
        resource.address,
        cost_center
    ])
}

# DENY rule: Tags must not contain sensitive information
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type in taggable_resources
    tags := object.get(resource.change.after, "tags", {})

    # Check for sensitive patterns in tag values
    sensitive_patterns := [
        "password",
        "secret",
        "key",
        "token",
        "credential"
    ]

    tag_value := tags[_]
    contains(tag_value, sensitive_patterns[_])

    msg := sprintf("Resource '%s' has tags that may contain sensitive information. Avoid including passwords, secrets, or keys in tags", [
        resource.address
    ])
}

# DENY rule: Tag values must not be empty
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type in taggable_resources
    tags := object.get(resource.change.after, "tags", {})

    tag_key := [key | tags[key] == ""][0]
    tag_key != null

    msg := sprintf("Resource '%s' has empty value for tag '%s'. All tags must have meaningful values", [
        resource.address,
        tag_key
    ])
}

