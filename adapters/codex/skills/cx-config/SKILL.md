---
name: cx-config
description: "Codex 侧 CX 配置管理。查看或修改项目级 .claude/cx/配置.json，并保持双运行器配置清晰。"
---

# CX Config (Codex Adapter)

`cx-config` 只处理项目级 `配置.json`。

## 可改内容

- `developer_id`
- `github_sync`
- `agent_teams`
- `code_review`
- `auto_memory`
- `worktree_isolation`
- `auto_format`

## 规则

- 不要把执行瞬时状态写进 `配置.json`
- 不要把 lease / handoff / session 信息写进 `配置.json`
- 共享 core 的 `runtime_roots` 由项目注册表维护，不应通过这里随意改写
