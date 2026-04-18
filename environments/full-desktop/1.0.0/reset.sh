#!/usr/bin/env bash
# reset.sh — Reset the full desktop environment to clean state
# Destroys the container and recreates it from the image snapshot.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="full-desktop"
CONTAINER_NAME="${CONTAINER_NAME:-fleetos-desktop-agent}"
IMAGE_NAME="${IMAGE_NAME:-fleetos-desktop:latest}"

VNC_PORT="${VNC_PORT:-6080}"
PREVIEW_PORT="${PREVIEW_PORT:-4000}"
HEALTH_PORT="${HEALTH_PORT:-8080}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1920x1080}"
VNC_PASSWORD="${VNC_PASSWORD:-fleetos}"

echo "=== Resetting Full Desktop Environment ==="

# ---------------------------------------------------------------------------
# 1. Stop and remove existing container
# ---------------------------------------------------------------------------
echo ""
echo "[1/3] Stopping desktop container..."
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
  echo "  -> Container '${CONTAINER_NAME}' removed"
else
  echo "  -> No existing container found"
fi

# ---------------------------------------------------------------------------
# 2. Clear local trial artifacts
# ---------------------------------------------------------------------------
echo ""
echo "[2/3] Clearing trial artifacts..."
rm -rf "${SCRIPT_DIR}/tmp" "${SCRIPT_DIR}/trials" "${SCRIPT_DIR}/recordings"
echo "  -> Local artifacts removed"

# ---------------------------------------------------------------------------
# 3. Start fresh container from image
# ---------------------------------------------------------------------------
echo ""
echo "[3/3] Starting fresh desktop container..."

# Verify image exists
if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "  Image '${IMAGE_NAME}' not found. Building..."
  docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
fi

docker run -d \
  --name "${CONTAINER_NAME}" \
  --label "fleetos.role=agent" \
  --label "fleetos.env=${ENV_NAME}" \
  -p "${VNC_PORT}:6080" \
  -p "${PREVIEW_PORT}:4000" \
  -p "${HEALTH_PORT}:8080" \
  -e "VNC_RESOLUTION=${VNC_RESOLUTION}" \
  -e "VNC_PASSWORD=${VNC_PASSWORD}" \
  "${IMAGE_NAME}"

# Wait for noVNC to be accessible
echo "  Waiting for desktop to be ready..."
RETRIES=30
while ! curl -sf "http://localhost:${VNC_PORT}/" >/dev/null 2>&1; do
  RETRIES=$((RETRIES - 1))
  if [ $RETRIES -le 0 ]; then
    echo "  WARNING: Desktop did not become ready in time"
    break
  fi
  sleep 1
done

echo "  -> Fresh desktop running"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Reset Complete ==="
echo "  noVNC: http://localhost:${VNC_PORT}/vnc.html"
echo "  Password: ${VNC_PASSWORD}"
echo "  Container: ${CONTAINER_NAME}"
echo ""
echo "Environment is ready for a new trial."
