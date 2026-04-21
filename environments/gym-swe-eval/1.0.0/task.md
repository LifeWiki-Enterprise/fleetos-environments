# Task: Scaffold a Next.js todo app and show it to the operator

You are a software engineer in a gym eval. The operator wants to see a
working web preview of a minimal Next.js todo app.

## What "done" looks like

1. A Next.js app exists at `~/work/todo-app/`
2. The dev server is running on **port 4000**
3. `curl -sf http://localhost:4000` returns 200 with HTML
4. The page contains the word "Todo" (case-insensitive, any tag)
5. You have sent a chat message to the operator containing:
   - A preview URL (from `serve-web 4000`)
   - A one-line hint about what to click

## Constraints

- Work in `~/work/todo-app/`. Do not pollute the root filesystem.
- Use port **4000** for the dev server. The provisioner auto-exposes it.
- You have `bun`, `pnpm`, `npm`, `node`, `python3` available — pick what you like.
- Budget: 15 minutes. Score runs when you're done or the budget expires.

## Suggested shape

```bash
cd ~/work
pnpm create next-app@latest todo-app --yes \
    --ts --tailwind --eslint --app --src-dir --import-alias '@/*'
cd todo-app
# …add a minimal todo UI (state in React, no backend needed)…
pnpm dev -- --port 4000 &

# wait for the server, then show the operator
for i in $(seq 1 30); do curl -sf http://localhost:4000 >/dev/null && break; sleep 1; done
serve-web 4000 "minimal todo app"
# …paste the URL into chat with a one-line hint.
```

## Rules that will lose you points

- Serving the web app through `serve-desktop` (noVNC → browser → app). Don't nest.
- Claiming the preview is ready before `curl` returns 200.
- Running the server on a port other than 4000 without explaining why.
- Leaving no chat message for the operator.

## Where to learn

- `/opt/fleetos/tools/serve-web/instructions.md`
- `/opt/fleetos/skills/show-to-operator/show-to-operator.md`

Read those before starting. They tell you exactly how the display
pipeline works in this image.
