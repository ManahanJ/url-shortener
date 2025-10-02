# CI/CD Runbook

This runbook covers the Continuous Integration and Continuous Deployment processes for the URL Shortener service.

## Overview

The CI/CD pipeline consists of two main workflows:
- **app-ci.yml**: Application code quality, testing, and smoke integration
- **iac-ci.yml**: Infrastructure validation and security scanning

## Local Development Workflow

### Running CI Checks Locally

Before pushing code, run the same checks that will execute in CI:

#### Application Checks
```bash
# Run all app CI checks
make ci-app

# Or run individual checks
make fmt     # Go code formatting check
make lint    # golangci-lint
make test    # Unit tests with race detection

# Check test coverage
make test-coverage
open coverage.html
```

#### Infrastructure Checks
```bash
# Run all infrastructure CI checks
make ci-iac

# Or run individual Terraform checks
make terraform-fmt      # Format check
make terraform-validate # Validation
make terraform-plan     # Plan generation

# Run security scans (requires tools installed)
cd terraform && tflint
tfsec terraform/
conftest test -p policy/opa/ terraform/
```

### Installing Development Tools

#### Go Tools
```bash
# golangci-lint
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin

# govulncheck
go install golang.org/x/vuln/cmd/govulncheck@latest
```

#### Infrastructure Tools
```bash
# tflint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# tfsec
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# conftest (OPA)
curl -L https://github.com/open-policy-agent/conftest/releases/download/v0.56.0/conftest_0.56.0_Linux_x86_64.tar.gz | tar xz -C /usr/local/bin

# On macOS, use brew:
brew install tflint tfsec conftest
```

## CI/CD Pipeline Details

### Application CI (`app-ci.yml`)

**Triggers:**
- Push to `main` branch
- All pull requests

**Jobs:**

1. **go-format-lint-test**
   - Go 1.22 setup with module caching
   - Code formatting validation (`gofmt -s -l`)
   - Linting with `golangci-lint`
   - Vulnerability scanning with `govulncheck`
   - Unit tests with race detection and coverage

2. **smoke-integration** (depends on job 1)
   - Starts Docker Compose stack (PostgreSQL, Redis, app)
   - Waits for services to be ready
   - Runs Flyway migrations
   - Tests health endpoint
   - Performs basic shorten/resolve smoke test
   - Cleans up resources

### Infrastructure CI (`iac-ci.yml`)

**Triggers:**
- Pull requests modifying:
  - `terraform/**`
  - `policy/**`
  - `.github/**`

**Jobs:**

1. **iac-validate-plan-policy**
   - Terraform formatting check
   - Terraform setup and initialization (backend=false)
   - Configuration validation
   - Plan generation and artifact upload
   - tflint analysis
   - tfsec security scanning
   - OPA policy validation with conftest

## Troubleshooting CI Issues

### Common Application CI Failures

#### Formatting Issues
```bash
# Error: Files need formatting
# Solution: Run gofmt locally
gofmt -s -w .

# Or use make target
make fmt
```

#### Lint Failures
```bash
# Check linting issues locally
golangci-lint run

# Common fixes:
# - Add error handling
# - Remove unused variables
# - Fix naming conventions
```

#### Test Failures
```bash
# Run tests with verbose output
go test -v ./...

# Run specific test
go test -v ./internal/handlers -run TestShortenHandler

# Check for race conditions
go test -race ./...
```

#### Smoke Integration Failures
```bash
# Debug locally
docker compose up -d
docker compose logs

# Check app health
curl http://localhost:8080/health

# Check services
docker compose ps
```

### Common Infrastructure CI Failures

#### Terraform Formatting
```bash
# Error: Terraform files not formatted
# Solution: Run terraform fmt
cd terraform
terraform fmt -recursive
```

#### Terraform Validation
```bash
# Debug validation issues
cd terraform/envs/dev
terraform init -backend=false
terraform validate

# Common issues:
# - Missing variables
# - Invalid resource references
# - Module interface mismatches
```

#### Security Scan Failures
```bash
# Check tfsec issues locally
tfsec terraform/

# Common issues:
# - Public ingress rules
# - Unencrypted resources
# - Overly permissive IAM policies

# Review and update .tfsec.yml for exclusions if needed
```

#### Policy Validation Failures
```bash
# Test OPA policies locally
conftest test -p policy/opa/ terraform/

# Debug policy evaluation
opa eval -d policy/opa/ -i terraform_plan.json "data.terraform.security.deny"
```

## Secrets Management

### CI/CD Secrets
- **No secrets in workflows**: All workflows use public data only
- **Backend disabled**: Terraform runs with `-backend=false` to avoid state access
- **Nightly backup**: Uses GitHub Actions secrets (if implemented)

### Required Secrets (for nightly backup job)
```bash
# Add these to GitHub Actions secrets if using backup verification
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
DB_IDENTIFIER
SNS_TOPIC_ARN
```

## Artifacts and Reports

### Terraform Plans
- Generated on every infrastructure PR
- Available as downloadable artifacts
- Named: `terraform-plan`
- Contains: `plan.txt` with human-readable plan output

### Test Coverage
- Generated during app CI
- File: `coverage.out`
- View locally: `go tool cover -html=coverage.out`

### Security Reports
- tfsec generates JSON reports
- Available in CI logs and artifacts
- Policy violations logged with file locations

## Monitoring and Alerts

### CI Pipeline Monitoring
- GitHub Actions provides native monitoring
- Failed builds trigger email notifications
- PR status checks prevent merging on failure

### Success Criteria
All checks must pass for PR merge:
- ✅ Go formatting and linting
- ✅ Unit tests with coverage
- ✅ Smoke integration tests
- ✅ Terraform validation and planning
- ✅ Security scans (tfsec)
- ✅ Policy validation (OPA)

## Emergency Procedures

### Bypassing CI (Emergency Only)
```bash
# If CI is broken and urgent fix needed:
# 1. Create hotfix branch
# 2. Apply minimal fix
# 3. Admin can merge with override (document in commit)
# 4. Fix CI in follow-up PR
```

### Rollback Procedures
- Application: Revert commit and redeploy
- Infrastructure: Use Terraform to revert to previous state
- Database: Use backup restoration procedures

## Continuous Improvement

### Adding New Checks
1. Test locally first
2. Add to appropriate workflow
3. Update Makefile targets
4. Document in this runbook
5. Update README.md

### Performance Optimization
- Use caching for dependencies
- Parallel job execution where possible
- Optimize Docker image layers
- Cache Terraform providers

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [golangci-lint Configuration](.golangci.yml)
- [Terraform Configuration](terraform/)
- [OPA Policies](policy/opa/)