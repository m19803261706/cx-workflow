---
name: cx-status
description: "Codex 侧 CX 状态查看。展示共享 core 中的 feature、owner、worktree、lease 与 handoff 状态。"
---

# CX Status (Codex Adapter)

优先读取：

- `.claude/cx/core/projects/*.json`
- `.claude/cx/core/features/*.json`
- `.claude/cx/core/worktrees/*.json`
- `.claude/cx/core/handoffs/**/*.json`

## 输出重点

- 当前 `current_feature`
- 当前 owner 是 `cc` 还是 `codex`
- 当前 lease session
- preferred / bound worktree
- 是否存在待处理 handoff
- 当前任务完成度与阻塞原因

## 规则

- 如果 feature 当前由 `cc` 持有，要明确告诉用户，不要假装 Codex 可以直接继续
- 如果存在 `reason_type`，要把阻塞原因结构化展示出来
