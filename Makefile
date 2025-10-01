.PHONY: help build test lint fmt vet dev-setup dev-start dev-stop migrate migrate-reset docker-build docker-run clean deps

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## Development
dev-setup: ## Set up local development environment
	docker compose up -d postgres redis
	@echo "Waiting for services to be ready..."
	@sleep 10
	docker compose --profile migration run --rm flyway migrate
	@echo "Development environment ready!"

dev-start: ## Start all services including app
	docker compose --profile app up -d

dev-stop: ## Stop all services
	docker compose --profile app down

dev-logs: ## Show logs from all services
	docker compose --profile app logs -f

dev-reset: ## Reset development environment
	docker compose down -v
	make dev-setup

## Database
migrate: ## Run database migrations
	docker compose --profile migration run --rm flyway migrate

migrate-info: ## Check migration status
	docker compose --profile migration run --rm flyway info

migrate-reset: ## Reset database (DESTRUCTIVE - dev only)
	docker compose --profile migration run --rm flyway clean
	docker compose --profile migration run --rm flyway migrate

## Go Development
deps: ## Download and tidy dependencies
	go mod download
	go mod tidy

build: ## Build the application
	go build -o bin/server cmd/server/main.go

run: ## Run the application locally (requires services)
	go run cmd/server/main.go

test: ## Run tests
	go test -v ./...

test-coverage: ## Run tests with coverage
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

lint: ## Run golangci-lint
	@command -v golangci-lint >/dev/null 2>&1 || { echo "golangci-lint not installed. Installing..."; go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; }
	golangci-lint run

fmt: ## Format Go code
	go fmt ./...
	goimports -w .

vet: ## Run go vet
	go vet ./...

## Docker
docker-build: ## Build Docker image
	docker build -t url-shortener:latest .

docker-run: ## Run application in Docker
	docker run -p 8080:8080 --env-file .env url-shortener:latest

## Quality Gates
quality: deps fmt vet lint test ## Run all quality checks

## Infrastructure
terraform-init: ## Initialize Terraform
	cd terraform/envs/dev && terraform init

terraform-plan: ## Plan Terraform changes
	cd terraform/envs/dev && terraform plan

terraform-validate: ## Validate Terraform configuration
	cd terraform/envs/dev && terraform validate

terraform-fmt: ## Format Terraform files
	cd terraform && terraform fmt -recursive

## Cleanup
clean: ## Clean up build artifacts
	rm -rf bin/
	rm -f coverage.out coverage.html
	docker system prune -f

## Quick start
quick-start: dev-setup ## Quick start for new developers
	@echo ""
	@echo "🚀 Development environment is ready!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Start the app: make dev-start"
	@echo "  2. Test the health endpoint: curl http://localhost:8080/health"
	@echo "  3. Check logs: make dev-logs"
	@echo ""