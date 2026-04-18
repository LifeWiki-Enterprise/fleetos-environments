# Dockerfile — FleetOS Full Desktop Environment
# Provides a complete Linux desktop accessible via noVNC in the browser.
#
# Build:  docker build -t fleetos-desktop:latest .
# Run:    docker run -d -p 6080:6080 -p 4000:4000 -p 8080:8080 fleetos-desktop:latest

FROM ubuntu:22.04 AS fleetos-desktop

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# System packages — desktop environment + VNC + noVNC
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Desktop environment
    xfce4 \
    xfce4-terminal \
    xfce4-goodies \
    dbus-x11 \
    # VNC server
    tigervnc-standalone-server \
    tigervnc-common \
    # noVNC (web-based VNC client)
    novnc \
    websockify \
    # Browsers
    chromium-browser \
    firefox \
    # Office
    libreoffice-calc \
    libreoffice-writer \
    libreoffice-impress \
    # Utilities
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    net-tools \
    xdg-utils \
    file-roller \
    thunar \
    # Fonts
    fonts-dejavu-core \
    fonts-liberation \
    fonts-noto-color-emoji \
    # Python (for helper scripts)
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# VS Code OSS (code-oss)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends code \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Create agent user
# ---------------------------------------------------------------------------
RUN useradd -m -s /bin/bash -G sudo agent \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ---------------------------------------------------------------------------
# VNC + noVNC configuration
# ---------------------------------------------------------------------------
ENV VNC_PORT=5900 \
    NOVNC_PORT=6080 \
    VNC_RESOLUTION=1920x1080 \
    VNC_COLOR_DEPTH=24 \
    VNC_PASSWORD=fleetos \
    DISPLAY=:1

USER agent
WORKDIR /home/agent

# VNC password file
RUN mkdir -p /home/agent/.vnc \
    && echo "${VNC_PASSWORD}" | vncpasswd -f > /home/agent/.vnc/passwd \
    && chmod 600 /home/agent/.vnc/passwd

# VNC startup config
RUN echo '#!/bin/bash\nstartxfce4 &' > /home/agent/.vnc/xstartup \
    && chmod +x /home/agent/.vnc/xstartup

# ---------------------------------------------------------------------------
# Startup script
# ---------------------------------------------------------------------------
USER root

COPY <<'STARTUP' /usr/local/bin/start-desktop.sh
#!/bin/bash
set -e

# Start VNC server
su - agent -c "vncserver :1 \
  -geometry ${VNC_RESOLUTION} \
  -depth ${VNC_COLOR_DEPTH} \
  -localhost no \
  -SecurityTypes VncAuth \
  -PasswordFile /home/agent/.vnc/passwd"

# Start noVNC (websockify proxy)
websockify --web=/usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} &

echo "Desktop environment ready."
echo "  noVNC: http://localhost:${NOVNC_PORT}/vnc.html"
echo "  VNC:   localhost:${VNC_PORT}"

# Keep container running
tail -f /dev/null
STARTUP
RUN chmod +x /usr/local/bin/start-desktop.sh

# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------
HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD curl -f http://localhost:${NOVNC_PORT}/ || exit 1

# ---------------------------------------------------------------------------
# Expose ports
# ---------------------------------------------------------------------------
EXPOSE 6080 4000 8080

CMD ["/usr/local/bin/start-desktop.sh"]
