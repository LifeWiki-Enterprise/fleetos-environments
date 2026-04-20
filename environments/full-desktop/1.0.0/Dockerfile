# ═══════════════════════════════════════════════════════════════
# FleetOS Full Desktop — The Universal Gym Computer
#
# A complete Linux desktop accessible via noVNC in the browser.
# Every gym environment is "install software on this computer."
#
# Build:  docker build -t fleetos-desktop:latest .
# Run:    docker run -d -p 6080:6080 --name gym-desktop fleetos-desktop:latest
# Access: http://localhost:6080/vnc.html
#
# Works on both AMD64 and ARM64 (Mac Studio).
# ═══════════════════════════════════════════════════════════════

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# ── System packages ───────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Desktop environment (lightweight)
    xfce4 \
    xfce4-terminal \
    dbus-x11 \
    # VNC
    tigervnc-standalone-server \
    tigervnc-tools \
    # Dev tools
    curl wget git jq \
    ca-certificates \
    openssh-client \
    gnupg \
    software-properties-common \
    vim nano \
    htop \
    # Node.js (for web app environments)
    nodejs npm \
    # Python
    python3 python3-pip python3-venv \
    # File management
    thunar file-roller \
    xdg-utils \
    # Fonts
    fonts-dejavu-core \
    fonts-liberation \
    fonts-noto-color-emoji \
    # Network tools
    net-tools \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# ── Browser: Chromium (via snap-free deb from Ubuntu 22.04 Chromium PPA) ──
# Ubuntu 24.04 ships firefox/chromium as snap which doesn't work in Docker.
# We install chromium from a real .deb source.
RUN add-apt-repository -y ppa:saiarcot895/chromium-dev 2>/dev/null || true \
    && apt-get update \
    && apt-get install -y --no-install-recommends chromium-browser \
    && rm -rf /var/lib/apt/lists/* \
    || ( \
    # Fallback: install Chromium via the snap-free deb from Debian
    apt-get update \
    && apt-get install -y --no-install-recommends chromium \
    && rm -rf /var/lib/apt/lists/* \
    )

# Create symlinks so both 'chromium' and 'google-chrome' work
RUN ln -sf "$(which chromium-browser 2>/dev/null || which chromium)" /usr/local/bin/google-chrome 2>/dev/null || true \
    && ln -sf "$(which chromium-browser 2>/dev/null || which chromium)" /usr/local/bin/chrome 2>/dev/null || true

# ── noVNC (web-based VNC client) ──────────────────────────────
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone --depth 1 https://github.com/novnc/websockify.git /opt/novnc/utils/websockify \
    && ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# ── gh CLI ────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ── Claude Code ───────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

# ── Create agent user ─────────────────────────────────────────
RUN useradd -m -s /bin/bash -G sudo agent \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /home/agent/.vnc /home/agent/.config /home/agent/work

# ── VNC configuration ─────────────────────────────────────────
ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NOVNC_PORT=6080 \
    VNC_RESOLUTION=1920x1080 \
    VNC_DEPTH=24 \
    VNC_PASSWORD=fleetos

# VNC xstartup
RUN printf '#!/bin/bash\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexec startxfce4\n' \
    > /home/agent/.vnc/xstartup \
    && chmod +x /home/agent/.vnc/xstartup \
    && chown -R agent:agent /home/agent/.vnc

# ── Startup script ────────────────────────────────────────────
COPY <<'EOF' /usr/local/bin/start-desktop.sh
#!/bin/bash
echo "================================================"
echo "  FleetOS Desktop Starting"
echo "  Resolution: ${VNC_RESOLUTION}"
echo "  noVNC port: ${NOVNC_PORT}"
echo "================================================"

# Clean up any stale VNC locks
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null

# Start VNC server as agent user
su - agent -c "vncserver :1 \
  -geometry ${VNC_RESOLUTION} \
  -depth ${VNC_DEPTH} \
  -localhost no \
  -SecurityTypes None \
  --I-KNOW-THIS-IS-INSECURE"

echo "[OK] VNC server started on :${VNC_PORT}"

# Wait for VNC to be ready
sleep 3

# Start noVNC (websockify proxy)
/opt/novnc/utils/websockify/run \
  --web /opt/novnc \
  --heartbeat 30 \
  ${NOVNC_PORT} \
  localhost:${VNC_PORT} &

echo "[OK] noVNC started on :${NOVNC_PORT}"
echo ""
echo "  Desktop: http://localhost:${NOVNC_PORT}/vnc.html"
echo ""

# Run environment setup if provided
if [ -f /opt/gym/setup-environment.sh ]; then
  echo "[GYM] Running environment setup..."
  bash /opt/gym/setup-environment.sh
  echo "[GYM] Environment ready."
fi

# Keep container running
echo "[OK] Desktop ready. Waiting..."
tail -f /dev/null
EOF
RUN chmod +x /usr/local/bin/start-desktop.sh

# ── Directories for gym environments ──────────────────────────
RUN mkdir -p /opt/gym /home/agent/work \
    && chown -R agent:agent /home/agent

# ── Health check ──────────────────────────────────────────────
HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD curl -sf http://localhost:${NOVNC_PORT}/ || exit 1

EXPOSE 6080 5901 4000 8080

CMD ["/usr/local/bin/start-desktop.sh"]
