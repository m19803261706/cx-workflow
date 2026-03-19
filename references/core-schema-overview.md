# CX Core Control Plane Schema Overview

`cx core` is the shared control plane for future `CX Core + CC Adapter + Codex Adapter` coordination.
It keeps project-level truth in a runner-neutral model while allowing each runner to keep its own runtime artifacts.

## Design Goals

- Keep a single registry model for projects, features, sessions, and handoffs.
- Make worktree ownership explicit so only one runner holds the execution lease for a feature at a time.
- Separate shared control-plane state from runner-specific runtime files such as logs, prompts, checkpoints, or transcripts.
- Allow adapters to recover state from disk instead of relying on model memory.

## Control Plane Layers

### 1. Project Registry

The project registry is the top-level index for one workspace.
It answers:

- which features exist
- which sessions are currently active
- which feature is the convenience `current_feature` pointer
- where shared and runner-specific runtime roots live

The project registry does not duplicate full feature state forever.
Instead it stores a stable summary keyed by feature slug and points at deeper feature/session records.

### 2. Feature Registry

Each feature record is the unit of planning and execution ownership.
It contains:

- stable identity: `slug`, `title`
- current lifecycle state
- planning owner and execution owner
- bound worktree metadata
- active execution lease
- docs, task registry, and handoff history

This makes a feature portable across runners without changing its identity.

### 3. Active Sessions

Session records model live runner processes or live working contexts.
Each session captures:

- which runner owns it
- which branch and worktree it is attached to
- when it started and last heartbeated
- which feature and tasks it currently claims

The project registry keeps only active sessions.
Historical detail belongs in feature handoffs or runner-specific artifacts.

## Ownership Model

### Execution Lease

The execution lease is the lock that prevents two runners from editing the same feature concurrently.
The lease lives on the feature record and mirrors the currently active session claim:

- `runner`
- `session_id`
- `branch`
- `worktree_path`
- `claimed_feature`
- `claimed_tasks`
- `claimed_at`
- `last_heartbeat`
- `expires_at`

If the lease expires, another runner can safely acquire the feature.

### Handoff Record

A handoff record is the durable transfer note between runners or sessions.
It captures:

- source runner/session identity
- claimed feature and tasks at the handoff boundary
- why the handoff happened
- when it was created
- when it was accepted
- optional target runner/session fields

Handoffs are append-only history.
The active lease is the current truth; the handoff log explains how ownership changed.

### Worktree Binding

Feature execution is bound to a git branch plus a concrete worktree path.
That binding travels through both the feature record and the session record so adapters can:

- recover the correct checkout
- detect stale or missing worktrees
- keep branch ownership visible

One feature may keep the same worktree across multiple sessions and handoffs.

## Runtime Storage Boundaries

### Shared Control Plane State

Shared state is runner-neutral and includes:

- project registry
- feature registry
- session registry
- handoff records
- worktree bindings

### Runner-Specific Runtime Artifacts

Each adapter may keep extra files under its own runtime root, for example:

- `cx`: hook snapshots, command state, local summaries
- `cc`: conversation checkpoints, prompt state, adapter cache
- `codex`: terminal session metadata, execution transcripts, sandbox state

Those artifacts are operational detail, not control-plane truth.
The project schema therefore stores `runtime_roots` so adapters know where to read or write their own files without polluting the shared model.

## Recommended Flow

1. A project registry points to features and active sessions.
2. A runner starts a session and heartbeats it.
3. The runner acquires a feature lease in a bound worktree.
4. The runner updates docs/tasks while the lease is valid.
5. If ownership must move, the runner writes a handoff record.
6. The target runner accepts the handoff and refreshes the feature lease.

This gives `cx core` one durable control plane with adapter-specific runtimes layered on top.
