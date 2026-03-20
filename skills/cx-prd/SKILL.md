---
name: cx-prd
description: >
  CX 工作流 — 需求收集与规模评估。当用户提到"新功能"、"需求"、"PRD"、
  "我想做一个"、"帮我规划"、"收集需求"、"功能规划"时触发。
  多轮对话收集需求，自动评估规模，保存到本地
  .claude/cx/功能/{feature_title}/需求.md，并自动判断是否需要 Design。
disable-model-invocation: true
---

# cx-prd: 需求收集与规模评估

把模糊想法收敛成可执行需求，并决定后续是否进入设计阶段。

先阅读：

- `core/workflow/README.md`
- `core/workflow/protocols/prd.md`
- `references/templates/prd.md`

## 使用方法

```text
/cx:cx-prd {功能名}
/cx:cx-prd
```

## 强制规则

**禁止跳过问答直接生成文档。** 无论用户的需求描述多清晰、多完整，都必须（MUST）：

1. 先分析代码和上下文
2. 主动提出方案选项（AskUserQuestion）
3. 至少完成 2 轮结构化问答并得到用户明确确认
4. 确认完成后才能生成 `需求.md`

违反这条规则的行为：
- ❌ 用户说完需求 → 直接写 `需求.md`
- ❌ 只做一轮问答就落盘
- ❌ 把问答内容和文档生成混在同一步

正确的行为：
- ✅ 用户说完需求 → 分析代码 → Round 1 方案选择 → Round 2 细化确认 → 用户确认"可以了" → 生成文档

## 运行边界

- 项目级 `.claude/cx/配置.json` 是运行时配置真相
- Feature 状态在各自 worktree 的 `.claude/cx/功能/{title}/状态.json` 中
- 全局 `current_feature` 指针已废弃，worktree CWD 即上下文
- 可见目录与文档名使用中文，内部状态引用始终使用稳定 `slug`
- `cx-prd` 负责需求收敛，不负责把流程做重
- Claude Code 侧以 runner `cc` 身份写共享状态；如果 feature 已由 `codex` 持有，先提示 handoff
- 不要在长时间分析之后才落盘；最小 PRD scaffold 应该先由 shared runner 建好

## Worktree 隔离（强制）

<HARD-GATE>
除非用户显式传入 --inline，否则禁止在主分支（main/master）上创建 PRD。
必须先创建 feature worktree。
</HARD-GATE>

### Step -1: 创建或进入 Feature Worktree

在 Step 0（scaffold）之前执行：

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
check_output=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-worktree.sh check --project-root "$PROJECT_ROOT" 2>&1) || true
```

**如果 `on_main=true`（在主分支上）：**

使用 `AskUserQuestion` 询问：

```json
{
  "questions": [{
    "question": "当前在主分支上，需要为这个功能创建隔离工作区",
    "header": "工作区选择",
    "multiSelect": false,
    "options": [
      { "label": "创建 Feature Worktree（推荐）", "description": "自动创建隔离分支和工作目录" },
      { "label": "在当前分支直接开始（--inline）", "description": "不隔离，适合极小改动" }
    ]
  }]
}
```

用户选择创建 worktree 时：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-worktree.sh create \
  --feature "{feature-slug}" \
  --runner cc \
  --project-root "$PROJECT_ROOT"
```

然后 `cd` 到新 worktree 路径继续后续步骤。

用户选择 inline 时，继续在当前分支执行。

## 核心步骤

### Step 0: 先按 shared workflow core 建立 feature scaffold

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-workflow-prd.sh \
  --project-root "$PROJECT_ROOT" \
  --title "{功能标题}" \
  --slug "{feature-slug}" \
  --runner cc \
  --session-id "{session-id}" \
  --size "{S|M|L}" \
  --needs-design "{true|false}" \
  --question-mode checklist
