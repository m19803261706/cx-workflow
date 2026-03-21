---
name: cx-adr
description: >
  CX 工作流 — 架构决策记录。当用户提到"架构决策"、"技术选型"、
  "ADR"、"为什么选择 X"、"架构方案对比"时可能触发（通常由 cx-design 自动调用）。
  仅在 L 规模或重大架构取舍出现时记录，保存到本地
  开发文档/CX工作流/功能/{feature_title}/架构决策.md。
---

# cx-adr: 架构决策记录

为少数高影响设计决策留一份短而清楚的取舍记录。

## 使用方法

```text
/cx:cx-adr {决策标题}
/cx:cx-adr
```

## 触发边界

以下情况才建议写 ADR：

- L 规模 feature
- 新技术或新基础设施引入
- 存储、通信、缓存、同步方案存在明显 trade-off
- 回退成本高、影响面大的架构决定

普通实现细节不要滥用 ADR。
Claude Code 侧写 ADR 时仍然只是在共享 core 上补充文档，不改变其他 runner 的 lease。
允许在用户明确确认需要 ADR 后，由工作流自动衔接到本 skill。

## 核心步骤

### Step 0: 定位文档目录

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
CX_DIR="$PROJECT_ROOT/开发文档/CX工作流"
FEATURE_TITLE="{功能标题}"
FEATURE_DIR="$CX_DIR/功能/$FEATURE_TITLE"
ADR_FILE="$FEATURE_DIR/架构决策.md"
```

### Step 1: 收集决策上下文

- 要解决什么问题
- 候选方案有哪些
- 每个方案的收益、成本、风险和回退难度

### Step 2: 关联 PRD / Design

默认关联同目录下已有文档：

- `需求.md`
- `设计.md`

### Step 3: 生成短决策记录

ADR 只保留这些核心内容：

- 背景
- 候选方案
- 选择结果
- 影响范围
- 回退策略

### Step 4: 更新 feature 文档关联

在 feature 的 `状态.json` 中补上：

```json
{
  "docs": {
    "prd": "需求.md",
    "design": "设计.md",
    "adr": "架构决策.md"
  }
}
```

如果没有明确架构决策，不要为了流程完整而硬写一份 ADR。
