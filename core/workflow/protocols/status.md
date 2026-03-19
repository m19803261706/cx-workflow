# Status Protocol

## 进入条件

- 任何时刻都可进入

## 问答规则

- 不做发散讨论，重点回答“现在做到哪了、卡在哪、下一步是什么”

## 完成判定

- 已展示当前 feature / owner / lease / worktree / blocked 信息
- 已给出下一步推荐动作

## 落盘文件

- 默认无新增持久化文件
- 允许写 runner-specific runtime snapshot

## 状态迁移

- `status` 是观察动作，不主动迁移 feature 生命周期

## 下一步路由

- 无活跃 feature：`cx-prd` 或 `cx-fix`
- 已规划未执行：`cx-exec`
- 已完成待闭环：`cx-summary`
