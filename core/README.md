# CX Core

`cx` 仓库里的共享核心分成两层：

- `control`：共享控制面，负责 feature / session / lease / handoff / worktree
- `workflow`：共享工作流大脑，负责 PRD / Design / Plan / Exec / Fix / Status / Summary 的统一规则

目前控制面协议主要落在这些文件：

- `references/core-schema-overview.md`
- `references/core-project-schema.json`
- `references/core-feature-schema.json`
- `references/core-session-schema.json`
- `references/core-handoff-schema.json`

共享工作流大脑从这里开始：

- `core/workflow/README.md`
- `core/workflow/protocols/*.md`
- `scripts/cx-workflow-prd.sh`

后续原则很明确：

- CC 与 Codex 共用同一套 shared workflow core
- adapter 只负责入口和交互载体，不重新定义流程逻辑
- 共享脚本优先提供确定性落盘与状态迁移，避免不同运行器各自解释协议
