# cx-workflow

纯 `cx` 工作流插件，面向 Claude Code 的项目级开发内核。

## 这次 3.0 的重点

- 只保留 `cx`
- 项目级 `.claude/cx` 是唯一运行时真相
- 可见目录与文档中文化，JSON 协议保持英文稳定
- 命令默认自动路由，普通执行尽量少打断
- `--all` 专门用于高自治 agent teams
- GitHub 只作为同步镜像，不承担主控

## 核心命令

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

## 工作流主线

### 新功能

```text
/cx-prd → /cx-design（按需）→ /cx-plan → /cx-exec → /cx-summary
```

### Bug 修复

```text
/cx-fix
```

## 项目级目录

```text
.claude/cx/
├── 配置.json
├── 状态.json
├── 功能/
│   └── 功能标题/
│       ├── 需求.md
│       ├── 设计.md
│       ├── 状态.json
│       ├── 任务/
│       │   └── 任务-1.md
│       └── 总结.md
└── 修复/
    └── 问题标题/
        └── 修复记录.md
```

## 默认行为

- `/cx-plan` 默认轻量，只有明显引入新技术时才额外做技术识别
- `/cx-exec` 默认自动推进当前功能
- `/cx-exec --all` 进入团队模式，按任务图自适应组织 3+ 专业代理
- `/cx-summary` 只负责闭环，不接管执行态

## GitHub 同步

GitHub 是同步镜像，不是运行时真相。

- `off`：完全本地
- `local`：本地为主，闭环时轻量同步
- `collab`：同步关键文档和闭环结果
- `full`：更完整的协作留痕

## 安装与初始化

在项目里运行一次：

```text
/cx-init
```

初始化时会一次性确认：

- `developer_id`
- GitHub 同步模式
- 是否启用 agent teams
- 是否启用 code review
- 是否启用 worktree isolation
- 是否启用 auto memory

## 更多说明

详细协议和行为说明见：

- `references/workflow-guide.md`
- `references/config-schema.json`
- `references/project-status-schema.json`
- `references/feature-status-schema.json`
