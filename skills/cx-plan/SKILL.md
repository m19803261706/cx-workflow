---
name: cx-plan
description: >
  CX 工作流 — 任务规划与契约下沉。当用户提到"规划任务"、"制定计划"、
  "plan"、"拆分任务"时触发。读取设计文档（小功能则读取 PRD），
  生成任务分解，创建子任务文件并将契约下沉到任务中。
  产物保存到本地 .claude/cx/功能/{feature_title}/任务/。
---

# cx-plan: 任务规划与契约下沉

把需求或设计真正变成能执行的任务图，而不是再写一层描述文档。

先阅读：

- `core/workflow/README.md`
- `core/workflow/protocols/plan.md`

## 使用方法

```text
/cx:cx-plan {功能名}
/cx:cx-plan
```

## 规划原则

- 默认轻量，普通功能直接拆任务
- 仅当 PRD 明显引入新技术时，才进入技术识别和 skill 准备支线
- 任务目录使用中文显示名，状态关联始终用稳定 `slug`
- Claude Code 侧规划属于 runner `cc` 的 adapter 行为；共享 core 被 `codex` 持有时先建议 handoff
- 允许在用户明确确认“进入规划阶段”后，由工作流自动衔接到本 skill

## 核心步骤

### Step 0: 定位 feature 目录

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
CX_DIR="$PROJECT_ROOT/.claude/cx"
FEATURE_TITLE="{功能标题}"
FEATURE_SLUG="{feature-slug}"
FEATURE_DIR="$CX_DIR/功能/$FEATURE_TITLE"
TASK_DIR="$FEATURE_DIR/任务"

mkdir -p "$TASK_DIR"
```

### Step 1: 选择规划输入

- 小功能：直接读取 `需求.md`
- 中大功能：读取 `设计.md`，必要时参考 `需求.md`

不再要求手工传 `--skip-design` 才能走轻量路径。

### Step 2: 新技术判断

仅当 PRD 明显引入新技术时，额外执行：

- 技术栈识别
- 现有项目兼容性检查
- 必要 skill 或外部文档准备

普通功能跳过这条支线，直接进入任务拆分。

### Step 3: 生成任务 DAG

每个任务至少包含：

- `number`
- `title`
- `phase`
- `depends_on`
- `parallel`
- 验收标准
- 关联契约片段

### Step 4: 写入任务文档

任务文件统一为：

```text
.claude/cx/功能/{功能标题}/任务/任务-1.md
.claude/cx/功能/{功能标题}/任务/任务-2.md
```

任务文档里要同时保留：

- 可见中文标题
- 稳定 `slug`
- 目标文件范围
- 契约片段
- 验收标准

### Step 5: 更新 feature 级状态

feature 级 `状态.json` 至少包含：

```json
{
  "feature": "功能标题",
  "slug": "feature-slug",
  "status": "planned",
  "tasks": [
    {
      "number": 1,
      "title": "建立接口骨架",
      "status": "pending"
    }
  ],
  "worktree": {
    "preferred_branch": "codex/vector-memory",
    "preferred_worktree_path": "/worktrees/vector-memory",
    "binding_status": "recommended"
  },
  "docs": {
    "prd": "需求.md",
    "design": "设计.md",
    "summary": "总结.md"
  }
}
```

### Step 6: 输出执行建议

规划完成后默认建议：

```text
下一步：/cx:cx-exec
执行开始时会询问：创建独立工作区 or 当前分支直接开始
```

如果任务图中存在清晰并行组，再在状态中标注 `parallel_group`，供 `/cx:cx-exec --all` 使用。
