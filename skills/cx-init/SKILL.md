---
name: cx-init
disable-model-invocation: true
description: >
  CX 工作流 — 项目初始化。每个项目都单独确认 developer_id、GitHub 同步策略、
  agent teams、code review、worktree isolation、auto memory，并建立项目级
  `开发文档/CX工作流 + .cx` 运行时真相目录。仅在用户明确调用 `/cx:cx-init` 时执行。
---

# cx-init — 初始化纯 CX 3.1 项目环境

## 概述

`cx:init` 是未来纯 `cx 3.1` 中唯一一次重配置向导。

它负责:

- 为每个项目单独确认 `developer_id`
- 初始化项目级 `开发文档/CX工作流` 与 `.cx`
- 建立项目内 `配置.json` 与 `状态.json`
- 安装插件级 hooks 接线
- 检查 GitHub remote
- 如果没有 remote，默认建议创建 GitHub 仓库并绑定
- 补齐最小项目规则段

初始化完成后，项目应直接可以进入 `/cx:cx-prd` 或 `/cx:cx-fix`。

## 执行原则

- 这是唯一一次集中式配置交互
- 后续命令尽量少打断用户
- 运行时真相保存在项目级 `开发文档/CX工作流` 与 `.cx`
- hooks 由插件层提供，不再复制到项目目录
- Claude Code 插件只是 runner `cc` 的 adapter，不直接拥有项目真相

## 执行流程

### Step 1: 检测项目根目录与 Git 状态

```bash
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

如果当前目录不是 Git 仓库：

- 先建议初始化 Git
- 初始化后再继续

如果检测到已有旧版 `.claude/cx` 但还没有共享 `core/`：

- 不要直接进入双运行器模式
- 先建议运行 `bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-core-migrate.sh`
- 迁移完成后，再继续 `/cx:cx-init` 或后续命令

### Step 2: 一次性收集关键项目配置

使用勾选式问答，按以下顺序确认:

1. `developer_id`
   - 每个项目都单独确认 developer_id
   - 这是项目展示称呼，不再用于 feature 目录命名

2. 是否启用 GitHub 集成

3. 是否已有 GitHub remote
   - 如果没有 remote，默认建议创建 GitHub 仓库并绑定

4. `github_sync`
   - `off`
   - `local`
   - `collab`
   - `full`

5. `agent_teams`
6. `code_review`
7. `worktree_isolation`
8. `auto_memory`

### Step 3: 创建项目级 cx 目录

在项目中创建:

```text
开发文档/CX工作流/
├── 配置.json
├── 状态.json
├── 功能/
└── 修复/
```

同时确保 `.worktrees/` 目录存在且被 `.gitignore` 忽略：

```bash
mkdir -p "$PROJECT_ROOT/.worktrees"
if ! grep -qxF '.worktrees' "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
  echo '.worktrees' >> "$PROJECT_ROOT/.gitignore"
fi
```

约束:

- 目录与文档命名允许中文
- JSON 字段保持英文
- feature 运行时状态以后放在 `功能/<中文标题>/状态.json`
- `current_feature` 始终保存稳定 slug

### Step 4: 生成项目级 配置.json

生成 `开发文档/CX工作流/配置.json`，至少包含:

```json
{
  "version": "3.0",
  "developer_id": "承玄",
  "github_sync": "local",
  "current_feature": "",
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

### Step 5: 生成项目级 状态.json

生成 `开发文档/CX工作流/状态.json`，只做项目索引摘要:

```json
{
  "initialized_at": "2026-03-19T16:00:00Z",
  "last_updated": "2026-03-19T16:00:00Z",
  "current_feature": null,
  "features": {},
  "fixes": {}
}
```

### Step 6: Dashboard 自动保活与项目注册

初始化完成后，确保 dashboard 服务可用并注册当前项目：

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-dashboard-ensure.sh
bridge_output=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-dashboard-bridge.sh \
  --project-root "$PROJECT_ROOT" \
  --display-name "$(basename "$PROJECT_ROOT")")
```

行为规则（与 cx-prd 共享同一套语义）：

**`prompt_state=accepted`：**
- 自动重启已挂的服务，自动注册当前项目
- 告知面板地址

**`prompt_state=pending`：**
- 用 `AskUserQuestion` 询问是否启用
- 不阻塞 init 流程

**`prompt_state=declined`：**
- 距上次检查 > 24h → 重新询问一次
- < 24h → 静默跳过

- 如果 `prompt_state=accepted` 但 `service_running=false`
  - 说明 bridge 启动面板失败或仍未就绪
  - 必须如实告诉用户“接入已记录，但面板暂未成功启动”
  - 不要把仅有 `frontend_url` 或旧 runtime 记录误报成“已经启动”

### Step 7: 校验插件 hooks 依赖条件

项目初始化不再向 `.claude/settings.json` 写入 hooks。

关键点:

- 插件 hooks 由插件自身 `hooks/hooks.json` 自动提供
- 不再复制 hook 到项目运行时目录
- 运行时 hook 只读取项目级 `配置.json` 与 feature 级 `状态.json`
- `cx:init` 只负责告知当前项目已具备被插件 hooks 读取的运行时真相
- 如果项目是旧布局，先迁移到共享 `cx core`，再启用双运行器

### Step 8: 检查并建议 GitHub 接入

如果 `origin` 不存在：

- 告知用户当前没有 GitHub remote
- 默认建议创建 GitHub 仓库并绑定
- 由后续命令或配套脚本完成仓库接入

### Step 9: 更新 CLAUDE.md / AGENTS.md 最小规则

只补最小规则，不塞完整流程实现细节。

建议保留:

- 当前已启用 `cx` 工作流
- 关键项目规范
- 必要的测试或运行说明

## 成功结果

`cx-init` 完成后应满足:

- 项目级 `开发文档/CX工作流/配置.json` 已创建
- 项目级 `开发文档/CX工作流/状态.json` 已创建
- `开发文档/CX工作流/功能/` 与 `开发文档/CX工作流/修复/` 已存在
- GitHub 接入状态已明确
- 项目可以直接进入下一步

## 下一步提示

初始化完成后，默认提示:

- 如果是新功能 → `/cx:cx-prd`
- 如果是缺陷修复 → `/cx:cx-fix`
