# Exec Protocol

## 进入条件

- feature 已完成规划
- 当前 runner 已通过 worktree 检查
- 当前 runner 已合法持有 lease

## 问答规则

- 默认自动推进
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

## 状态迁移

- feature 中文状态：`executing / blocked / completed`
- shared core lifecycle：`executing / blocked / completed`
- `workflow.current_phase = "exec"`

## 下一步路由

- 仍有未完成任务：继续 `cx-exec`
- 全部完成：`cx-summary`
