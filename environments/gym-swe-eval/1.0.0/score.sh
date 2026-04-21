#!/bin/bash
# score.sh — compute a score for the swe-scaffold-nextjs eval.
#
# Called by the gym runner when the session ends (agent declares done,
# budget expires, or runner times out). Emits a JSON result on stdout.
#
# Output shape (stable contract with the runner):
#   {
#     "eval": "swe-scaffold-nextjs",
#     "score": 0.0..1.0,
#     "breakdown": [ {"check": "...", "weight": N, "passed": true|false, "detail": "..."} ],
#     "passed": true|false,      # score >= pass_threshold
#     "pass_threshold": 0.8
#   }
#
# Exit 0 whether the agent passed or failed — the score is the signal.
# Exit non-zero only on scorer bugs.

set -u

# ── Config ────────────────────────────────────────────────────
PASS_THRESHOLD="0.8"
EVAL_NAME="swe-scaffold-nextjs"
APP_DIR="${APP_DIR:-$HOME/work/todo-app}"
PORT="${EXPECTED_PORT:-4000}"

# ── Checks (weighted) ─────────────────────────────────────────
# Each check contributes its weight to the score if it passes.
# Weights sum to 1.0.

declare -a CHECK_NAMES
declare -a CHECK_WEIGHTS
declare -a CHECK_PASSED
declare -a CHECK_DETAILS

record() {
    CHECK_NAMES+=("$1")
    CHECK_WEIGHTS+=("$2")
    CHECK_PASSED+=("$3")
    CHECK_DETAILS+=("$4")
}

# 1. App directory exists  (w=0.15)
if [ -d "$APP_DIR" ]; then
    record "app_dir_exists" "0.15" "true" "$APP_DIR"
else
    record "app_dir_exists" "0.15" "false" "missing $APP_DIR"
fi

# 2. package.json declares Next.js  (w=0.15)
if [ -f "$APP_DIR/package.json" ] \
   && grep -q '"next"' "$APP_DIR/package.json" 2>/dev/null; then
    record "is_nextjs" "0.15" "true" "next in package.json"
else
    record "is_nextjs" "0.15" "false" "no next in package.json"
fi

# 3. Dev server responds on port  (w=0.35) — the weightiest
if curl -sf --max-time 3 "http://localhost:${PORT}" >/dev/null 2>&1; then
    record "server_responds" "0.35" "true" "HTTP 200 on :${PORT}"
else
    record "server_responds" "0.35" "false" "nothing on :${PORT}"
fi

# 4. Rendered page contains "todo" (case-insensitive)  (w=0.20)
BODY=$(curl -sf --max-time 3 "http://localhost:${PORT}" 2>/dev/null || true)
if echo "$BODY" | grep -qi "todo"; then
    record "page_mentions_todo" "0.20" "true" "'todo' found in HTML"
else
    record "page_mentions_todo" "0.20" "false" "'todo' not in HTML"
fi

# 5. serve-web was available (capability sanity) (w=0.05)
if command -v serve-web >/dev/null 2>&1; then
    record "serve_web_available" "0.05" "true" "serve-web on PATH"
else
    record "serve_web_available" "0.05" "false" "serve-web missing"
fi

# 6. No desktop-nested cheating: no Firefox/chrome process pointed at :4000 (w=0.10)
# Heuristic — catches the common "launch-desktop-app firefox http://localhost:4000"
# anti-pattern. Not bullet-proof; the skill docs explain why this is wrong.
if pgrep -af "firefox.*localhost:${PORT}\|chrome.*localhost:${PORT}" >/dev/null 2>&1; then
    record "no_nested_preview" "0.10" "false" "browser pointed at localhost:${PORT} (nested preview)"
else
    record "no_nested_preview" "0.10" "true" "no nested browser preview"
fi

# ── Compute score ─────────────────────────────────────────────
SCORE="0"
for i in "${!CHECK_NAMES[@]}"; do
    if [ "${CHECK_PASSED[$i]}" = "true" ]; then
        SCORE=$(awk -v a="$SCORE" -v b="${CHECK_WEIGHTS[$i]}" 'BEGIN {printf "%.4f", a + b}')
    fi
done

PASSED="false"
if awk -v s="$SCORE" -v t="$PASS_THRESHOLD" 'BEGIN {exit !(s + 0 >= t + 0)}'; then
    PASSED="true"
fi

# ── Emit JSON ─────────────────────────────────────────────────
json_escape() {
    # minimal escaping for the strings we control
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

printf '{\n'
printf '  "eval": "%s",\n' "$EVAL_NAME"
printf '  "score": %s,\n' "$SCORE"
printf '  "pass_threshold": %s,\n' "$PASS_THRESHOLD"
printf '  "passed": %s,\n' "$PASSED"
printf '  "breakdown": [\n'
LAST=$((${#CHECK_NAMES[@]} - 1))
for i in "${!CHECK_NAMES[@]}"; do
    printf '    {"check": "%s", "weight": %s, "passed": %s, "detail": "%s"}' \
        "$(json_escape "${CHECK_NAMES[$i]}")" \
        "${CHECK_WEIGHTS[$i]}" \
        "${CHECK_PASSED[$i]}" \
        "$(json_escape "${CHECK_DETAILS[$i]}")"
    if [ "$i" -lt "$LAST" ]; then printf ','; fi
    printf '\n'
done
printf '  ]\n'
printf '}\n'

exit 0
