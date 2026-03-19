# Core Feature: {title}

- 保存路径：`.claude/cx/core/features/{slug}.json`
- 当前 owner：`{execution_owner_runner}` / `{execution_owner_session_id}`
- worktree：`{worktree_branch}` @ `{worktree_path}` (`{binding_status}`)
- latest handoff：`{latest_handoff_summary}`

## Current Lease

- lease holder：`{lease_runner}` / `{lease_session_id}`
- claimed tasks：`{lease_claimed_tasks}`
- claimed at：`{lease_claimed_at}`
- last heartbeat：`{lease_last_heartbeat}`
- expires at：`{lease_expires_at}`

## Next Allowed Runner Actions

- 如果当前 session 与 lease holder 一致，可以继续执行并刷新 heartbeat。
- 如果目标 runner 已完成合法 handoff 并成为新的 lease holder，可以直接接管后续任务。
- 如果 lease holder 不一致且没有合法 handoff 记录，其他 runner 必须先等待转交或使用 force 路径。

## Handoff Context

- latest handoff record path：`{latest_handoff_record_path}`
- latest handoff accepted at：`{latest_handoff_accepted_at}`
- latest handoff target：`{latest_handoff_target_runner}` / `{latest_handoff_target_session_id}`
