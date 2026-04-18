# Environment Specification v1.0

> Canonical reference for the `environment.yml` file format used in FleetOS environments.

## What Is an Environment?

An environment defines the **complete working context** for an AI employee trial. It specifies both sides of the interaction:

- **Agent side** -- the container, tools, and services the agent works inside
- **User side** -- the interfaces and services a human (or simulated user) interacts through
- **Observer side** -- how a third party watches and records what happens

An environment is NOT a harness (how the agent behaves), a tool (what capabilities the agent has), or a skill (what knowledge the agent applies). It is the **stage** on which all of those perform.

---

## File Structure

Each environment lives in a versioned directory:

```
environments/
  {name}/
    {version}/
      environment.yml    # Required. The environment definition.
      setup.sh           # Optional. Script to start all services.
      reset.sh           # Optional. Script to clean state between trials.
      Dockerfile         # Optional. Custom container image for the environment.
      docker-compose.yml # Optional. Multi-service orchestration.
      README.md          # Optional. Environment-specific documentation.
```

---

## `environment.yml` Schema

### Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Unique identifier. Lowercase, hyphens only. Must match directory name. |
| `version` | string | yes | Semantic version (`"1.0.0"`). Must match directory name. |
| `description` | string | yes | One-line human-readable description of the environment. |
| `agent_setup` | object | yes | Configuration for the agent's container and runtime. |
| `user_setup` | object | yes | Configuration for the user-facing interface and services. |
| `services` | list | no | Additional Docker services needed beyond agent and user setup. |
| `observer` | object | yes | How the god view / monitor page works. |
| `reset` | object | yes | How to clean state between trials. |
| `variables` | object | no | Configurable parameters that can be overridden per trial. |

---

### `agent_setup`

Defines what the agent's container needs to function.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `base_image` | string | yes | Docker image to use as the agent's runtime. |
| `ports` | object | no | Named port mappings exposed from the agent container. |
| `ports.preview` | integer | no | Port for web preview (default: `4000`). |
| `ports.health` | integer | no | Port for health check endpoint (default: `8080`). |
| `ports.vnc` | integer | no | Port for VNC/noVNC access (desktop environments). |
| `pre_install` | list[string] | no | Packages to install in the container before the agent starts. |
| `required_tools` | list[string] | no | FleetOS tools that must be available (resolved from the tools registry). |
| `env` | object | no | Environment variables to set in the agent container. |

**Example:**

```yaml
agent_setup:
  base_image: fleetos-base:latest
  ports:
    preview: 4000
    health: 8080
  pre_install:
    - chromium-browser
    - libreoffice
  required_tools:
    - tool-github
  env:
    NODE_ENV: development
```

---

### `user_setup`

Defines what services and interfaces the user interacts with.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `description` | string | yes | Human-readable description of the user experience. |
| `services` | list[object] | no | Services that must run for the user interface. |
| `services[].name` | string | yes | Service identifier. |
| `services[].image` | string | no | Docker image for the service. Mutually exclusive with `command`. |
| `services[].command` | string | no | Shell command to start the service. Mutually exclusive with `image`. |
| `services[].port` | integer | yes | Port the service listens on. |
| `services[].env` | object | no | Environment variables for this service. |
| `services[].depends_on` | list[string] | no | Other services that must start first. |
| `interface` | string | yes | URL template for the primary user interface. Supports `{variable}` substitution. |

**Example:**

```yaml
user_setup:
  description: "User interacts via the FleetOS web app"
  services:
    - name: api
      image: fleetos-api:latest
      port: 4800
    - name: app
      image: fleetos-app:latest
      port: 3002
      depends_on: [api]
  interface: "http://localhost:3002"
```

---

### `services`

Optional top-level list of infrastructure services (databases, caches, message queues) that both agent and user sides depend on.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Service identifier. |
| `image` | string | yes | Docker image. |
| `port` | integer | no | Exposed port. |
| `volumes` | list[string] | no | Volume mounts. |
| `env` | object | no | Environment variables. |

