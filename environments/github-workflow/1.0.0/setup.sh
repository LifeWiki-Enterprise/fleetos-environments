#!/usr/bin/env bash
# setup.sh — Set up the GitHub workflow environment
# Verifies the test repo exists, GitHub credentials are valid, and the repo is in a clean state.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="github-workflow"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO="${REPO:-LifeWiki-Enterprise/gym-test-repo}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
BRANCH_PREFIX="${BRANCH_PREFIX:-gym/}"

echo "=== GitHub Workflow Environment Setup ==="
echo "Repo: ${REPO}"
echo "Branch prefix: ${BRANCH_PREFIX}"
echo ""

# ---------------------------------------------------------------------------
# Preflight: verify gh CLI and authentication
# ---------------------------------------------------------------------------
echo "[1/4] Checking prerequisites..."

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) is required but not installed."
  echo "  Install: https://cli.github.com/"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI is not authenticated."
  echo "  Run: gh auth login"
  exit 1
fi

echo "  -> gh CLI authenticated"

# ---------------------------------------------------------------------------
# Verify repo exists and is accessible
# ---------------------------------------------------------------------------
echo ""
echo "[2/4] Verifying repository..."

if gh repo view "${REPO}" >/dev/null 2>&1; then
  echo "  -> Repository ${REPO} exists and is accessible"
else
  echo "WARNING: Repository ${REPO} not found. Creating..."
  gh repo create "${REPO}" --private --description "FleetOS gym test repository" --confirm 2>/dev/null || {
    echo "ERROR: Could not create repository ${REPO}"
    echo "  Create it manually: gh repo create ${REPO} --private"
    exit 1
  }
  echo "  -> Repository created"

  # Initialize with a README
  TMPDIR=$(mktemp -d)
  cd "${TMPDIR}"
  git init -b "${DEFAULT_BRANCH}"
  echo "# Gym Test Repo" > README.md
  echo "" >> README.md
  echo "Test repository for FleetOS gym trials. Do not edit manually." >> README.md
  git add README.md
  git commit -m "Initial commit — FleetOS gym test repo"
  git remote add origin "https://github.com/${REPO}.git"
  git push -u origin "${DEFAULT_BRANCH}"
  cd -
  rm -rf "${TMPDIR}"
  echo "  -> Repository initialized with default branch '${DEFAULT_BRANCH}'"
fi

# ---------------------------------------------------------------------------
# Verify default branch
# ---------------------------------------------------------------------------
echo ""
echo "[3/4] Verifying default branch..."

ACTUAL_DEFAULT=$(gh repo view "${REPO}" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null)
if [ "${ACTUAL_DEFAULT}" = "${DEFAULT_BRANCH}" ]; then
  echo "  -> Default branch is '${DEFAULT_BRANCH}'"
else
  echo "  WARNING: Expected default branch '${DEFAULT_BRANCH}', got '${ACTUAL_DEFAULT}'"
  echo "  Using '${ACTUAL_DEFAULT}' as the default branch"
  DEFAULT_BRANCH="${ACTUAL_DEFAULT}"
fi

# ---------------------------------------------------------------------------
# Record clean state commit SHA
# ---------------------------------------------------------------------------
echo ""
echo "[4/4] Recording clean state..."

CLEAN_SHA=$(gh api "repos/${REPO}/git/ref/heads/${DEFAULT_BRANCH}" --jq '.object.sha' 2>/dev/null)
echo "${CLEAN_SHA}" > "${SCRIPT_DIR}/.clean-sha"
echo "  -> Clean state SHA: ${CLEAN_SHA}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Environment Ready ==="
echo ""
echo "  Repository:     https://github.com/${REPO}"
echo "  Default branch: ${DEFAULT_BRANCH}"
echo "  Clean SHA:      ${CLEAN_SHA}"
echo "  Branch prefix:  ${BRANCH_PREFIX}"
echo ""
echo "  Agent will clone the repo and create PRs with '${BRANCH_PREFIX}' branch prefix."
echo "  User reviews PRs at: https://github.com/${REPO}/pulls"
echo ""
echo "To reset: bash ${SCRIPT_DIR}/reset.sh"
