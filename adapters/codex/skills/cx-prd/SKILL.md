---
name: cx-prd
description: "Codex 侧 CX 需求收集。创建需求文档、评估规模，并同步共享 cx core 的 feature 注册信息。"
---

# CX PRD (Codex Adapter)

先阅读：

- `../cx-shared/references/codex-skill-contract.md`
- `../cx-shared/references/templates/prd.md`
- `../cx-shared/references/core-schema-overview.md`

## 目标

- 在 `.claude/cx/功能/<中文标题>/需求.md` 写出 PRD
- 为 feature 生成稳定 slug
- 在共享 `cx core` 中注册或更新该 feature

## 执行规则

- PRD 阶段不需要 claim lease
- 但如果发现同名 feature 已由 `cc` 持有并正在执行，先提醒用户复用或 handoff，不要直接覆盖
- `current_feature` 可以指向新 slug，但必须保证项目注册表与 feature 文件同步

## 输出

- `需求.md`
- `功能/<标题>/状态.json`
- `.claude/cx/core/features/<slug>.json`
- `.claude/cx/core/projects/project.json` 中的 feature 索引

## 路由

- S 规模：进入 `cx-plan`
- M/L 规模：进入 `cx-design`
