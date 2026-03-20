# Exec Protocol

## 进入条件

- feature 已完成规划
- 已完成工作区选择（worktree 或 inline）
- 当前 runner 已通过 worktree 检查
- 当前 runner 已合法持有 lease

## 问答规则

- 默认自动推进
- 每完成一个 task 后，必须重新调度，而不是在 task 边界自然停下
- 当出现 `2+ ready` 且属于同一 `parallel_group` 的任务时：
  - 普通 `cx-exec` 可以问用户一次是否切到团队模式
  - 若用户未明确切换，则默认继续串行
  - `cx-exec --all` 则直接进入并行推进
- 仅在 4 类关键决策点暂停：
  - 行为路径差异明显
  - 架构 / 契约 / 数据模型变化
  - 高风险或不可逆操作
  - 缺外部信息

## 完成判定

- 当前 wave 或全部可执行任务已完成
- 相关验证已通过
- 共享状态已更新
- 提交信息已带 `[cx:<slug>] [task:<n>]`

## 落盘文件

- feature 级 `状态.json`
- shared core feature / project / session records
- runner-specific runtime artifacts
- exec dispatch 决策输出

## 工作区选择规则

- 每个 feature 首次执行时必须询问用户：创建独立工作区 or 当前分支直接开始
- `worktree_isolation=true` 时默认推荐创建独立工作区
- 使用 Claude Code 内置 `EnterWorktree` 工具创建隔离 worktree
- 用户选择后记录到 feature 状态的 `worktree.isolation_mode`（`worktree` 或 `inline`）
- 后续 resume 同一 feature 时不再重复询问

## 调度规则

- 先调用共享 helper `scripts/cx-workflow-exec-dispatch.sh`
- dispatch helper 负责统一判断：
  - 是否继续当前 `in_progress` 任务
  - 是否选择下一个 `ready` 任务
  - 是否出现可并行任务组，需要提示用户或进入 `--all`
  - 是否已经 `blocked`
  - 是否已经全部完成，应切到 `cx-summary`
- adapter 不能自行发明另一套“下一个任务怎么选”的逻辑

## 状态迁移

- feature 中文状态：`executing / blocked / completed`
- shared core lifecycle：`executing / blocked / completed`
- `workflow.current_phase = "exec"`

## 下一步路由

- 仍有未完成任务：继续 `cx-exec`
- 全部完成：`cx-summary`
