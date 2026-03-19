# Codex Skill Contract

这份契约定义 Codex 侧 `cx` 技能必须遵守的共享语义。

## 1. 运行器身份

- Codex 在共享控制平面中的固定 runner 名称是 `codex`
- 任何 Codex skill 在写共享状态前，都必须显式带上当前 `session_id`

## 2. 命令语义

Codex 侧允许用 skill 名、别名或自然语言触发，但行为必须和 Claude Code 的 `/cx:*` 语义对齐。

最小命令面：

- `cx-init`
- `cx-prd`
- `cx-design`
- `cx-adr`
- `cx-plan`
- `cx-exec`
- `cx-fix`
- `cx-status`
- `cx-summary`

## 3. 共享状态读写边界

Codex 可以读取：

- project registry
- feature registry
- session registry
- handoff records
- 中文文档：需求 / 设计 / 任务 / 总结 / 修复记录

Codex 可以写入：

- 自己持有 lease 的 feature/task 状态
- 合法 handoff 记录
- `runtime/codex/` 下的私有快照

Codex 不可以写入：

- 未持有 lease 的 feature
- 其他 runner 的 runtime 目录
- 未经 handoff 的跨 worktree 抢占状态

## 4. lease 规则

Codex 在写共享状态前，必须先成功通过：

1. worktree 绑定检查
2. feature / task claim

如果 feature 已由 `cc` 持有：

- 默认拒绝写入
- 优先提示 handoff

## 5. handoff 规则

Codex 必须支持两种 handoff：

- `cc -> codex`
- `codex -> cc`

handoff 最少要保证：

- 记录 source runner / session
- 记录 target runner / session
- 转移 lease
- 保留审计痕迹
- 迁移 task owner

## 6. worktree 规则

- 一个 feature 只能有一个 preferred worktree
- 不同 feature 可以在不同 worktree 并行
- 同一 feature 未经 handoff 不能在两个 worktree 中同时执行

Codex skill 在执行前必须尊重这一层。

## 7. 允许的 UX 偏差

Codex 侧允许和 Claude Code 有这些交互差异：

- 不需要 slash command 形态
- 可以靠 skill 名或自然语言路由
- 没有 Claude Code hooks 时，可用 Codex 自己的恢复方式

但这些差异不能改变共享状态语义。

## 8. 明确禁止项

以下行为视为违反契约：

- 不经过 lease 直接改 feature 状态
- 看到 `cc` owner 后直接覆盖
- 绕过 worktree 检查直接执行
- 把 Codex 的私有快照写进 `runtime/cc/`
- 修改共享状态时不记录 `runner = codex`
