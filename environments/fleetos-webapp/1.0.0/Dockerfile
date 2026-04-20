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

# ── Clone FleetOS repos at BUILD time (not runtime) ───────────
RUN mkdir -p /opt/fleetos-repos && cd /opt/fleetos-repos \
    && git clone --depth 1 https://github.com/LifeWiki-Enterprise/fleetos-app.git \
    && git clone --depth 1 https://github.com/LifeWiki-Enterprise/fleetos-api.git \
    && git clone --depth 1 https://github.com/LifeWiki-Enterprise/fleetos-registry.git \
    && git clone --depth 1 https://github.com/LifeWiki-Enterprise/fleetos-harnesses.git \
    && git clone --depth 1 https://github.com/LifeWiki-Enterprise/fleetos-tools.git \
    && git clone --depth 1 https://github.com/LifeWiki-Enterprise/fleetos-skills.git

# ── Install deps at build time ────────────────────────────────
RUN cd /opt/fleetos-repos/fleetos-registry && bun install
RUN cd /opt/fleetos-repos/fleetos-api && bun install
RUN cd /opt/fleetos-repos/fleetos-app && npm install --legacy-peer-deps

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

# Open Chromium to the FleetOS web app (as agent user with DISPLAY)
export DISPLAY=:1
BROWSER_CMD=$(which chromium-browser 2>/dev/null || which chromium || which google-chrome)
su - agent -c "DISPLAY=:1 $BROWSER_CMD --no-sandbox --disable-dev-shm-usage --start-maximized http://localhost:3002 &" 2>/dev/null || \
    DISPLAY=:1 $BROWSER_CMD --no-sandbox --disable-dev-shm-usage --start-maximized http://localhost:3002 &

echo "[GYM-ENV] FleetOS Web App ready — Browser opening..."
SETUP
RUN chmod +x /opt/gym/setup-environment.sh

EXPOSE 6080 4000 3002 4800 4900

CMD ["/usr/local/bin/start-desktop.sh"]
