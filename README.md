# cx-workflow

纯 `cx` 工作流仓库，面向共享 `cx core` 的多运行器工作流。

其中：

- Claude Code 侧通过插件命令遵循 2026 官方命名空间规范：`/cx:*`
- Codex 侧通过可安装 skills 使用 `cx-*` 语义

## 这次 3.1 的重点

- 只保留 `cx`
- 插件命名空间正式收敛为 `cx`
- 项目级 `.claude/cx` 是唯一运行时真相
- 可见目录与文档中文化，JSON 协议保持英文稳定
- 命令默认自动路由，普通执行尽量少打断
- 强副作用命令默认手动触发
- `--all` 专门用于高自治 agent teams
- GitHub 只作为同步镜像，不承担主控
- 插件 hooks 通过官方 `hooks/hooks.json` 自动生效，不再由 init 写入项目 settings
- Claude Code 现在被视为共享 `cx core` 上的 `cc` adapter
- Codex 侧现在有独立的可安装 adapter skill 包
- `core/workflow/` 开始承载共享 workflow core，避免 CC 与 Codex 各自维护一套流程脑子

## 核心命令

- `/cx:init`
- `/cx:help`
- `/cx:status`
- `/cx:config`
- `/cx:prd`
- `/cx:design`
- `/cx:adr`
- `/cx:plan`
- `/cx:exec`
- `/cx:fix`
- `/cx:summary`

## 工作流主线

### 新功能

```text
/cx:prd → /cx:design（按需）→ /cx:plan → /cx:exec → /cx:summary
```

### Bug 修复

```text
/cx:fix
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

- `/cx:plan` 默认轻量，只有明显引入新技术时才额外做技术识别
- `/cx:exec` 默认自动推进当前功能
- `/cx:exec --all` 进入团队模式，按任务图自适应组织 3+ 专业代理
- `/cx:summary` 只负责闭环，不接管执行态

## GitHub 同步

GitHub 是同步镜像，不是运行时真相。

- `off`：完全本地
- `local`：本地为主，闭环时轻量同步
- `collab`：同步关键文档和闭环结果
- `full`：更完整的协作留痕

## 安装与初始化

### Claude Code

在项目里运行一次：

```text
/cx:init
```

初始化时会一次性确认：

- `developer_id`
- GitHub 同步模式
- 是否启用 agent teams
- 是否启用 code review
- 是否启用 worktree isolation
- 是否启用 auto memory

### Codex

Codex 侧安装使用仓库自带脚本：

```text
bash scripts/install-codex.sh
```

默认安装到用户级 `~/.agents/skills`。

如果你希望本地开发时跟随当前仓库实时更新，可以改用：

```text
bash scripts/install-codex.sh --mode symlink
```

如果你希望安装到某个项目自己的 skill 目录：

```text
bash scripts/install-codex.sh --scope project --project-root /path/to/project
```

Codex 适配器源码位于：

- `adapters/codex/skills/`
- `adapters/codex/README.md`

## 旧项目迁移

如果项目里已经有旧版 `.claude/cx`，在启用双运行器前先迁移：

```text
bash scripts/cx-core-migrate.sh
```

迁移会：

- 生成共享 `core/projects` / `core/features` / `core/worktrees`
- 保留原有中文文档目录
- 把旧的 root 级 runtime 快照移到 `runtime/cc/`
- 为后续 CC + Codex 协作准备统一真相源

## Rollout 要求

- Claude Code 最低版本：`2.1.79`
- Codex 侧必须同步到新的 `cx core` 契约与技能语义后，才能和 CC 共用同一个项目
- 已有项目先迁移，再开启双运行器；不要在旧 `.claude/cx` 上直接并行使用 CC 和 Codex
- Codex 侧推荐安装到 `.agents/skills`；如需兼容旧本地约定，可额外镜像到 `.codex/skills`

## 更多说明

详细协议和行为说明见：

- `core/README.md`
- `core/workflow/README.md`
- `core/workflow/protocols/`
- `references/workflow-guide.md`
- `docs/codex-adapter-guide.md`
- `references/codex-skill-contract.md`
- `adapters/codex/README.md`
- `references/config-schema.json`
- `references/project-status-schema.json`
- `references/feature-status-schema.json`
