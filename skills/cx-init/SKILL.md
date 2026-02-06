---
name: cx-init
description: >
  CX 工作流 — 项目初始化。配置开发者信息 (developer_id)、GitHub 同步模式、
  目录结构创建、hooks 安装、CLAUDE.md 智能追加。
  触发词：初始化、init、配置、setup、开始工作流。
  仅在用户明确调用 /cx-init 时执行。不要自动触发。
---

# cx-init — 初始化 CX 工作流环境

## 概述

初始化 CX 工作流环境，包括配置开发者信息、创建本地目录结构、安装 hooks、以及智能追加 CLAUDE.md CX 段落。

## 执行流程

### Step 1: 检测 Git 根目录

```bash
GIT_ROOT=$(git rev-parse --show-toplevel)
```

如果不在 Git 仓库内，提示用户初始化 Git：
```bash
git init
```

### Step 2: 交互式收集初始配置

使用 **AskUserQuestion** 逐步收集：

#### 2.1 开发者标识
```
"请输入你的开发者标识 (developer_id)。
用于功能目录和 commit author 前缀。
例如：cx、alice、bob"

→ 输入: developer_id
```

#### 2.2 GitHub 同步模式
```
"选择 GitHub 同步模式：

① off (默认)
   纯本地开发。cx-summary 仅生成本地 summary.md

② local
   cx-summary 时创建汇总 Issue

③ collab (推荐)
   PRD/Design Doc 创建为 Issue（供团队 review）
   cx-summary 创建汇总 Issue + PR

④ full
   所有文档都创建 Issue（1.0 行为）"

→ 选择: github_sync (off/local/collab/full)
```

#### 2.3 可选高级选项
```
"是否启用高级功能？

① 代码审查 (code_review)
   cx-exec 完成后自动询问是否审查代码

② Agent Teams (agent_teams)
   前后端 agent 按契约分工并行开发
   [实验性，需要 Claude Code 的 Agent Teams 支持]"

→ code_review: true (默认)
→ agent_teams: false (默认，稳定后可开启)
```

### Step 3: 创建目录结构

在 `${GIT_ROOT}/.claude/cx/` 创建：

```
.claude/cx/
├── features/          # 功能目录（动态，每个功能一个子目录）
├── hooks/             # 钩子脚本
├── config.json        # 配置文件（来自 Step 2 的输入）
├── status.json        # 状态文件（执行进度追踪）
└── context-snapshot.md # 上下文快照（compaction 前保存）
```

#### features 目录约定

每个功能创建一个子目录：
```
features/
├── cx-payment/
│   ├── prd.md
│   ├── design.md
│   ├── plan.md
│   ├── status.json
│   └── fix-records.json
└── cx-auth/
    └── ...
```

### Step 4: 生成 config.json

```json
{
  "version": "2.0",
  "developer_id": "cx",
  "github_sync": "collab",
  "current_feature": "",

  "agent_teams": false,
  "background_agents": false,
  "code_review": true,

  "auto_format": {
    "enabled": true,
    "formatter": "auto"
  },

  "hooks": {
    "session_start": true,
    "pre_compact": true,
    "prompt_refresh_interval": 5,
    "stop_verify": true,
    "post_edit_format": true,
    "notification": true,
    "permission_auto_approve": true
  }
}
```

### Step 5: 生成 status.json

```json
{
  "initialized_at": "2026-02-06T10:30:00Z",
  "last_updated": "2026-02-06T10:30:00Z",
  "current_feature": null,
  "features": {},
  "fixes": []
}
```

### Step 6: 检测并更新 CLAUDE.md

#### 6.1 检查是否存在 CLAUDE.md

```bash
if [ -f "${GIT_ROOT}/CLAUDE.md" ]; then
  # 文件存在
else
  # 创建新文件
fi
```

#### 6.2 检查 CX 段落

寻找 `<!-- CX-WORKFLOW-START -->` 和 `<!-- CX-WORKFLOW-END -->` 标记：

```markdown
<!-- CX-WORKFLOW-START -->
...content...
<!-- CX-WORKFLOW-END -->
```

**三种情况处理**：

1. **没有 CLAUDE.md** → 创建新文件（见模板）
2. **有 CLAUDE.md 但没有 CX 段落** → 在末尾追加 CX 段落
3. **有 CLAUDE.md 和 CX 段落** → 替换标记之间的内容

