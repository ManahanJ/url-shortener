# tflint configuration for URL Shortener project
# Terraform best practices and AWS-specific linting

config {
  # Enable module inspection
  call_module_type = "all"

  # Force return an error code even if no issues found
  force = false
}

# Core Terraform rules
rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true

  # Variable naming
  variable {
    format = "snake_case"
  }

  # Local value naming
  locals {
    format = "snake_case"
  }

  # Output naming
  output {
    format = "snake_case"
  }

  # Resource naming
  resource {
    format = "snake_case"
  }

  # Data source naming
  data {
    format = "snake_case"
  }
}

rule "terraform_standard_module_structure" {
  enabled = true
}

# AWS-specific plugin
plugin "aws" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"

  # Deep check for AWS resources (slower but more thorough)
  deep_check = false
}

# AWS-specific rules - using only available rules
rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_instance_previous_type" {
  enabled = true
}

rule "aws_route_not_specified_target" {
  enabled = true
}

rule "aws_route_specified_multiple_targets" {
  enabled = true
}

rule "aws_elasticache_cluster_invalid_type" {
  enabled = true
}

rule "aws_elasticache_cluster_previous_type" {
  enabled = true
}

rule "aws_db_instance_invalid_type" {
  enabled = true
}

rule "aws_db_instance_previous_type" {
  enabled = true
}

rule "aws_db_instance_invalid_engine" {
  enabled = true
}

rule "aws_security_group_rule_invalid_protocol" {
  enabled = true
}

rule "aws_lambda_function_invalid_runtime" {
  enabled = true
}

rule "aws_lambda_function_deprecated_runtime" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}