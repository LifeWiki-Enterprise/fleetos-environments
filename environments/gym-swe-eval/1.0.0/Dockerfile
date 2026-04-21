# ═══════════════════════════════════════════════════════════════
# fleetos-gym-swe-eval — first SWE eval scenario
#
# Extends fleetos-desktop (NOT fleetos-swe) on purpose: gym and prod
# evolve independently. Gym images carry scoring hooks and synthetic
# state; prod images carry live credentials and real integrations.
# They converge on the capability layer (same display tools + skill).
#
# Baked-in eval task: "Scaffold a Next.js todo app, run it on :4000,
# and show it to the operator." See /opt/gym/task.md.
#
# Build (from LifeWiki-Enterprise root):
#   ./fleetos-environments/environments/gym-swe-eval/1.0.0/build.sh
# ═══════════════════════════════════════════════════════════════

FROM fleetos-desktop:latest

USER root
ENV DEBIAN_FRONTEND=noninteractive

# ── SWE tooling (same as production fleetos-swe) ──────────────
# Keep this list in lockstep with environments/swe/1.0.0/Dockerfile.
# Divergence between gym and prod must be in state/creds/scoring,
# not in capability.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      pkg-config \
      libssl-dev \
      ripgrep \
      fd-find \
      tmux \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://bun.sh/install | bash \
    && ln -s /root/.bun/bin/bun /usr/local/bin/bun

RUN npm install -g pnpm

# ── Display tools + skill (same as fleetos-swe) ───────────────
COPY fleetos-tools/packages/serve-web/1.0.0/      /opt/fleetos/tools/serve-web/
COPY fleetos-tools/packages/serve-desktop/1.0.0/  /opt/fleetos/tools/serve-desktop/
COPY fleetos-tools/packages/serve-mobile/1.0.0/   /opt/fleetos/tools/serve-mobile/

RUN bash /opt/fleetos/tools/serve-web/setup.sh \
    && bash /opt/fleetos/tools/serve-desktop/setup.sh \
    && bash /opt/fleetos/tools/serve-mobile/setup.sh

COPY fleetos-skills/packages/show-to-operator/1.0.0/ \
     /opt/fleetos/skills/show-to-operator/

# ── Eval scaffolding ──────────────────────────────────────────
# task.md is what the agent reads. score.sh is what the gym runner
# invokes at the end of the session to compute a numeric result.
COPY fleetos-environments/environments/gym-swe-eval/1.0.0/task.md   /opt/gym/task.md
COPY fleetos-environments/environments/gym-swe-eval/1.0.0/score.sh  /opt/gym/score.sh
RUN chmod +x /opt/gym/score.sh

# ── Eval metadata (readable by the runner + score.sh) ─────────
# Keep declarative — the runner reads these to label results.
RUN mkdir -p /opt/gym && cat > /opt/gym/eval.yml <<'YAML'
name: swe-scaffold-nextjs
version: "1.0.0"
surface: web
expected_port: 4000
task_file: /opt/gym/task.md
score_file: /opt/gym/score.sh
# Time budget the runner should enforce (seconds).
budget_seconds: 900
YAML

# ── Label so the runner can identify this image ───────────────
LABEL fleetos.image.role=gym-eval \
      fleetos.image.version=1.0.0 \
      fleetos.image.base=fleetos-desktop:latest \
      fleetos.eval.name=swe-scaffold-nextjs

EXPOSE 6080 5901 4000

# Inherit CMD from base (start-desktop.sh).