#### 6.3 CX 段落模板

```markdown
<!-- CX-WORKFLOW-START -->
## CX 工作流 (v2.0)

### 命令
/cx-prd <功能名> | /cx-fix <描述> | /cx-exec | /cx-status | /cx-summary

### 活跃任务
暂无活跃任务

### 项目规范
- 待补充

### 开发模式
- developer_id: {developer_id}
- github_sync: {github_sync}
<!-- CX-WORKFLOW-END -->
```

### Step 7: 创建和安装 Hooks

在 `.claude/cx/hooks/` 创建以下脚本（这些脚本由 cx-workflow 插件提供）：

- `session-start.sh` — SessionStart hook
- `pre-compact.sh` — PreCompact hook
- `prompt-submit.sh` — UserPromptSubmit hook
- `post-edit.sh` — PostToolUse hook (async)
- `notification.sh` — Notification hook
- `permission-auto-approve.sh` — PermissionRequest hook

#### 将 hooks 注册到 .claude/settings.json

检查 `.claude/settings.json` 中是否已有 `hooks` 配置。如果没有，追加：

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${PROJECT_ROOT}/.claude/cx/hooks/session-start.sh",
        "timeout": 10
      }]
    }],
    "PreCompact": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${PROJECT_ROOT}/.claude/cx/hooks/pre-compact.sh",
        "timeout": 5
      }]
    }],
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${PROJECT_ROOT}/.claude/cx/hooks/prompt-submit.sh",
        "timeout": 3
      }]
    }],
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "bash ${PROJECT_ROOT}/.claude/cx/hooks/post-edit.sh",
        "timeout": 15,
        "async": true
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "prompt",
        "prompt": "检查当前 cx-workflow 任务：读取 .claude/cx/status.json，如果有 in_progress 的任务但用户没有明确说完成，提醒用户。如果没有活跃任务或用户已确认完成，返回 ok。"
      }]
    }],
    "SubagentStop": [{
      "hooks": [{
        "type": "prompt",
        "prompt": "检查子代理的执行结果：代码是否符合契约？测试是否通过？如果有问题返回 reject 并说明原因。"
      }]
    }],
    "Notification": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${PROJECT_ROOT}/.claude/cx/hooks/notification.sh",
        "timeout": 3
      }]
    }],
    "PermissionRequest": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${PROJECT_ROOT}/.claude/cx/hooks/permission-auto-approve.sh",
        "timeout": 2
      }]
    }]
  }
}
```

### Step 8: 完成提示

```
✅ CX 工作流初始化完成！

📁 创建目录: ${GIT_ROOT}/.claude/cx/
📝 配置文件: ${GIT_ROOT}/.claude/cx/config.json
🔧 已安装 hooks: 7 个
📄 已更新 CLAUDE.md

接下来可以：
1. /cx-status — 查看当前状态
2. /cx-prd <功能名> — 开始新功能需求收集
3. /cx-fix <描述> — 修复 Bug
4. /cx-config — 查看或修改配置

工作流手册: /cx-help
```

## 关键细节

### Git 根目录锚定

所有路径相对于 `$(git rev-parse --show-toplevel)` 计算，确保跨目录调用时定位正确。

### CLAUDE.md CX 段落守卫

- 初始段落≤30 行
- cx-summary 闭环时检查是否有新规范，智能询问是否更新
- 不自动扩展超过 30 行（保护 token 效率）

### 原幂等性

运行多次 cx-init：
- 如果配置已存在，询问是否覆盖
- 不重复创建目录
- 只在必要时修改 CLAUDE.md

### Hook 安全

- Hooks 脚本来自 cx-workflow 插件（已验证）
- PermissionRequest hook 仅放行白名单命令
- 不需要用户手动授权每个 hook

## 故障排查

| 问题 | 解决方案 |
|------|---------|
| 不在 Git 仓库 | 执行 `git init` 后重试 |
| CLAUDE.md 格式异常 | 手动检查文件编码（UTF-8）和行尾格式 |
| Hooks 未执行 | 检查 `.claude/settings.json` 是否正确，hooks 脚本是否可执行 |
| 配置被覆盖 | /cx-init 再次执行时询问是否保留现有配置 |
