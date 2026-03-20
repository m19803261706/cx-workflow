# Plan Protocol

## 进入条件

- PRD 已 ready
- 如果 `needs_design = true`，则设计已完成或用户明确跳过

## 问答规则

- 默认轻量拆任务
- 仅当 PRD 明显引入新技术时，才进入技术识别支线

## 共享契约规则

- 任务图涉及 2+ 层级时，**MUST** 先生成 `契约.md` 再拆任务
- 契约定义 API 路径、请求/响应结构、数据模型、枚举
- 前端任务引用契约中的路径，禁止自行猜测
- 后端任务如果修改了路径，必须同步更新契约

## 完成判定

- feature 级 `状态.json` 已有 tasks / phases / execution_order
- 跨层功能已生成 `契约.md`
- 任务文档已落盘，且每个任务引用了契约条目
- shared core feature record 已同步任务清单
- 已给出 preferred worktree 建议

## 落盘文件

- `.claude/cx/功能/<中文标题>/契约.md`（跨层时）
- `.claude/cx/功能/<中文标题>/任务/任务-*.md`
- `.claude/cx/core/worktrees/<slug>.json`

## 状态迁移

- feature 中文状态：`planned`
- shared core lifecycle：`planned` 或 `ready`
- `workflow.current_phase = "plan"`
- `workflow.completion_status = "ready"`

## 下一步路由

- `cx-exec`
