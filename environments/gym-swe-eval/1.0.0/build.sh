#!/bin/bash
# Build fleetos-gym-swe-eval:latest — first SWE eval scenario.
#
# Must run with build context at LifeWiki-Enterprise root so the
# Dockerfile can COPY sibling fleetos-tools/, fleetos-skills/, and
# its own task.md / score.sh paths.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "Building fleetos-gym-swe-eval:latest..."
echo "  Context:    $ROOT_DIR"
echo "  Dockerfile: $SCRIPT_DIR/Dockerfile"

if ! docker image inspect fleetos-desktop:latest >/dev/null 2>&1; then
    echo "ERROR: base image fleetos-desktop:latest not found." >&2
    echo "Build it first:" >&2
    echo "  cd $ROOT_DIR/fleetos-environments/environments/full-desktop/1.0.0 && docker build -t fleetos-desktop:latest ." >&2
    exit 1
fi

cd "$ROOT_DIR"
docker build \
    -f fleetos-environments/environments/gym-swe-eval/1.0.0/Dockerfile \
    -t fleetos-gym-swe-eval:latest \
    --load \
    "$ROOT_DIR"

echo ""
echo "Built fleetos-gym-swe-eval:latest"
echo ""
echo "Inspect the baked task:"
echo "  docker run --rm fleetos-gym-swe-eval:latest cat /opt/gym/task.md | head -40"
echo ""
echo "Run the scorer standalone (expect near-zero score — nothing has built yet):"
echo "  docker run --rm fleetos-gym-swe-eval:latest /opt/gym/score.sh"
