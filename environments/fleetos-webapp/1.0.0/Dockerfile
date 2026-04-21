# ═══════════════════════════════════════════════════════════════
# FleetOS Web App Gym Environment
#
# Full-desktop + FleetOS stack PRE-INSTALLED at build time.
# No runtime cloning — services start instantly.
#
# Build: docker build -t fleetos-gym-webapp:latest .
# ═══════════════════════════════════════════════════════════════

FROM fleetos-desktop:latest

USER root

# ── Install bun ───────────────────────────────────────────────
RUN curl -fsSL https://bun.sh/install | bash \
    && ln -s /root/.bun/bin/bun /usr/local/bin/bun

# ── Copy FleetOS repos from local build context (repos are private) ───
# Build context: ../../../../../ (the LifeWiki-Enterprise root)
# This requires building from the root: docker build -f environments/fleetos-webapp/1.0.0/Dockerfile .
RUN mkdir -p /opt/fleetos-repos
COPY fleetos-app /opt/fleetos-repos/fleetos-app
COPY fleetos-api /opt/fleetos-repos/fleetos-api
COPY fleetos-registry /opt/fleetos-repos/fleetos-registry
COPY fleetos-harnesses /opt/fleetos-repos/fleetos-harnesses
COPY fleetos-tools /opt/fleetos-repos/fleetos-tools
COPY fleetos-skills /opt/fleetos-repos/fleetos-skills

# Remove any local node_modules/.next/lock files from the copy
# (will reinstall inside container for correct architecture)
RUN rm -rf /opt/fleetos-repos/fleetos-app/node_modules \
           /opt/fleetos-repos/fleetos-app/.next \
           /opt/fleetos-repos/fleetos-app/package-lock.json \
           /opt/fleetos-repos/fleetos-app/bun.lock \
           /opt/fleetos-repos/fleetos-api/node_modules \
           /opt/fleetos-repos/fleetos-api/bun.lock \
           /opt/fleetos-repos/fleetos-registry/node_modules \
           /opt/fleetos-repos/fleetos-registry/bun.lock \
           /opt/fleetos-repos/fleetos-app/.env.local \
           /opt/fleetos-repos/fleetos-api/.env \
           2>/dev/null || true

# ── Install deps at build time ────────────────────────────────
RUN cd /opt/fleetos-repos/fleetos-registry && bun install
RUN cd /opt/fleetos-repos/fleetos-api && bun install

# Next.js app — install with optional deps (lightningcss native binaries)
# and explicitly install the ARM64 binary
RUN cd /opt/fleetos-repos/fleetos-app \
    && rm -rf node_modules package-lock.json \
    && npm install --legacy-peer-deps --include=optional \
    && npm install lightningcss --legacy-peer-deps --force

# ── Runtime startup script ────────────────────────────────────
COPY <<'SETUP' /opt/gym/setup-environment.sh
#!/bin/bash
echo "[GYM-ENV] Starting FleetOS services..."

REPOS_DIR="/opt/fleetos-repos"

# Create .env files with credentials from container env
cat > $REPOS_DIR/fleetos-api/.env << ENV
SUPABASE_URL=${SUPABASE_URL:-https://pgiyllpriwyaijdfruav.supabase.co}
SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY:-}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
PORT=4800
REGISTRY_URL=http://localhost:4900
ENV

cat > $REPOS_DIR/fleetos-app/.env.local << ENV
NEXT_PUBLIC_SUPABASE_URL=${SUPABASE_URL:-https://pgiyllpriwyaijdfruav.supabase.co}
NEXT_PUBLIC_SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
NEXT_PUBLIC_FLEETOS_API_URL=http://localhost:4800
NEXT_PUBLIC_REGISTRY_URL=http://localhost:4900
ENV

# Start Registry
cd $REPOS_DIR/fleetos-registry
FLEETOS_REPOS_DIR=$REPOS_DIR nohup bun run src/index.ts > /tmp/registry.log 2>&1 &
echo "[GYM-ENV] Registry starting on :4900"

# Start API
cd $REPOS_DIR/fleetos-api
nohup bun run src/index.ts > /tmp/api.log 2>&1 &
echo "[GYM-ENV] API starting on :4800"

# Start Web App (in background, will take ~30s)
cd $REPOS_DIR/fleetos-app
nohup npx next dev --port 3002 > /tmp/app.log 2>&1 &
echo "[GYM-ENV] Web App starting on :3002"

# Wait for web app to be ready (up to 60s)
echo "[GYM-ENV] Waiting for web app..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:3002 >/dev/null 2>&1; then
        echo "[GYM-ENV] Web App ready after ${i}x2s ✓"
        break
    fi
    sleep 2
done

# Open Firefox to the FleetOS web app (as agent user with DISPLAY)
export DISPLAY=:1
su - agent -c "DISPLAY=:1 firefox --new-window http://localhost:3002 &" 2>/dev/null &
sleep 2
echo "[GYM-ENV] FleetOS Web App ready — Firefox opening..."
SETUP
RUN chmod +x /opt/gym/setup-environment.sh

EXPOSE 6080 4000 3002 4800 4900

CMD ["/usr/local/bin/start-desktop.sh"]
