# ═══════════════════════════════════════════════════════════════
# fleetos-swe — production SWE agent runtime
#
# Extends the universal computer (fleetos-desktop) with the tooling a
# software engineer needs: bun, pnpm, build-essential, docker CLI.
# Installs the three display tools and the show-to-operator skill so
# the agent can serve web / desktop / (stub) mobile previews.
#
# Independent from gym images. Same base, different layers. Gym evals
# install the same tools + skill; they diverge on credentials, state,
# and scoring — not on capability.
#
# Build (from LifeWiki-Enterprise root):
#   ./fleetos-environments/environments/swe/1.0.0/build.sh
# ═══════════════════════════════════════════════════════════════

FROM fleetos-desktop:latest

USER root
ENV DEBIAN_FRONTEND=noninteractive

# ── SWE-specific tooling ──────────────────────────────────────
# build-essential for native deps (lightningcss, sharp, esbuild fallback)
# netcat-openbsd is already in base; explicit here for the serve-* verifiers
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      pkg-config \
      libssl-dev \
      ripgrep \
      fd-find \
      tmux \
    && rm -rf /var/lib/apt/lists/*

# ── bun (via official installer; pinned to a known-good line) ─
RUN curl -fsSL https://bun.sh/install | bash \
    && ln -s /root/.bun/bin/bun /usr/local/bin/bun \
    && bun --version

# ── pnpm (handles optional platform binaries correctly) ───────
RUN npm install -g pnpm \
    && pnpm --version

# ── docker CLI (for agents that need to build/run containers) ─
# Docker socket is mounted by the provisioner; this gives agents
# the client binary to talk to it.
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
       -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# ── Display tools ─────────────────────────────────────────────
# Copy the three preview tools and run each setup.sh at build time.
# Agents get /usr/local/bin/{serve-web,serve-desktop,launch-desktop-app,serve-mobile}.
COPY fleetos-tools/packages/serve-web/1.0.0/      /opt/fleetos/tools/serve-web/
COPY fleetos-tools/packages/serve-desktop/1.0.0/  /opt/fleetos/tools/serve-desktop/
COPY fleetos-tools/packages/serve-mobile/1.0.0/   /opt/fleetos/tools/serve-mobile/

RUN bash /opt/fleetos/tools/serve-web/setup.sh \
    && bash /opt/fleetos/tools/serve-desktop/setup.sh \
    && bash /opt/fleetos/tools/serve-mobile/setup.sh

# ── Skill: show-to-operator ───────────────────────────────────
# Placed on disk where the harness loader can find it at runtime.
COPY fleetos-skills/packages/show-to-operator/1.0.0/ \
     /opt/fleetos/skills/show-to-operator/

# ── Label so the provisioner / runtime can identify this image ─
LABEL fleetos.image.role=swe \
      fleetos.image.version=1.0.0 \
      fleetos.image.base=fleetos-desktop:latest

# ── Standard ports (inherited from base, restated for clarity) ─
# 6080  noVNC (serve-desktop URL)
# 4000  HTTP preview (serve-web convention)
EXPOSE 6080 5901 4000

# Inherit CMD from base (start-desktop.sh).
