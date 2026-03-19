---
name: prd
description: >
  CX 工作流 — 需求收集与规模评估。当用户提到"新功能"、"需求"、"PRD"、
  "我想做一个"、"帮我规划"、"收集需求"、"功能规划"时触发。
  多轮对话收集需求，自动评估规模，保存到本地
  .claude/cx/功能/{feature_title}/需求.md，并自动判断是否需要 Design。
disable-model-invocation: true
---

# cx-prd: 需求收集与规模评估

把模糊想法收敛成可执行需求，并决定后续是否进入设计阶段。

## 使用方法

```text
/cx:prd {功能名}
/cx:prd
```

## 运行边界

- 项目级 `.claude/cx/配置.json` 与 `.claude/cx/状态.json` 是唯一运行时真相
- 可见目录与文档名使用中文，内部状态引用始终使用稳定 `slug`
- `cx-prd` 负责需求收敛，不负责把流程做重

## 核心步骤

### Step 0: 建立功能目录与 slug

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
CX_DIR="$PROJECT_ROOT/.claude/cx"
CONFIG_FILE="$CX_DIR/配置.json"
PROJECT_STATUS="$CX_DIR/状态.json"

FEATURE_TITLE="{功能标题}"
FEATURE_SLUG="{feature-slug}"
FEATURE_DIR="$CX_DIR/功能/$FEATURE_TITLE"

mkdir -p "$FEATURE_DIR/任务"
```

同时在项目级 `状态.json` 中登记：

```json
{
  "current_feature": "feature-slug",
  "features": {
    "feature-slug": {
      "title": "功能标题",
      "path": "功能/功能标题",
      "status": "drafting"
    }
  }
}
```

### Step 1: 读取现有上下文

- 扫描项目技术栈和已有模块
- 查找与本功能最接近的页面、接口、数据结构
- 如果项目里已经有相关 `需求.md / 设计.md / 修复记录.md`，只提炼与本次需求相关的部分

### Step 2: 多轮问答收敛需求

优先使用 Claude Code 的勾选式问答收集这些信息：

- 核心用户场景
- 影响层级：前端、后端、数据层、基础设施
- 是否涉及新增接口、数据库结构、状态模型
- 验收标准与明确的 out-of-scope

每轮都先复述理解，再继续追问缺口；普通细节不做开放式盘问。

### Step 3: 生成项目级需求文档

写入：

```text
.claude/cx/功能/{功能标题}/需求.md
```

文档里至少包含：

- 功能标题
- 稳定 slug
- 背景与目标
- 用户场景
- 功能需求
- 验收标准
- 风险与未决问题

### Step 4: 自动评估规模

根据这些维度给出 `S / M / L` 建议：

- 影响文件和模块数量
- 是否跨前后端
- 是否新增或改动 API
- 是否涉及数据库或状态机
- 是否引入新技术或重大架构决策

### Step 5: 自动判断是否需要 Design

`cx-prd` 必须自动判断是否需要 Design，然后用勾选式问答让用户确认，而不是静默决定。

- `S`：通常直接进入 `/cx:plan`
- `M`：进入 `/cx:design`
- `L`：进入 `/cx:design`，并在重大架构决策时补 `/cx:adr`

如果用户选择“仍要完整流程”，可以让小功能也走设计，但默认不强迫。

### Step 6: 路由到下一步

- 小功能：`PRD → Plan`
- 中大功能：`PRD → Design → Plan`

只有在需求确实成熟后，才把 feature 状态从 `drafting` 推进到 `planned` 前的下一阶段。

## 输出物

- 文档：`.claude/cx/功能/{功能标题}/需求.md`
- 状态：项目级 `状态.json` 更新 `current_feature`、`features[slug]`
- 后续路由：自动建议 `/cx:plan` 或 `/cx:design`
