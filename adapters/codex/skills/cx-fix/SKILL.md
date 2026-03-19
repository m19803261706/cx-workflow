---
name: cx-fix
description: "Codex 侧 CX 缺陷修复。调查、定位、修复、测试，并在需要时遵守共享 lease 与 handoff 规则。"
---

# CX Fix (Codex Adapter)

先阅读：

- `../cx-shared/references/codex-skill-contract.md`
- `../cx-shared/references/templates/fix.md`

## 目标

- 生成 `.claude/cx/修复/<问题标题>/修复记录.md`
- 修完后更新相关 feature 或 fix 状态

## 规则

- 如果问题明确归属某个活跃 feature，先检查 owner
- 如果该 feature 由 `cc` 持有，先建议 handoff，再决定是否继续
- 如果是独立 fix，可以单独记录，不必强行占用无关 feature 的 lease
- 修复后的运行时临时说明写入 `.claude/cx/runtime/codex/`
