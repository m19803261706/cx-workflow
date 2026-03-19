---
name: cx-help
description: >
  CX 工作流 — 帮助与使用指南。展示纯 cx 3.0 的命令面、自动路由逻辑、
  `--all` 语义和项目级真相模型。
---

# cx-help: 纯 cx 3.0 使用指南

以后只保留 `cx`，不再发展 `tc`。

## 命令面

- `/cx-init`
- `/cx-help`
- `/cx-status`
- `/cx-config`
- `/cx-prd`
- `/cx-design`
- `/cx-adr`
- `/cx-plan`
- `/cx-exec`
- `/cx-fix`
- `/cx-summary`

## 核心体验

- 项目级 `.claude/cx` 是唯一运行时真相
- 命令默认自动路由，不要求你频繁带参数
- 普通执行优先少打断
- `GitHub 为同步镜像`，不是主控面

## 最常用路径

### 新功能

```text
/cx-prd → /cx-design（按需）→ /cx-plan → /cx-exec → /cx-summary
```

### Bug 修复

```text
/cx-fix
```

## `/cx-exec` 和 `--all`

- `/cx-exec`
  默认自动推进当前功能的可执行任务

- `/cx-exec --all`
  进入高自治团队模式，按任务图自适应拆分，并尽可能组织 3+ 专业代理

## 什么时候会暂停问你

只在 4 类关键决策点暂停：

- 多条行为路径且结果差异明显
- 架构 / API / 数据库 / 状态模型变更
- 高风险或不可逆操作
- 需要外部信息
