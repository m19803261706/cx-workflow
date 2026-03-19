# Plan Protocol

## 进入条件

- PRD 已 ready
- 如果 `needs_design = true`，则设计已完成或用户明确跳过

## 问答规则

- 默认轻量拆任务
- 仅当 PRD 明显引入新技术时，才进入技术识别支线

## 完成判定

- feature 级 `状态.json` 已有 tasks / phases / execution_order
- 任务文档已落盘
- shared core feature record 已同步任务清单
- 已给出 preferred worktree 建议

## 落盘文件

- `.claude/cx/功能/<中文标题>/任务/任务-*.md`
- `.claude/cx/core/worktrees/<slug>.json`

## 状态迁移

- feature 中文状态：`planned`
- shared core lifecycle：`planned` 或 `ready`
- `workflow.current_phase = "plan"`
- `workflow.completion_status = "ready"`

## 下一步路由

- `cx-exec`
