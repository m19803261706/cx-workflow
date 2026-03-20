---
name: cx-status
description: >
  CX 工作流 — 进度查看。读取项目级配置和状态文件，展示当前功能、
  当前任务、阻塞原因和最近修复记录。
---

# cx-status: 查看当前进度

快速回答“现在做到哪了、卡在哪、下一步是什么”。

先阅读：

- `${CLAUDE_PLUGIN_ROOT}/core/workflow/README.md`
- `${CLAUDE_PLUGIN_ROOT}/core/workflow/protocols/status.md`

## 读取来源

优先调用共享 runner：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-workflow-status.sh \
  --runner cc
```

- `.claude/cx/配置.json`
- `.claude/cx/状态.json`
- `.claude/cx/功能/{功能标题}/状态.json`
- `.claude/cx/修复/*/修复记录.md`（如需要）

## 展示重点

### 1. 当前功能

- 中文标题
- 稳定 `slug`
- 当前状态：`drafting / planned / executing / blocked / completed / summarized`
- 完成进度：`completed / total`

### 2. 当前任务

优先展示 `in_progress` 的任务；如果没有，就展示下一条可执行任务。

### 3. 阻塞信息

当 feature 或 task 进入 `blocked` 时，必须展示结构化原因：

- `reason_type`
- `message`

例如：

```json
{
  "reason_type": "verification_failed",
  "message": "测试仍未通过，需要继续修复"
}
```

### 4. 下一步建议

- 正在执行：建议 `/cx:cx-exec`
- 已完成待收尾：建议 `/cx:cx-summary`
- 无活跃功能：建议 `/cx:cx-prd` 或 `/cx:cx-fix`

## 说明原则

- 状态优先来自 JSON，而不是模型记忆
- GitHub 信息只作为补充，不覆盖本地状态
- 输出要短、结构化、可行动
- 如果共享 core 显示 feature 由 `codex` 持有，必须明确展示 owner 和 handoff 建议
