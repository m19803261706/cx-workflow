---
name: cx-init
description: "Codex 侧 CX 项目初始化。收集项目级配置，建立 .claude/cx，并确保共享 cx core 可立即供 CC 与 Codex 共用。"
---

# CX Init (Codex Adapter)

仅在用户明确要求初始化时执行。

先阅读：

- `../cx-shared/references/codex-skill-contract.md`
- `../cx-shared/references/core-schema-overview.md`

然后按这个顺序执行：

1. 检测项目根目录与 Git 状态
2. 检测 `.claude/cx` 是否已存在
3. 如果已经有 `.claude/cx/core/projects/*.json`
   - 只做健康检查与缺失修复，不重复初始化
4. 如果存在旧版 `.claude/cx/配置.json` / `.claude/cx/状态.json` 但没有 `core/`
   - 先运行 `bash ../cx-shared/scripts/cx-core-migrate.sh`
5. 如果项目尚未初始化
   - 先收集 `developer_id`、`github_sync`、`agent_teams`、`code_review`、`worktree_isolation`、`auto_memory`
   - 运行 `bash ../cx-shared/scripts/cx-init-setup.sh --developer-id ...`
   - 紧接着运行 `bash ../cx-shared/scripts/cx-core-migrate.sh`
6. 初始化完成后，统一调用：
   - `bash ../cx-shared/scripts/cx-dashboard-bridge.sh --project-root "$(git rev-parse --show-toplevel)" --display-name "$(basename "$(git rev-parse --show-toplevel)")"`
7. 如果 bridge 返回 `should_prompt=true`
   - 提醒用户存在全局 Web 管理面板
   - 这是强推荐，不是强制前置
   - 用户接受时执行同一个 bridge helper 并追加 `--decision accept`
   - 用户暂不启用时执行同一个 bridge helper 并追加 `--decision decline`
8. 如果 bridge 返回 `prompt_state=accepted` 且 `auto_register=true`
   - 当前项目应该已经自动注册到全局面板
   - 不要重复询问

## 结果要求

- 项目里有 `.claude/cx/配置.json`
- 项目里有 `.claude/cx/状态.json`
- 项目里有 `.claude/cx/core/projects/project.json`
- 共享 runtime roots 已包含 `codex`
- 后续可以直接进入 `cx-prd` 或 `cx-fix`

## 禁止事项

- 不要写 Claude Code 专用 hooks 到项目 `.claude/settings.json`
- 不要跳过 migrate 直接让 Codex 在旧布局上并行执行
- 不要把 Codex 运行时文件写到 `.claude/cx/runtime/cc/`
