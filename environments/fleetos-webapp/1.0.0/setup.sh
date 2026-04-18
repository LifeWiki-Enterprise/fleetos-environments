#!/usr/bin/env bash
# setup.sh — Start the FleetOS web app environment
# Idempotent: safe to run multiple times.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="fleetos-webapp"
COMPOSE_PROJECT="${ENV_NAME}-env"

# ---------------------------------------------------------------------------
# Configuration (override via environment variables)
# ---------------------------------------------------------------------------
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
REDIS_PORT="${REDIS_PORT:-6379}"
API_PORT="${API_PORT:-4800}"
REGISTRY_PORT="${REGISTRY_PORT:-4900}"
APP_PORT="${APP_PORT:-3002}"
AGENT_PREVIEW_PORT="${AGENT_PREVIEW_PORT:-4000}"
AGENT_HEALTH_PORT="${AGENT_HEALTH_PORT:-8080}"

DB_NAME="${DB_NAME:-fleetos}"
DB_USER="${DB_USER:-fleetos}"
DB_PASSWORD="${DB_PASSWORD:-fleetos-dev}"

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required but not installed."; exit 1; }

echo "=== FleetOS Webapp Environment Setup ==="
echo "Project: ${COMPOSE_PROJECT}"
echo ""

# ---------------------------------------------------------------------------
# Generate docker-compose.yml if not present
# ---------------------------------------------------------------------------
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "Generating docker-compose.yml..."
  cat > "${COMPOSE_FILE}" <<YAML
version: "3.9"

services:
  postgres:
    image: postgres:16
    ports:
      - "${POSTGRES_PORT}:5432"
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 5s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine
    ports:
      - "${REDIS_PORT}:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10

  api:
    image: fleetos-api:latest
    ports:
      - "${API_PORT}:4800"
    environment:
      DATABASE_URL: "postgresql://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}"
      REDIS_URL: "redis://redis:6379"
      NODE_ENV: development
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  registry:
    image: fleetos-registry:latest
    ports:
      - "${REGISTRY_PORT}:4900"
    environment:
      API_URL: "http://api:4800"
    depends_on:
      - api

  app:
    image: fleetos-app:latest
    ports:
      - "${APP_PORT}:3002"
    environment:
      NEXT_PUBLIC_API_URL: "http://localhost:${API_PORT}"
      NEXT_PUBLIC_REGISTRY_URL: "http://localhost:${REGISTRY_PORT}"
    depends_on:
      - api
      - registry

volumes:
  pgdata:
YAML
  echo "  -> docker-compose.yml created"
fi

# ---------------------------------------------------------------------------
# Start services
# ---------------------------------------------------------------------------
echo ""
echo "Starting services..."
docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_FILE}" up -d

# ---------------------------------------------------------------------------
# Wait for health
# ---------------------------------------------------------------------------
echo ""
echo "Waiting for services to be healthy..."

wait_for_port() {
  local name="$1" port="$2" retries=30
  while ! docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_FILE}" ps --format json 2>/dev/null | grep -q '"Health":"healthy"'; do
    retries=$((retries - 1))
    if [ $retries -le 0 ]; then
      echo "  WARNING: Timed out waiting for ${name} on port ${port}"
      return 1
    fi
    sleep 1
  done
  echo "  ${name} is ready on port ${port}"
}

# Simple port check fallback
check_port() {
  local name="$1" port="$2" retries=30
  while ! nc -z localhost "$port" 2>/dev/null; do
    retries=$((retries - 1))
    if [ $retries -le 0 ]; then
      echo "  WARNING: ${name} not responding on port ${port}"
      return 1
    fi
    sleep 1
  done
  echo "  ${name} is ready on port ${port}"
}

check_port "PostgreSQL" "${POSTGRES_PORT}"
check_port "Redis" "${REDIS_PORT}"
check_port "API" "${API_PORT}"
check_port "Registry" "${REGISTRY_PORT}"
check_port "App" "${APP_PORT}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Environment Ready ==="
echo ""
echo "  Web App:   http://localhost:${APP_PORT}"
echo "  API:       http://localhost:${API_PORT}"
echo "  Registry:  http://localhost:${REGISTRY_PORT}"
echo "  Postgres:  localhost:${POSTGRES_PORT}"
echo "  Redis:     localhost:${REDIS_PORT}"
echo ""
echo "  Agent preview will be on port ${AGENT_PREVIEW_PORT}"
echo "  Agent health check on port ${AGENT_HEALTH_PORT}"
echo ""
echo "To stop:  docker compose -p ${COMPOSE_PROJECT} -f ${COMPOSE_FILE} down"
echo "To reset: bash ${SCRIPT_DIR}/reset.sh"
