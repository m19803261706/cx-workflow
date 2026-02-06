---
name: cx-plan
description: >
  CX 工作流 — 任务规划与契约下沉。当用户提到"规划任务"、"制定计划"、
  "plan"、"拆分任务"时触发。读取 Design Doc（或 PRD for S 规模）
  生成任务分解，创建子任务文件 task-{n}.md，每个任务包含设计文档中的
  API 契约片段。保存到本地 .claude/cx/features/{dev_id}-{feature}/tasks/。
---

# cx-plan: 任务规划与契约下沉

读取设计文档，生成分阶段任务分解，将 API 契约下沉到各子任务，使 exec 阶段无需翻阅设计文档即可按契约实现。

## 使用方法

```
/cx-plan {功能名}              # 指定功能创建任务规划
/cx-plan                      # 使用最近的 Design Doc（或 PRD for S 规模）
/cx-plan --skip-design {功能} # S 规模功能直接从 PRD 创建计划
```

## 核心步骤

### Step 0: 初始化本地环境

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
DEVELOPER_ID=$(jq -r '.developer_id' "$PROJECT_ROOT/.claude/cx/config.json" 2>/dev/null || echo "cx")
FEATURE_DIR="$PROJECT_ROOT/.claude/cx/features/${DEVELOPER_ID}-{feature_slug}"
mkdir -p "$FEATURE_DIR/tasks"
```

### Step 1: 读取设计文档

```bash
if [[ "$ARGUMENTS" == *"--skip-design"* ]]; then
  # S 规模：直接读取 PRD
  DESIGN_DOC_PATH=""
  PRD_PATH="$FEATURE_DIR/prd.md"
else
  # 正常：读取 Design Doc
  DESIGN_DOC_PATH="$FEATURE_DIR/design.md"
  PRD_PATH="$FEATURE_DIR/prd.md"
fi
```

### Step 2: 提取 API 契约片段

从 Design Doc 中提取三大契约信息：
1. **API 契约** — 接口路径 + 请求体 + 响应体
2. **状态枚举对照表** — 后端常量 / API 传输值 / 前端常量
3. **VO/DTO 字段映射** — DB 字段 → DTO → 前端字段

将这些契约按接口/功能点编号，便于任务引用。

### Step 3: 任务细化与并行标注

基于 Design Doc 中的模块划分和代码影响范围，细化任务列表：

**分阶段划分**：
```yaml
phases:
  - phase: 1
    name: "数据层"
    tasks:
      - number: 1
        title: "数据库表设计"
        description: "{description}"
        labels: ["backend"]
        parallel: true
        depends_on: []
        related_apis: []           # API 契约编号
        related_enums: []          # 状态枚举
        related_fields: [1,2]      # 字段映射编号
        acceptance:
          - "创建数据库表，符合 Design Doc 数据库设计"
          - "索引和约束按设计要求"

  - phase: 2
    name: "后端服务"
    tasks:
      - number: 2
        title: "REST API 实现"
        description: "{description}"
        labels: ["backend"]
        parallel: false
        depends_on: [1]
        related_apis: [1, 2, 3]    # 该任务实现的 API 接口编号
        related_enums: ["StatusEnum"]
        related_fields: [1,2,3,4,5]
        acceptance:
          - "接口路径与 API 契约一致"
          - "请求/响应字段与 VO/DTO 映射表一致"
          - "状态枚举值与对照表一致"
```

### Step 4: 创建本地任务文件

为每个任务创建 `task-{n}.md` 文件，包含任务描述和相关契约片段：

**文件格式**：

```markdown
# Task {number}: {title}

## 关联
- Part of feature: {feature_name}
- Phase: {phase}

## 任务描述

{任务描述和背景}

## 验收标准

- [ ] {标准1}
- [ ] {标准2}
- [ ] ✅ 接口路径与 API 契约一致
- [ ] ✅ 请求/响应字段与契约一致
- [ ] ✅ 状态枚举值与对照表一致

## 📋 API 契约片段（来自 Design Doc）

> ⚠️ 以下契约已在 Design Doc 中锁定，实现时必须严格遵守。

### 关联接口

#### 接口 1: {接口名}
\`\`\`
{METHOD} /api/v1/{path}

Request:
{JSON 示例}

Response:
{JSON 示例}
\`\`\`

#### 接口 2: {接口名}
\`\`\`
...
\`\`\`

### 关联状态枚举

| 枚举值 | 后端常量 | API 传输值 | 前端常量 | 显示文本 |
|--------|---------|-----------|---------|---------|
| {值} | {CONSTANT} | "{value}" | '{value}' | "{显示}" |

### 关联字段映射

| # | DB 字段 | DTO 字段 | API JSON | 前端字段 | 类型 | 必填 |
|---|---------|---------|----------|---------|------|------|
| 1 | {db} | {dto} | {api} | {ts} | {type} | ✅/❌ |

## 代码参考

{复用/冲突信息，如有}

## 相关文档

- Design Doc: {path 或 Issue 编号}
- PRD: {path 或 Issue 编号}
```