```

这个 shared runner 负责确定性落盘：

- `.claude/cx/功能/{功能标题}/需求.md`
- `.claude/cx/功能/{功能标题}/状态.json`
- `.claude/cx/core/features/{feature-slug}.json`
- `.claude/cx/core/projects/project.json`

### Step 0.5: Dashboard 自动保活与项目注册

每次进入 PRD 时都执行，确保 dashboard 服务始终可用：

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-dashboard-ensure.sh
bridge_output=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-dashboard-bridge.sh \
  --project-root “$PROJECT_ROOT” \
  --display-name “$(basename “$PROJECT_ROOT”)”)
```

行为规则：

**`prompt_state=accepted`（已启用）：**
- 每次都检查服务健康状态，服务挂了自动重启（`cx-dashboard-ensure.sh`）
- 自动注册当前项目，无需再问
- 告知用户面板地址（如果服务正常运行）

**`prompt_state=pending`（从未被问过）：**
- 用 `AskUserQuestion` 询问是否启用全局面板
- 用户接受 → 执行 `--decision accept`，启动服务
- 用户跳过 → 执行 `--decision decline`，本次跳过
- 不阻塞 PRD 流程

**`prompt_state=declined`（曾经跳过）：**
- **不是永久性拒绝**。检查 `runtime.json` 中 `last_checked_at`：
  - 如果距上次检查 > 24 小时（说明可能重启了电脑）→ 重新询问一次
  - 如果 < 24 小时 → 静默跳过，不打扰

**服务重启后的行为：**
- `cx-dashboard-ensure.sh` 会检测 PID 是否存活
- 进程不在 → 自动清理旧 PID → 重新拉起 backend + frontend
- 自动扫描 `~/.cx/dashboard/registry.json` 中已注册的项目

### Step 1: 读取现有上下文

- 扫描项目技术栈和已有模块
- 查找与本功能最接近的页面、接口、数据结构
- 如果项目里已经有相关 `需求.md / 设计.md / 修复记录.md`，只提炼与本次需求相关的部分

### Step 2: 多轮结构化问答收敛需求

PRD 阶段的所有用户交互 **必须（MUST）** 使用 `AskUserQuestion` 工具。
禁止用纯文字列选项或开放式盘问代替。每轮先复述当前理解，再用结构化问题追问缺口。

#### Round 1: 场景与范围

先根据用户描述和代码分析，主动提出 2-3 个可行的实现方向，让用户选择或补充：

```json
{
  “questions”: [
    {
      “question”: “基于你的描述和项目现状，我分析了几个可行方向，哪个最接近你的预期？”,
      “header”: “实现方向”,
      “multiSelect”: false,
      “options”: [
        {
          “label”: “方案 A: {简要描述} (Recommended)”,
          “description”: “{优势、适用场景、预估工作量}”
        },
        {
          “label”: “方案 B: {简要描述}”,
          “description”: “{优势、适用场景、预估工作量}”
        },
        {
          “label”: “方案 C: {简要描述}”,
          “description”: “{优势、适用场景、预估工作量}”
        }
      ]
    },
    {
      “question”: “这个功能会影响哪些层级？”,
      “header”: “影响范围”,
      “multiSelect”: true,
      “options”: [
        { “label”: “前端 UI/交互”, “description”: “页面、组件、样式、路由” },
        { “label”: “后端 API/逻辑”, “description”: “接口、服务、中间件” },
        { “label”: “数据库/状态”, “description”: “表结构、状态机、缓存” },
        { “label”: “基础设施/部署”, “description”: “配置、CI/CD、环境变量” }
      ]
    }
  ]
}
```

方案推荐规则：
- **MUST** 根据项目代码现状主动分析并提出方案，不能只问”你想怎么做”
- 推荐方案放首位并标 `(Recommended)`，附带理由
- 每个方案说明优势、风险和预估工作量
- 用户可选 “Other” 自行补充

#### Round 2: 需求细化

根据 Round 1 的选择继续深入。可同时问 1-4 个问题：

