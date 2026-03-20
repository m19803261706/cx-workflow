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
- `cx dashboard` 的全局观察台骨架已经锁定：本地服务聚合多项目状态，Web 前端只读展示

## 核心命令

- `/cx:cx-init`
- `/cx:cx-help`
- `/cx:cx-status`
- `/cx:cx-config`
- `/cx:cx-prd`
- `/cx:cx-design`
- `/cx:cx-adr`
- `/cx:cx-plan`
- `/cx:cx-exec`
- `/cx:cx-fix`
- `/cx:cx-summary`

## 工作流主线

### 新功能

```text
/cx:cx-prd → /cx:cx-design（按需）→ /cx:cx-plan → /cx:cx-exec → /cx:cx-summary
```

### Bug 修复

```text
/cx:cx-fix
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

- `/cx:cx-plan` 默认轻量，只有明显引入新技术时才额外做技术识别
- `/cx:cx-exec` 默认自动推进当前功能
- `/cx:cx-exec --all` 进入团队模式，按任务图自适应组织 3+ 专业代理
- `/cx:cx-summary` 只负责闭环，不接管执行态

## GitHub 同步

GitHub 是同步镜像，不是运行时真相。

- `off`：完全本地
- `local`：本地为主，闭环时轻量同步
- `collab`：同步关键文档和闭环结果
- `full`：更完整的协作留痕

## 全局 Web 管理面板

`cx dashboard` 是这套工作流的全局观察台能力。

- 目标：统一查看多个项目的 feature、phase、owner、worktree、handoff 与进度
- 形态：本地服务 + Web 前端
- 边界：第一版只读，不直接触发 `cx:plan` / `cx:exec`
- 高峰入口：`cx:init` 与 `cx:prd` 后续会复用同一套 bridge helper 做面板检测、提醒与自动注册

当前已经锁定的骨架包括：

- 架构文档：`docs/dashboard-architecture.md`
- 用户级注册表 schema：`references/dashboard-registry-schema.json`
- 用户级 runtime schema：`references/dashboard-runtime-schema.json`
- smoke 文档：`docs/dashboard-smoke-test.md`

建议目录结构：

```text
dashboard/
├── service/
├── web/
└── contracts/
scripts/
└── cx-dashboard-bridge.sh
```

第一版本地启动辅助脚本：

- `scripts/cx-dashboard-ensure.sh`
- `scripts/cx-dashboard-open.sh`

其中：

- `cx-dashboard-ensure.sh` 负责顺位选择可用端口并写入 `~/.cx/dashboard/runtime.json`
- `cx-dashboard-open.sh` 负责读取 runtime 清单并打开当前面板地址
- `cx-dashboard-bridge.sh` 负责给 `cx:init / cx:prd` 复用首次提醒与自动注册逻辑

推荐启动顺序：

```text
1. bash scripts/cx-dashboard-ensure.sh
2. BACKEND_PORT=$(jq -r '.backend_port' ~/.cx/dashboard/runtime.json)
3. FRONTEND_PORT=$(jq -r '.frontend_port' ~/.cx/dashboard/runtime.json)
4. REGISTRY_PATH=$(jq -r '.registry_path' ~/.cx/dashboard/runtime.json)
5. (cd apps/dashboard-service && CX_DASHBOARD_REGISTRY_PATH="$REGISTRY_PATH" CX_DASHBOARD_PORT="$BACKEND_PORT" npm start)
6. (cd apps/dashboard-web && npm run dev -- --host 127.0.0.1 --port "$FRONTEND_PORT")
```

自动注册规则：

- 第一次在 `cx:init / cx:prd` 进入项目时，bridge 会提醒用户存在全局面板
- 用户接受后，bridge 会把 `prompt_state` 写成 `accepted`，同时启用 `auto_register=true`
- 后续项目再次进入高频入口时，会默认自动注册，不再重复提醒
- 用户如果暂不启用，也不会阻塞当前工作流

用户级文件约定：

- `~/.cx/dashboard/registry.json`
- `~/.cx/dashboard/runtime.json`

## 安装与初始化

### Claude Code

在项目里运行一次：

```text
/cx:cx-init
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
- `docs/dashboard-architecture.md`
- `docs/dashboard-smoke-test.md`
- `references/dashboard-registry-schema.json`
- `references/dashboard-runtime-schema.json`
