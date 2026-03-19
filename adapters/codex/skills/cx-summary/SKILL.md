---
name: cx-summary
description: "Codex 侧 CX 汇总闭环。汇总 feature 结果、更新共享状态，并保持 docs 元信息一致。"
---

# CX Summary (Codex Adapter)

先阅读：

- `../cx-shared/core/workflow/README.md`
- `../cx-shared/core/workflow/protocols/summary.md`
- `../cx-shared/references/codex-skill-contract.md`
- `../cx-shared/references/templates/summary.md`

## 目标

- 生成 `.claude/cx/功能/<标题>/总结.md`
- 把 feature 状态推进到 completed / archived / summarized

## 规则

- 只有在 Codex 合法持有该 feature lease，或已经完成 handoff 后，才能推进执行闭环状态
- 如果 feature 当前属于 `cc`，Codex 只能给出建议，不要直接改共享完成态
- `GitHub` 仍然只是同步镜像，`.claude/cx` 与 `.claude/cx/core` 才是真相

优先调用：

```bash
bash ../cx-shared/scripts/cx-workflow-summary.sh \
  --feature <feature-slug> \
  --runner codex \
  --session-id <session-id>
```
