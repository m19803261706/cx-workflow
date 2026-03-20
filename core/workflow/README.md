# Shared Workflow Core

`shared workflow core` 是 `cx` 的统一工作流大脑。

它不区分 Claude Code 还是 Codex，只定义：

- 何时进入某个阶段
- 该阶段应该如何问答与收敛
- 什么时候算完成
- 要写哪些文件
- 要怎样迁移共享状态
- 下一步应该路由到哪里

## 设计目标

- 让 `PRD / Design / Plan / Exec / Fix / Status / Summary` 的逻辑只维护一套
- 让 `cc` 与 `codex` 只是 adapter，而不是两套工作流
- 让 feature 能在两个运行器之间安全 handoff，而不会因为流程理解不同而失真
- 为确定性脚本 runner 提供统一协议来源

## 分层边界

### Shared Control Core

控制面负责：

- project registry
- feature registry
- active sessions
- lease / claim
- handoff
- worktree binding

### Shared Workflow Core

工作流层负责：

- PRD 问答节奏与收敛
- Design 的进入条件与契约沉淀
- Plan 的任务拆分与 worktree 推荐
- Exec 的推进、阻塞、验证与提交规则
- Fix 的轻量路径与升级条件
- Status 的展示重点与下一步建议
- Summary 的闭环条件与结果沉淀

### Adapters

adapter 只负责：

- 入口形式
- 交互载体
- 运行器本地 runtime 文件
- 调用 shared workflow core 的协议和脚本

adapter 不负责重新发明流程。

## 当前实现批次

第一批 shared workflow core 先落这两部分：

1. 协议文档
   - `core/workflow/protocols/*.md`
2. 确定性 runner
   - `scripts/cx-workflow-prd.sh`

这一批优先解决最先暴露的问题：

- Codex 侧 `cx-prd` 能命中 skill，但落盘不够确定
- CC 与 Codex 对 PRD 的问答与状态迁移不应该各写一套

## Phase Contract

每个 phase 协议都必须固定回答这 6 个问题：

1. 进入条件
2. 问答/收敛规则
3. 完成判定
4. 落盘文件
5. 状态迁移
6. 下一步路由

## Shared Workflow State

feature 级中文状态文件和 shared core feature record 都允许带同一段 `workflow` 元信息：

- `protocol_version`
- `current_phase`
- `completion_status`
- `question_mode`
- `size`
- `needs_design`
- `needs_adr`
- `next_route`
- `decision_basis`
- `last_transition_at`

这不是为了把所有逻辑塞进 JSON，而是为了让两个运行器在切换时看到同一套阶段真相。

## User Prompt Contract

工作流中需要用户做选择的场景（工作区模式、合并方式、审查级别等），
两个 adapter 必须遵守各自的交互规则：

### Claude Code (cc)

**MUST** 使用 `AskUserQuestion` 工具呈现选项。禁止用纯文字列选项代替。

`AskUserQuestion` 支持：
- 结构化选项（2-4 个，含 label + description）
- 单选 / 多选（`multiSelect`）
- 推荐项放首位并标 `(Recommended)`
- 自动提供 "Other" 兜底输入

### Codex

Codex 没有 `AskUserQuestion` 工具。**MUST** 使用编号文字列表 + 等待用户回复的降级方案：

```
问题描述：

1. 选项 A（推荐）— 说明
2. 选项 B — 说明

请回复编号：
```

### 结果记录

无论哪个 adapter，用户选择的结果都以相同格式写入共享状态（如 `worktree.isolation_mode`），
保证跨运行器 handoff 时状态一致。
