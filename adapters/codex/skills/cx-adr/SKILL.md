---
name: cx-adr
description: "Codex 侧 CX 架构决策记录。沉淀设计取舍，不改变 lease 与 worktree 持有关系。"
---

# CX ADR (Codex Adapter)

先阅读：

- `../cx-shared/references/codex-skill-contract.md`

## 目标

- 在 feature 目录中写 `adr.md` 或 `架构决策.md`
- 记录架构决策、备选方案和影响范围

## 规则

- ADR 是文档补充，不代表接管 feature
- 如果当前 feature 的执行 owner 是 `cc`，Codex 仍然只能补文档，不能借机改 lease
- 保持 `.cx/core/features/<slug>.json` 中 docs 元信息与文档路径一致