**Example:**

```yaml
services:
  - name: postgres
    image: postgres:16
    port: 5432
    env:
      POSTGRES_DB: fleetos
      POSTGRES_PASSWORD: dev
  - name: redis
    image: redis:7-alpine
    port: 6379
```

---

### `observer`

Defines how the monitoring / god view works for this environment. The observer sees both sides.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `agent_view` | object | yes | How to observe the agent's activity. |
| `agent_view.type` | string | yes | View type: `terminal`, `vnc`, `logs`, `browser`. |
| `agent_view.source` | string | no | Source for the view (e.g., log command). Supports `{variable}` substitution. |
| `agent_view.port` | integer | no | Port for VNC or web-based views. |
| `user_view` | object | yes | How to observe the user's experience. |
| `user_view.type` | string | yes | View type: `browser`, `vnc`, `terminal`. |
| `user_view.url` | string | no | URL for browser-based views. Supports `{variable}` substitution. |
| `user_view.port` | integer | no | Port for VNC-based views. |
| `recording` | object | no | Recording configuration for trial replay. |
| `recording.enabled` | boolean | no | Whether to record trials (default: `true`). |
| `recording.format` | string | no | Recording format: `jsonl` (structured transcript), `video` (screen capture), `both`. |

**Example:**

```yaml
observer:
  agent_view:
    type: terminal
    source: "docker logs -f {container_name}"
  user_view:
    type: browser
    url: "http://localhost:3002"
  recording:
    enabled: true
    format: jsonl
```

---

### `reset`

Defines how to clean state between gym trials. Every environment MUST be resettable.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `steps` | list[string] | yes | Ordered list of human-readable reset steps. |
| `script` | string | no | Path to executable reset script (relative to environment directory). |
| `timeout` | integer | no | Maximum seconds for reset to complete (default: `120`). |

**Example:**

```yaml
reset:
  steps:
    - "Stop and remove agent container"
    - "Reset database to clean state"
    - "Clear message history"
  script: reset.sh
  timeout: 60
```

---

### `variables`

Configurable parameters that can be overridden per trial run. Variables can be referenced anywhere in the YAML using `{variable_name}` syntax.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `{key}` | string | -- | Default value for the variable. |

**Example:**

```yaml
variables:
  repo: "LifeWiki-Enterprise/gym-test-repo"
  branch_prefix: "gym/"
  task_description: "Fix the failing CI checks"
```

Variables are substituted at runtime in any string field that contains `{variable_name}`.

---

## Naming Conventions

- Environment names: lowercase, hyphens, no underscores (`fleetos-webapp`, not `fleetos_webapp`)
- Versions: semantic versioning, always quoted (`"1.0.0"`, not `1.0.0`)
- Service names: lowercase, no hyphens or underscores (`api`, `app`, `postgres`)
- Port assignments: avoid conflicts within a single environment

## Reserved Ports

| Port | Purpose |
|------|---------|
| 4000 | Agent web preview |
| 8080 | Agent health check |
| 6080 | noVNC web client |
| 5900 | VNC server (internal) |

---

## Validation Rules

1. `name` must match the directory name exactly
2. `version` must match the directory version exactly
3. All referenced images must either exist in the FleetOS registry or be public
4. Port numbers must not conflict within a single environment
5. `reset.steps` must be non-empty
6. `agent_setup.base_image` is required and must be a valid image reference
7. `user_setup.interface` is required and must be a valid URL or URL template
8. Variable references (`{name}`) must have a corresponding entry in `variables` or be a well-known runtime variable (`container_name`, `org`, `repo`)

## Well-Known Runtime Variables

These are injected by the FleetOS runtime and do not need to be declared in `variables`:

| Variable | Description |
|----------|-------------|
| `container_name` | Name of the agent's Docker container |
| `trial_id` | Unique identifier for the current gym trial |
| `agent_id` | Identifier of the agent being evaluated |
| `timestamp` | ISO 8601 timestamp of trial start |
