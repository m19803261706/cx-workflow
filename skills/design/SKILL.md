---
name: design
description: >
  CX 工作流 — 技术设计与执行契约。当用户提到"技术设计"、"Design Doc"、
  "API 设计"、"接口设计"、"架构设计"、"系统设计"时触发。
  读取 PRD 生成设计文档，保存到本地 .claude/cx/功能/{feature_title}/设计.md。
  该步骤只服务中大 feature 的执行契约，不强加给所有小功能。
disable-model-invocation: true
---

# cx-design: 技术设计与执行契约

把中大 feature 的关键决策、接口契约和测试重点先锁住，再进入任务规划。

## 使用方法

```text
/cx:design {功能名}
/cx:design
```

## 设计原则

- 只服务中大 feature，S 规模默认跳过
- 设计文档是执行契约，不是长篇论文
- 优先锁定 API、状态枚举、字段映射、风险点和测试重点

## 核心步骤

### Step 0: 定位项目级真相

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
CX_DIR="$PROJECT_ROOT/.claude/cx"
FEATURE_TITLE="{功能标题}"
FEATURE_SLUG="{feature-slug}"
FEATURE_DIR="$CX_DIR/功能/$FEATURE_TITLE"
PRD_FILE="$FEATURE_DIR/需求.md"
DESIGN_FILE="$FEATURE_DIR/设计.md"
```

内部关联始终使用 `slug`，目录展示使用中文标题。

### Step 1: 读取需求与现有实现

- 读取 `需求.md`
- 扫描相邻模块、接口约定、DTO/VO、状态枚举
- 找出可以复用的代码和必须变更的边界

### Step 2: 生成执行契约

设计文档最少包含这些章节：

1. 架构边界与模块拆分
2. API 接口契约
3. 状态枚举对照表
4. VO/DTO 字段映射
5. 风险点与测试重点

### Step 3: 用勾选问答确认关键契约

对这些高风险内容给用户做确认：

- 接口路径与响应结构
- 数据库或状态模型变更
- 兼容性和迁移风险

普通实现细节不需要频繁打断。

### Step 4: 写入项目文档并更新状态

写入：

```text
.claude/cx/功能/{功能标题}/设计.md
```

同时把 feature 状态推进到可规划阶段，例如：

```json
{
  "slug": "feature-slug",
  "status": "planned",
  "docs": {
    "prd": "需求.md",
    "design": "设计.md"
  }
}
```

## 什么时候需要 ADR

只有在这些情况出现时，才建议进入 `/cx:adr`：

- 明显引入新技术
- 存储或通信方案存在实质性取舍
- 重大架构调整
- 可逆成本或回退成本很高
