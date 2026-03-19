---
name: cx-plan
description: "Codex 侧 CX 任务规划。读取 PRD/Design，生成任务清单、任务文档与共享状态。"
---

# CX Plan (Codex Adapter)

先阅读：

- `../cx-shared/references/codex-skill-contract.md`
- `../cx-shared/references/templates/task.md`

## 目标

- 生成任务拆分与 `.claude/cx/功能/<标题>/任务/任务-*.md`
- 更新 feature 的任务状态与共享 core 任务列表
- 给出 preferred worktree 建议，但不自动 claim

## 规则

- 只有当 PRD 明显引入新技术时，才额外做技术识别
- 规划阶段不应偷偷拿 lease
- 需要在共享 feature 记录中维护 task ids、task status、preferred worktree 信息

## worktree

- 新 feature 默认建议 `/worktrees/<slug>`
- 默认建议分支 `codex/<slug>`
- 这只是建议，不代表已经绑定或已经执行
