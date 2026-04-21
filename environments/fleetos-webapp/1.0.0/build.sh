#!/bin/bash
# Build the FleetOS webapp gym image.
# Must be run with build context at LifeWiki-Enterprise root so
# the Dockerfile can COPY the sibling repos.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "Building fleetos-gym-webapp:latest..."
echo "  Context: $ROOT_DIR"
echo "  Dockerfile: $SCRIPT_DIR/Dockerfile"

cd "$ROOT_DIR"
docker build \
  -f fleetos-environments/environments/fleetos-webapp/1.0.0/Dockerfile \
  -t fleetos-gym-webapp:latest \
  --load \
  --no-cache \
  "$ROOT_DIR"
