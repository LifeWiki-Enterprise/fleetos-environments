# fleetos-environments

Environment packages for FleetOS. Each environment defines the complete working context for an AI employee -- the container it works in, the interfaces users interact through, and the monitoring layer that observes both sides.

## What Is an Environment?

An environment is one of the four registries in FleetOS:

| Registry | What It Contains | Example |
|----------|-----------------|---------|
| **Environments** | Working contexts (this repo) | `fleetos-webapp`, `full-desktop`, `github-workflow` |
| **Harnesses** | Behavioral configurations | How the agent thinks, what guardrails it follows |
| **Tools** | Capabilities | GitHub integration, browser control, file editing |
| **Skills** | Knowledge packages | Code review expertise, documentation writing |

An environment is the **stage**. It defines:

- **Agent side** -- what container image to use, what ports to expose, what software to pre-install
- **User side** -- what services run for the human interface (web app, Slack, GitHub)
- **Observer side** -- how a third party watches the trial (terminal logs, VNC, screen recording)
- **Reset procedure** -- how to clean everything between trials

Environments do NOT define agent behavior (that's the harness), agent capabilities (that's tools), or agent knowledge (that's skills).

## Available Environments

### `fleetos-webapp` (v1.0.0)
The FleetOS web app as the working environment. The agent works inside a container with a code preview. The user interacts through the FleetOS web interface (API + app + registry). Observer sees terminal logs on the agent side and the web app on the user side.

### `full-desktop` (v1.0.0)
A full Linux desktop with browser, terminal, file manager, and office apps. The agent operates a graphical desktop via VNC. The user and observer both see the same desktop through noVNC. Useful for general-purpose tasks, browser-based work, and document editing.

### `github-workflow` (v1.0.0)
GitHub-native workflow. The agent clones a repo, writes code, and creates pull requests. The user reviews PRs on github.com. Minimal infrastructure -- just the agent container and GitHub. Good for code review, bug fixing, and feature implementation trials.

## Directory Structure

```
fleetos-environments/
  ENVIRONMENT_SPEC.md          # Canonical spec for environment.yml
  README.md                    # This file
  environments/
    {name}/
      {version}/
        environment.yml        # Required -- the environment definition
        setup.sh               # Optional -- start all services
        reset.sh               # Optional -- clean state between trials
        Dockerfile             # Optional -- custom container image
        docker-compose.yml     # Optional -- multi-service orchestration
```

## Creating a New Environment

### 1. Create the directory

```bash
mkdir -p environments/{name}/{version}
```

### 2. Write `environment.yml`

See [ENVIRONMENT_SPEC.md](ENVIRONMENT_SPEC.md) for the full schema. Minimum viable environment:

```yaml
name: my-environment
version: "1.0.0"
description: "Short description of the working context"

agent_setup:
  base_image: fleetos-base:latest

user_setup:
  description: "How the user interacts"
  interface: "http://localhost:3000"

observer:
  agent_view:
    type: terminal
    source: "docker logs -f {container_name}"
  user_view:
    type: browser
    url: "http://localhost:3000"
  recording:
    enabled: true
    format: jsonl

reset:
  steps:
    - "Stop and remove agent container"
```

### 3. Add setup and reset scripts (recommended)

- `setup.sh` -- idempotent script that starts all services the environment needs
- `reset.sh` -- script that returns the environment to a clean state

### 4. Add a Dockerfile (if needed)

Only needed when the environment requires a custom image beyond `fleetos-base:latest`. For example, `full-desktop` needs a desktop environment with VNC.

### 5. Test it

```bash
# Start the environment
cd environments/{name}/{version}
bash setup.sh

# Verify all services are running
curl http://localhost:8080/health

# Reset and verify clean state
bash reset.sh
```

## Design Principles

1. **Environments are reproducible.** Anyone with Docker can start one from scratch.
2. **Environments are resettable.** Every trial starts from the same clean state.
3. **Environments are versioned.** Breaking changes get a new version directory.
4. **Environments are self-contained.** All dependencies are declared, nothing assumed.
5. **Environments separate concerns.** Agent behavior, tools, and skills come from other registries.

## License

Proprietary -- LifeWiki Enterprise.