保存到 `.claude/cx/features/{dev_id}-{feature}/tasks/task-{n}.md`。

### Step 5: 生成全局任务状态文件

创建 `status.json` 记录所有任务的元数据和执行顺序：

```json
{
  "feature": "{feature_name}",
  "slug": "{feature_slug}",
  "created_at": "2024-01-15T10:00:00Z",
  "status": "planning",
  "phases": [
    {
      "number": 1,
      "name": "数据层",
      "parallel_group": "p1-a",
      "status": "pending",
      "tasks": [1, 2]
    },
    {
      "number": 2,
      "name": "后端服务",
      "parallel_group": "p2-a",
      "status": "blocked",
      "tasks": [3, 4],
      "depends_on": [1]
    }
  ],
  "tasks": [
    {
      "number": 1,
      "title": "数据库表设计",
      "phase": 1,
      "parallel": true,
      "depends_on": [],
      "parallel_group": "p1-a",
      "related_apis": [],
      "related_enums": [],
      "related_fields": [1, 2],
      "status": "pending"
    }
  ],
  "execution_order": [1, 2, 3, 4, 5],
  "docs": {
    "prd": "prd.md",
    "design": "design.md",
    "adr": "adr.md"
  }
}
```

### Step 6: 并行性判定

基于以下规则判断任务是否可以并行：

| 可并行 | 不可并行 |
|--------|---------|
| 不同目录的独立模块 | 修改同一文件 |
| 后端 model + DB migration | 同一组件的不同部分 |
| 独立的 API 端点 | 共享状态/配置修改 |
| 独立的前端页面 | 路由/导航修改 |
| 单元测试文件 | 全局样式/主题修改 |

### Step 7: GitHub 同步（可选）

根据 `config.github_sync`：
- **off/local**：仅保存本地任务文件和 status.json
- **collab/full**：创建 GitHub Epic Issue（标签 `epic`），关联所有子任务 Issues（标签 `task:{feature}`）

### Step 8: 输出摘要

```
任务规划完成

功能: {feature_name}
规模: {S/M/L}
总任务数: {N}

Phase 1: {phase_name}
├── Task 1: {title} (parallel)
└── Task 2: {title} (parallel)

Phase 2: {phase_name}
├── Task 3: {title} (depends_on: Task 1,2)
└── Task 4: {title} (depends_on: Task 1,2)

执行顺序: 1 → {2,3,4} → 5 → ...
（括号内的任务可并行执行）

本地任务文件位置: .claude/cx/features/{dev_id}-{feature}/tasks/
任务状态: .claude/cx/features/{dev_id}-{feature}/status.json

下一步: /cx-exec
```

### Step 9: 下一步引导

```json
{
  "questions": [
    {
      "question": "是否立即执行任务？",
      "header": "下一步",
      "multiSelect": false,
      "options": [
        {"label": "立即执行", "description": "运行 /cx-exec 开始第一个任务"},
        {"label": "批量执行", "description": "运行 /cx-exec --all 并行执行"},
        {"label": "稍后处理", "description": "先 review status.json 和各任务文件"}
      ]
    }
  ]
}
```

## 本地文件结构

```
.claude/cx/features/{dev_id}-{feature}/
├── status.json                ← 全局任务状态和执行顺序
├── tasks/
│   ├── task-1.md              ← Task 1 + 契约片段
│   ├── task-2.md              ← Task 2 + 契约片段
│   └── task-N.md              ← Task N + 契约片段
├── prd.md
├── design.md
└── adr.md
```

## 契约下沉的优势

- **cx-exec 无需翻阅设计文档**：所有契约片段已嵌入任务文件
- **并行 exec 更安全**：各子代理有独立的契约参考，避免理解偏差
- **契约校验更精确**：对比实现 vs 任务 Issue 中的契约片段，错误更容易定位

## 与 cx-design 的衔接

- **输入**：design.md（含三大契约）
- **输出**：task-{n}.md files（契约下沉）+ status.json（执行顺序）
- 如果 S 规模跳过 design，直接从 prd.md 读取需求并生成简化任务

## 与 cx-exec 的衔接

- cx-exec 读取 status.json 确定执行顺序
- cx-exec 根据 parallel_group 判断哪些任务可并行
- cx-exec 读取 task-{n}.md 作为实现参考
- cx-exec 更新 status.json 中的任务进度
