---
name: cx-help
description: "Codex 侧 CX 工作流帮助。解释共享 cx core、可用 skills、lease/handoff/worktree 规则，以及下一步推荐动作。"
---

# CX Help (Codex Adapter)

这是 Codex 侧的 `cx` 帮助入口。

先阅读：

- `../cx-shared/references/codex-skill-contract.md`
- `../cx-shared/references/core-schema-overview.md`

然后按下面的语义回答用户：

- `cx-init`：初始化项目，并确保共享 `cx core` 已建立
- `cx-prd`：新建或补充需求文档，并同步 feature 注册信息
- `cx-design`：写设计文档与契约
- `cx-adr`：沉淀架构决策
- `cx-plan`：拆任务并写任务状态
- `cx-exec`：执行任务，先 worktree 检查，再 claim lease
- `cx-fix`：修复缺陷，必要时先走 handoff
- `cx-status`：读取共享状态与运行器持有情况
- `cx-summary`：在完成后闭环 feature
- `cx-config`：编辑项目级 `配置.json`
- `cx-scope`：做项目或功能蓝图讨论

## Codex 侧必守规则

- 共享真相始终在项目里的 `.claude/cx/core`
- Codex 运行时临时文件只写 `.claude/cx/runtime/codex/`
- 如果 feature 当前由 `cc` 持有，不要静默覆盖，优先建议 handoff
- 同一 feature 未经 handoff 不得跨 worktree 并发执行
- 新项目如果只有旧版 `.claude/cx`，先迁移，再进入双运行器协作