```json
{
  “questions”: [
    {
      “question”: “需要支持哪些核心功能？”,
      “header”: “核心功能”,
      “multiSelect”: true,
      “options”: [
        { “label”: “{功能点 A}”, “description”: “{说明}” },
        { “label”: “{功能点 B}”, “description”: “{说明}” },
        { “label”: “{功能点 C}”, “description”: “{说明}” },
        { “label”: “{功能点 D}”, “description”: “{说明}” }
      ]
    },
    {
      “question”: “以下哪些属于本次范围外？”,
      “header”: “Out of Scope”,
      “multiSelect”: true,
      “options”: [
        { “label”: “{排除项 A}”, “description”: “{为什么建议排除}” },
        { “label”: “{排除项 B}”, “description”: “{为什么建议排除}” }
      ]
    }
  ]
}
```

#### Round 3: 验收与风险

```json
{
  “questions”: [
    {
      “question”: “以下验收标准是否完整？”,
      “header”: “验收标准”,
      “multiSelect”: true,
      “options”: [
        { “label”: “{标准 1}”, “description”: “{可测试的具体条件}” },
        { “label”: “{标准 2}”, “description”: “{可测试的具体条件}” },
        { “label”: “{标准 3}”, “description”: “{可测试的具体条件}” }
      ]
    },
    {
      “question”: “识别到以下潜在风险，需要特别关注哪些？”,
      “header”: “风险”,
      “multiSelect”: true,
      “options”: [
        { “label”: “{风险 A}”, “description”: “{影响和缓解方案}” },
        { “label”: “{风险 B}”, “description”: “{影响和缓解方案}” }
      ]
    }
  ]
}
```

#### 多轮节奏控制

- 每轮最多 4 个问题，每个问题最多 4 个选项
- 如果一轮能覆盖多个维度就合并，不需要每个维度单独一轮
- 通常 2-3 轮即可收敛，复杂功能不超过 4 轮
- 发现用户选了 “Other” 并补充了新信息时，下一轮要体现对该信息的理解

### Step 3: 生成项目级需求文档

在 shared runner 先完成最小落盘后，再把需求内容补充完整，而不是只停留在口头问答。

文档里至少包含：

- 功能标题
- 稳定 slug
- 背景与目标
- 选定方案（含对比分析）
- 用户场景
- 功能需求（来自 Round 2 多选结果）
- 验收标准（来自 Round 3 确认结果）
- 明确的 Out-of-Scope
- 风险与未决问题

### Step 4: 规模评估与路由确认

根据分析结果给出建议，**MUST** 使用 `AskUserQuestion` 让用户最终确认：

```json
{
  “questions”: [
    {
      “question”: “需求已收敛完成。根据分析建议规模为 {S/M/L}，接下来？”,
      “header”: “下一步”,
      “multiSelect”: false,
      “options”: [
        {
          “label”: “{推荐路由} (Recommended)”,
          “description”: “{推荐理由}”
        },
        {
          “label”: “走完整流程（PRD → Design → Plan）”,
          “description”: “即使是小功能也做完整设计，适合不确定性较高的场景”
        },
        {
          “label”: “直接进入规划（PRD → Plan）”,
          “description”: “跳过设计阶段，适合需求已经非常清晰的场景”
        }
      ]
    }
  ]
}
```

路由规则：
- `S`：默认推荐 `/cx:cx-plan`
- `M`：默认推荐 `/cx:cx-design`
- `L`：默认推荐 `/cx:cx-design`，并在重大架构决策时补 `/cx:cx-adr`

只有在需求确实成熟后，才把 feature 状态从 `drafting` 推进到下一阶段。

## 输出物

- 文档：`.claude/cx/功能/{功能标题}/需求.md`
- 状态：项目级 `状态.json` 更新 `current_feature`、`features[slug]`
- shared core：`.claude/cx/core/features/{slug}.json` 与 `project.json`
- 后续路由：自动建议 `/cx:cx-plan` 或 `/cx:cx-design`
