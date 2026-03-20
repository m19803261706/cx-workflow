# CX Dashboard Architecture

`cx dashboard` 是共享 `cx core` 之上的全局观察台能力。
它不是新的真相源，而是对多个项目 `.claude/cx` 与 `.claude/cx/core` 的聚合视图。

## Goals

- Keep project-level `.claude/cx` as the only workflow truth.
- Add a global local-only dashboard for multi-project visibility.
- Make `cx:init` and `cx:prd` reuse one bridge helper for dashboard detection, reminder, and auto-registration.
- Keep the first version read-only so the dashboard cannot mutate shared workflow state directly.

## Runtime Layers

### 1. Dashboard Service

`dashboard/service/`

Responsibilities:

- read user-level registry and runtime state
- load project-level `.claude/cx` and shared core summaries
- expose dashboard HTTP APIs
- manage health state and chosen ports
- coordinate manual registration and directory scan flows

Recommended stack:

- Node.js 22+
- TypeScript
- Fastify for local HTTP APIs
- `fs/promises` + `path` for project reads
- `Ajv` for validating dashboard registry/runtime JSON files against repository schemas

This service is the only process allowed to read and aggregate multiple project states for the dashboard UI.

### 2. Dashboard Web

`dashboard/web/`

Responsibilities:

- render project list and project detail pages
- poll dashboard service APIs
- present feature, owner, worktree, handoff, and progress summaries
- expose read-only helper actions such as open directory, copy recommended command, or rescan

Recommended stack:

- React 19
- TypeScript
- Vite
- React Router
- TanStack Query

The web app must not read project files directly.

### 3. Dashboard Contracts

`dashboard/contracts/`

Responsibilities:

- mirror API DTOs used by dashboard service and dashboard web
- keep stable field naming for:
  - `ProjectSummary`
  - `ProjectDetail`
  - `DashboardHealth`
  - `DashboardPromptState`
- map repository JSON schemas to runtime DTO definitions

The repository-level schema files remain the canonical contract for persisted registry/runtime files:

- `references/dashboard-registry-schema.json`
- `references/dashboard-runtime-schema.json`

### 4. Dashboard Bridge

`scripts/cx-dashboard-bridge.sh`

Responsibilities:

- detect whether dashboard service is already reachable
- read user-level prompt state
- decide whether `cx:init` / `cx:prd` should remind the user about the global dashboard
- register the current project when dashboard auto-registration is enabled
- avoid repeated prompts when many CC / Codex windows are open

The bridge is intentionally a shell helper because the high-frequency workflow runners already live in `scripts/*.sh`.

## User-Level Storage

Dashboard state lives outside any single project:

- `~/.cx/dashboard/registry.json`
- `~/.cx/dashboard/runtime.json`

### registry.json

Persistent user preference and project registry:

- prompt state: `unknown | accepted | declined`
- whether auto-registration is enabled
- registered projects
- scan roots and ignored roots
- last seen metadata for project summaries

### runtime.json

Ephemeral local service runtime metadata:

- backend port
- frontend port
- frontend URL
- backend API base URL
- service status
- PID
- last started / checked timestamps
- latest startup error, if any

## Directory Layout

```text
dashboard/
├── service/
│   ├── src/
│   │   ├── routes/
│   │   ├── readers/
│   │   ├── registry/
│   │   ├── runtime/
│   │   └── dto/
│   └── package.json
├── web/
│   ├── src/
│   │   ├── app/
│   │   ├── pages/
│   │   ├── components/
│   │   ├── lib/
│   │   └── api/
│   └── package.json
└── contracts/
    ├── src/
    │   ├── dto/
    │   └── enums/
    └── package.json
scripts/
└── cx-dashboard-bridge.sh
```

This keeps dashboard-specific code explicit without polluting `core/` or adapter-only directories.

## API Surface

First-version routes:

- `GET /api/dashboard/health`
- `GET /api/dashboard/projects`
- `GET /api/dashboard/projects/{projectId}`
- `POST /api/dashboard/projects/register`
- `POST /api/dashboard/projects/scan`
- `GET /api/dashboard/runtime/prompt-state`

The dashboard service reads shared workflow state but does not own it.
Any future command-triggering behavior must be added as a later design wave, not as part of this first read-only surface.

## Port Strategy

- backend preferred base port: `43120`
- frontend preferred base port: `43130`

Startup rule:

1. attempt preferred base port
2. if occupied, increment until a free port is found
3. write chosen ports to `runtime.json`
4. let bridge and adapters consult `runtime.json` before probing health endpoints

## Integration Rules

### `cx:init`

- may call the dashboard bridge after project initialization
- should remind on first use
- must not block project initialization if the user declines dashboard startup

### `cx:prd`

- reuses the same bridge logic
- should avoid repeated first-use prompts once a global decision exists
- should auto-register the project when the dashboard has already been accepted

## First-Version Boundaries

Allowed:

- multi-project project list
- project detail page
- feature / phase / owner / worktree / handoff summaries
- read-only helper actions

Not allowed:

- direct `cx:plan` / `cx:exec` dispatch from the dashboard
- writing project workflow truth from the dashboard UI
- remote/cloud sync concerns

## Why This Shape

This architecture keeps three boundaries stable:

- project `.claude/cx` remains the source of truth
- dashboard service becomes the only global aggregator
- adapters only need one bridge helper to make dashboard behavior feel consistent in both CC and Codex
