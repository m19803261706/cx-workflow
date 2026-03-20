---
name: cx-design
description: "Codex 侧 CX 技术设计。基于 PRD 生成设计文档与契约，并与共享 cx core 保持一致。"
---

# CX Design (Codex Adapter)

先阅读：

- `../cx-shared/core/workflow/README.md`
- `../cx-shared/core/workflow/protocols/design.md`
- `../cx-shared/references/codex-skill-contract.md`
- `../cx-shared/references/templates/design.md`

## Worktree 检测（强制）

<HARD-GATE>
禁止在主分支（main/master）上执行设计阶段。必须在 feature worktree 中。
</HARD-GATE>

执行前检测：

```bash
check_output=$(bash ../cx-shared/scripts/cx-worktree.sh check \
  --project-root "$(git rev-parse --show-toplevel)" 2>&1) || true
```

如果返回 `on_main=true`：

```
当前在主分支上，无法执行设计阶段。请先创建 feature worktree：

1. 运行 /cx:cx-prd 创建新功能的 worktree
2. 手动进入已有 worktree

请回复编号：
```

**不要继续执行设计阶段。**

## 目标

- 生成 `.claude/cx/功能/<标题>/设计.md`
- 明确 API、状态枚举、字段映射、测试重点
- 保持共享 `cx core` 的 docs 元信息与 feature 标题一致

## 规则

- 设计阶段不抢 lease
- 如果 feature 已由 `cc` 执行中，允许补设计文档，但不要改执行 owner
- 设计文档只沉淀决策与契约，不改动 runtime lease

优先调用：

```bash
bash ../cx-shared/scripts/cx-workflow-design.sh \
  --feature <feature-slug> \
  --runner codex \
  --session-id <session-id>
```
