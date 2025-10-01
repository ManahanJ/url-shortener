#!/bin/bash
set -e

echo "🚀 Setting up URL Shortener development environment..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose >/dev/null 2>&1; then
    echo "❌ docker-compose is not installed. Please install it and try again."
    exit 1
fi

echo "📦 Starting PostgreSQL and Redis..."
docker-compose up -d postgres redis

echo "⏳ Waiting for services to be ready..."
sleep 15

echo "🗄️ Running database migrations..."
docker-compose --profile migration run --rm flyway migrate

echo "✅ Development environment ready!"
echo ""
echo "Next steps:"
echo "  • Start the app: make dev-start"
echo "  • Test health: curl http://localhost:8080/health"
echo "  • View logs: make dev-logs"
echo "  • Stop services: make dev-stop"