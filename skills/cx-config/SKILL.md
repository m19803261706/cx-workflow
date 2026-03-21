---
name: cx-config
disable-model-invocation: true
description: >
  CX 工作流 — 配置管理。查看或修改项目级 `开发文档/CX工作流/配置.json`
  中公开的少量字段。仅在用户明确调用 `/cx:cx-config` 时执行。
---

# cx-config: 项目配置管理

`cx:config` 只管理项目级公开配置，不暴露实现细节开关。

## 配置来源

运行时只读取：

```text
开发文档/CX工作流/配置.json
```

全局插件配置只用于 `cx:init` 提供默认值，不参与后续运行时决策。

## 公开字段

```json
{
  "version": "3.0",
  "developer_id": "承玄",
  "github_sync": "local",
  "current_feature": "vector-memory",
  "agent_teams": true,
  "code_review": true,
  "auto_memory": true,
  "worktree_isolation": true,
  "auto_format": {
    "enabled": true,
    "formatter": "auto"
  },
  "hooks": {
    "session_start": true,
    "pre_compact": true,
    "post_edit_format": true,
    "notification": true
  }
}
```

## 配置原则

- `developer_id` 每个项目单独确认
- `current_feature` 只是入口指针，不承担主状态机
- 不再公开后台代理、批量模式、简化模式这类实现策略字段
- hook 配置只保留少量开关，不再暴露固定频率提醒

## 典型修改

- 切换 `github_sync`
- 开关 `agent_teams`
- 开关 `code_review`
- 调整 `auto_format.enabled`

## 与初始化的关系

`cx:init` 负责一次性问清关键项目决策；
`cx:config` 负责后续查看和小范围修改，不再重复初始化向导。
