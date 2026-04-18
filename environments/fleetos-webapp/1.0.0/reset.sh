#!/usr/bin/env bash
# reset.sh — Reset the FleetOS web app environment to clean state
# Run between gym trials to ensure each trial starts fresh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="fleetos-webapp"
COMPOSE_PROJECT="${ENV_NAME}-env"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

DB_NAME="${DB_NAME:-fleetos}"
DB_USER="${DB_USER:-fleetos}"
DB_PASSWORD="${DB_PASSWORD:-fleetos-dev}"

echo "=== Resetting FleetOS Webapp Environment ==="

# ---------------------------------------------------------------------------
# 1. Stop and remove agent container (if running)
# ---------------------------------------------------------------------------
echo ""
echo "[1/4] Stopping agent container..."
AGENT_CONTAINER=$(docker ps -q --filter "label=fleetos.role=agent" --filter "label=fleetos.env=${ENV_NAME}" 2>/dev/null || true)
if [ -n "${AGENT_CONTAINER}" ]; then
  docker stop "${AGENT_CONTAINER}" 2>/dev/null || true
  docker rm -f "${AGENT_CONTAINER}" 2>/dev/null || true
  echo "  -> Agent container removed"
else
  echo "  -> No agent container found (already clean)"
fi

# ---------------------------------------------------------------------------
# 2. Reset database to clean state
# ---------------------------------------------------------------------------
echo ""
echo "[2/4] Resetting database..."
if docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_FILE}" ps postgres 2>/dev/null | grep -q "running"; then
  # Drop and recreate the database
  docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_FILE}" exec -T postgres \
    psql -U "${DB_USER}" -d postgres -c "
      SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();
      DROP DATABASE IF EXISTS ${DB_NAME};
      CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
    " 2>/dev/null
  echo "  -> Database reset to empty state"

  # Re-run migrations if the API has a migrate command
  docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_FILE}" exec -T api \
    sh -c 'if command -v npm >/dev/null 2>&1 && npm run migrate 2>/dev/null; then echo "  -> Migrations applied"; else echo "  -> No migration command found (skipped)"; fi' \
    2>/dev/null || echo "  -> Migration step skipped (API not running or no migrate script)"

  # Re-run seed if available
  docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_FILE}" exec -T api \
    sh -c 'if command -v npm >/dev/null 2>&1 && npm run seed 2>/dev/null; then echo "  -> Seed data applied"; else echo "  -> No seed command found (skipped)"; fi' \
    2>/dev/null || echo "  -> Seed step skipped"
else
  echo "  -> PostgreSQL not running (skipped — run setup.sh first)"
fi

# ---------------------------------------------------------------------------
# 3. Clear Redis cache
# ---------------------------------------------------------------------------
echo ""
echo "[3/4] Clearing Redis cache..."
if docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_FILE}" ps redis 2>/dev/null | grep -q "running"; then
  docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_FILE}" exec -T redis redis-cli FLUSHALL 2>/dev/null
  echo "  -> Redis cache cleared"
else
  echo "  -> Redis not running (skipped)"
fi

# ---------------------------------------------------------------------------
# 4. Clear trial artifacts
# ---------------------------------------------------------------------------
echo ""
echo "[4/4] Clearing trial artifacts..."
rm -rf "${SCRIPT_DIR}/tmp" "${SCRIPT_DIR}/trials" "${SCRIPT_DIR}/recordings"
echo "  -> Local trial artifacts removed"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Reset Complete ==="
echo "Environment is ready for a new trial."
echo "Run 'bash ${SCRIPT_DIR}/setup.sh' if services need to be restarted."
