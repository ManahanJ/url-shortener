# ADR-001: Scope Expansion from Database Backend to Full Go Service

## Status
Accepted

## Context
The initial project scope was defined as a "PostgreSQL database backend for a URL shortener service" with focus on Infrastructure as Code, backup strategy, and schema migrations. However, the implementation requirements call for a complete TinyURL-style service in Go with comprehensive functionality.

## Decision
We are expanding the project scope to include:

1. **Go HTTP Service**: Complete REST API with gin framework
2. **Redis Integration**: Caching for URL resolution and rate limiting
3. **Comprehensive Developer Experience**: Linting, testing, pre-commit hooks, CI/CD
4. **Multi-environment Infrastructure**: Development and production Terraform configurations

The original database-focused components (PostgreSQL + Flyway + Terraform) remain as the foundation, with the Go application and Redis components built on top.

## Consequences

### Positive
- Complete working service that can be deployed and tested end-to-end
- Demonstrates full-stack development and operational practices
- Provides realistic caching and rate limiting implementations
- Better showcases Infrastructure as Code across multiple AWS services

### Negative
- Increased complexity compared to database-only approach
- Additional dependencies (Go runtime, Redis)
- More surface area for security and operational concerns

## Implementation Notes
- All existing documentation (README.md, CLAUDE.md) updated to reflect new scope
- Maintain backward compatibility with existing Flyway migration patterns
- Preserve database-first approach for schema management
- Add Redis as optional dependency (service should degrade gracefully without cache)