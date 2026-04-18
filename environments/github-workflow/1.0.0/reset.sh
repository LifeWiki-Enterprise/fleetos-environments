#!/usr/bin/env bash
# reset.sh — Reset the GitHub workflow environment to clean state
# Closes gym PRs, deletes gym branches, and optionally resets the default branch.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="github-workflow"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO="${REPO:-LifeWiki-Enterprise/gym-test-repo}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
BRANCH_PREFIX="${BRANCH_PREFIX:-gym/}"
CLEAN_SHA_FILE="${SCRIPT_DIR}/.clean-sha"

echo "=== Resetting GitHub Workflow Environment ==="
echo "Repo: ${REPO}"
echo ""

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) is required."
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI is not authenticated."
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Close all open PRs with gym/ branch prefix
# ---------------------------------------------------------------------------
echo "[1/4] Closing gym PRs..."

GYM_PRS=$(gh pr list --repo "${REPO}" --state open --json number,headRefName \
  --jq ".[] | select(.headRefName | startswith(\"${BRANCH_PREFIX}\")) | .number" 2>/dev/null || true)

if [ -n "${GYM_PRS}" ]; then
  for PR_NUM in ${GYM_PRS}; do
    gh pr close "${PR_NUM}" --repo "${REPO}" --delete-branch 2>/dev/null || true
    echo "  -> Closed PR #${PR_NUM}"
  done
else
  echo "  -> No open gym PRs found"
fi

# ---------------------------------------------------------------------------
# 2. Delete all remote branches with gym/ prefix
# ---------------------------------------------------------------------------
echo ""
echo "[2/4] Deleting gym branches..."

GYM_BRANCHES=$(gh api "repos/${REPO}/git/matching-refs/heads/${BRANCH_PREFIX}" \
  --jq '.[].ref' 2>/dev/null || true)

if [ -n "${GYM_BRANCHES}" ]; then
  for REF in ${GYM_BRANCHES}; do
    BRANCH_NAME="${REF#refs/heads/}"
    gh api -X DELETE "repos/${REPO}/git/ref/heads/${BRANCH_NAME}" 2>/dev/null || true
    echo "  -> Deleted branch: ${BRANCH_NAME}"
  done
else
  echo "  -> No gym branches found"
fi

# ---------------------------------------------------------------------------
# 3. Reset default branch to clean commit (if SHA recorded)
# ---------------------------------------------------------------------------
echo ""
echo "[3/4] Resetting default branch..."

if [ -f "${CLEAN_SHA_FILE}" ]; then
  CLEAN_SHA=$(cat "${CLEAN_SHA_FILE}")
  CURRENT_SHA=$(gh api "repos/${REPO}/git/ref/heads/${DEFAULT_BRANCH}" --jq '.object.sha' 2>/dev/null)

  if [ "${CURRENT_SHA}" = "${CLEAN_SHA}" ]; then
    echo "  -> Default branch already at clean state (${CLEAN_SHA:0:8})"
  else
    # Force update the branch ref to the clean SHA
    gh api -X PATCH "repos/${REPO}/git/refs/heads/${DEFAULT_BRANCH}" \
      -f sha="${CLEAN_SHA}" -F force=true 2>/dev/null
    echo "  -> Default branch reset to ${CLEAN_SHA:0:8}"
  fi
else
  echo "  -> No clean SHA recorded (run setup.sh first to record clean state)"
  echo "  -> Skipping branch reset"
fi

# ---------------------------------------------------------------------------
# 4. Remove agent container
# ---------------------------------------------------------------------------
echo ""
echo "[4/4] Removing agent container..."

AGENT_CONTAINER=$(docker ps -a -q --filter "label=fleetos.role=agent" --filter "label=fleetos.env=${ENV_NAME}" 2>/dev/null || true)
if [ -n "${AGENT_CONTAINER}" ]; then
  docker stop "${AGENT_CONTAINER}" 2>/dev/null || true
  docker rm -f "${AGENT_CONTAINER}" 2>/dev/null || true
  echo "  -> Agent container removed"
else
  echo "  -> No agent container found"
fi

# Clear local artifacts
rm -rf "${SCRIPT_DIR}/tmp" "${SCRIPT_DIR}/trials" "${SCRIPT_DIR}/recordings"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Reset Complete ==="
echo "  All gym PRs closed"
echo "  All gym branches deleted"
if [ -f "${CLEAN_SHA_FILE}" ]; then
  echo "  Default branch at clean state: $(cat "${CLEAN_SHA_FILE}" | head -c 8)"
fi
echo ""
echo "Environment is ready for a new trial."
