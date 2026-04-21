#!/bin/bash
# Build fleetos-swe:latest — the production SWE agent image.
#
# Must be run with build context at LifeWiki-Enterprise root so the
# Dockerfile can COPY sibling fleetos-tools/ and fleetos-skills/ paths.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "Building fleetos-swe:latest..."
echo "  Context:    $ROOT_DIR"
echo "  Dockerfile: $SCRIPT_DIR/Dockerfile"

# Sanity: base image must exist locally (we don't pull from a registry yet)
if ! docker image inspect fleetos-desktop:latest >/dev/null 2>&1; then
    echo "ERROR: base image fleetos-desktop:latest not found." >&2
    echo "Build it first:" >&2
    echo "  cd $ROOT_DIR/fleetos-environments/environments/full-desktop/1.0.0 && docker build -t fleetos-desktop:latest ." >&2
    exit 1
fi

cd "$ROOT_DIR"
docker build \
    -f fleetos-environments/environments/swe/1.0.0/Dockerfile \
    -t fleetos-swe:latest \
    --load \
    "$ROOT_DIR"

echo ""
echo "Built fleetos-swe:latest"
echo ""
echo "Smoke test:"
echo "  docker run --rm fleetos-swe:latest bash -c 'serve-web 4000 test && serve-mobile; exit 0'"
