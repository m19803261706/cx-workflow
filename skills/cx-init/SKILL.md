---
name: cx-init
description: >
  CX 工作流 — 项目初始化。每个项目都单独确认 developer_id、GitHub 同步策略、
  agent teams、code review、worktree isolation、auto memory，并建立项目级
  .claude/cx 运行时真相目录。仅在用户明确调用 /cx-init 时执行。
---

# cx-init — 初始化纯 CX 3.0 项目环境

## 概述

`cx-init` 是未来纯 `cx 3.0` 中唯一一次重配置向导。

它负责:

- 为每个项目单独确认 `developer_id`
- 初始化项目级 `.claude/cx`
- 建立项目内 `配置.json` 与 `状态.json`
- 安装插件级 hooks 接线
- 检查 GitHub remote
- 如果没有 remote，默认建议创建 GitHub 仓库并绑定
- 补齐最小项目规则段

初始化完成后，项目应直接可以进入 `/cx-prd` 或 `/cx-fix`。

## 执行原则

- 这是唯一一次集中式配置交互
- 后续命令尽量少打断用户
- 运行时真相只保存在项目级 `.claude/cx`
- hooks 由插件层提供，不再复制到项目目录

## 执行流程

### Step 1: 检测项目根目录与 Git 状态

```bash
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

如果当前目录不是 Git 仓库：

- 先建议初始化 Git
- 初始化后再继续

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
.claude/cx/
├── 配置.json
├── 状态.json
├── 功能/
└── 修复/
```

约束:

- 目录与文档命名允许中文
- JSON 字段保持英文
- feature 运行时状态以后放在 `功能/<中文标题>/状态.json`
- `current_feature` 始终保存稳定 slug

### Step 4: 生成项目级 配置.json

生成 `.claude/cx/配置.json`，至少包含:

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

生成 `.claude/cx/状态.json`，只做项目索引摘要:

```json
{
  "initialized_at": "2026-03-19T16:00:00Z",
  "last_updated": "2026-03-19T16:00:00Z",
  "current_feature": null,
  "features": {},
  "fixes": {}
}
```

### Step 6: 安装插件级 hooks 接线

将插件层 hooks 注册到项目 `.claude/settings.json`。

关键点:

- 使用插件目录下的 hook 脚本
- 不再复制 hook 到项目 `.claude/cx/hooks/`
- 运行时 hook 只读取项目级 `配置.json` 与 feature 级 `状态.json`

### Step 7: 检查并建议 GitHub 接入

如果 `origin` 不存在：

- 告知用户当前没有 GitHub remote
- 默认建议创建 GitHub 仓库并绑定
- 由后续命令或配套脚本完成仓库接入

### Step 8: 更新 CLAUDE.md / AGENTS.md 最小规则

只补最小规则，不塞完整流程实现细节。

建议保留:

- 当前已启用 `cx` 工作流
- 关键项目规范
- 必要的测试或运行说明

## 成功结果

`cx-init` 完成后应满足:

- 项目级 `.claude/cx/配置.json` 已创建
- 项目级 `.claude/cx/状态.json` 已创建
- `.claude/cx/功能/` 与 `.claude/cx/修复/` 已存在
- `.claude/settings.json` 已接入插件 hooks
- GitHub 接入状态已明确
- 项目可以直接进入下一步

## 下一步提示

初始化完成后，默认提示:

- 如果是新功能 → `/cx-prd`
- 如果是缺陷修复 → `/cx-fix`
