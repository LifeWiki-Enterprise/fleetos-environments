# ═══════════════════════════════════════════════════════════════
# FleetOS Web App Gym Environment
#
# The full-desktop computer + FleetOS web app running inside.
# The agent works on code, the user sees the app via noVNC.
#
# Build:  docker build -t fleetos-gym-webapp:latest .
# Run:    docker run -d -p 6080:6080 -p 4000:4000 --name gym-webapp fleetos-gym-webapp:latest
# Access: http://localhost:6080/vnc.html (desktop with FleetOS app)
# ═══════════════════════════════════════════════════════════════

FROM fleetos-desktop:latest

USER root

# ── Install bun (for running the FleetOS API + registry) ──────
RUN curl -fsSL https://bun.sh/install | bash \
    && ln -s /root/.bun/bin/bun /usr/local/bin/bun

# ── Copy FleetOS app source into the environment ──────────────
# These get cloned from GitHub at setup time, but we pre-create dirs
RUN mkdir -p /opt/fleetos-app /opt/fleetos-api /opt/fleetos-registry

# ── Setup script: clones repos, installs deps, starts services ─
COPY <<'SETUP' /opt/gym/setup-environment.sh
#!/bin/bash
echo "[GYM-ENV] Setting up FleetOS Web App environment..."

# Clone the FleetOS repos (or use pre-installed)
REPOS_DIR="/opt/fleetos-repos"
mkdir -p $REPOS_DIR

# Clone from GitHub if not already present
if [ ! -d "$REPOS_DIR/fleetos-app/.git" ]; then
    echo "[GYM-ENV] Cloning FleetOS repos..."
    cd $REPOS_DIR
    git clone --depth 1 https://github.com/LifeWiki-Enterprise/fleetos-app.git 2>/dev/null || true
    git clone --depth 1 https://github.com/LifeWiki-Enterprise/fleetos-api.git 2>/dev/null || true
    git clone --depth 1 https://github.com/LifeWiki-Enterprise/fleetos-registry.git 2>/dev/null || true
    git clone --depth 1 https://github.com/LifeWiki-Enterprise/fleetos-harnesses.git 2>/dev/null || true
    git clone --depth 1 https://github.com/LifeWiki-Enterprise/fleetos-tools.git 2>/dev/null || true
    git clone --depth 1 https://github.com/LifeWiki-Enterprise/fleetos-skills.git 2>/dev/null || true
    echo "[GYM-ENV] Repos cloned."
fi

# Install deps and start services
echo "[GYM-ENV] Installing dependencies..."

# Registry
if [ -d "$REPOS_DIR/fleetos-registry" ]; then
    cd $REPOS_DIR/fleetos-registry
    bun install --frozen-lockfile 2>/dev/null || bun install
    FLEETOS_REPOS_DIR=$REPOS_DIR bun run src/index.ts &
    echo "[GYM-ENV] Registry starting on :4900"
fi

# API
if [ -d "$REPOS_DIR/fleetos-api" ]; then
    cd $REPOS_DIR/fleetos-api
    bun install --frozen-lockfile 2>/dev/null || bun install

    # Create .env for the API
    cat > .env << ENV
SUPABASE_URL=${SUPABASE_URL:-https://pgiyllpriwyaijdfruav.supabase.co}
SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY:-}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
PORT=4800
REGISTRY_URL=http://localhost:4900
GITHUB_APP_ID=${GITHUB_APP_ID:-}
GITHUB_APP_INSTALLATION_ID=${GITHUB_APP_INSTALLATION_ID:-}
GITHUB_APP_PRIVATE_KEY=${GITHUB_APP_PRIVATE_KEY:-}
ENV
    bun run src/index.ts &
    echo "[GYM-ENV] API starting on :4800"
fi

# Web App
if [ -d "$REPOS_DIR/fleetos-app" ]; then
    cd $REPOS_DIR/fleetos-app
    npm install 2>/dev/null || true

    # Create .env.local
    cat > .env.local << ENV
NEXT_PUBLIC_SUPABASE_URL=${SUPABASE_URL:-https://pgiyllpriwyaijdfruav.supabase.co}
NEXT_PUBLIC_SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
NEXT_PUBLIC_FLEETOS_API_URL=http://localhost:4800
NEXT_PUBLIC_REGISTRY_URL=http://localhost:4900
ENV
    npx next dev --port 3002 &
    echo "[GYM-ENV] Web App starting on :3002"
fi

# Wait for services to be ready
echo "[GYM-ENV] Waiting for services..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:4800/healthz >/dev/null 2>&1; then
        echo "[GYM-ENV] API ready ✓"
        break
    fi
    sleep 2
done

for i in $(seq 1 30); do
    if curl -sf http://localhost:3002 >/dev/null 2>&1; then
        echo "[GYM-ENV] Web App ready ✓"
        break
    fi
    sleep 2
done

# Open Firefox to the FleetOS web app
su - agent -c "DISPLAY=:1 firefox http://localhost:3002 &" 2>/dev/null || true

echo "[GYM-ENV] FleetOS Web App environment ready!"
echo "[GYM-ENV] Desktop: http://localhost:6080/vnc.html"
echo "[GYM-ENV] Web App: http://localhost:3002 (inside desktop)"
SETUP
RUN chmod +x /opt/gym/setup-environment.sh

# ── Expose ports ──────────────────────────────────────────────
# 6080: noVNC (desktop viewer)
# 4000: Preview port (agent's dev server)
# 3002: FleetOS web app (inside the environment)
# 4800: FleetOS API (inside the environment)
# 4900: Registry (inside the environment)
EXPOSE 6080 4000 3002 4800 4900

CMD ["/usr/local/bin/start-desktop.sh"]
