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

## 分支合并（独立工作区时）

如果 feature 的 `状态.json` 中 `worktree.isolation_mode = "worktree"`，
Codex 没有 `AskUserQuestion` 工具，**必须（MUST）用编号文字列表 + 等待用户回复**：

```
功能「{feature_title}」已完成，如何合并回主分支？

1. 创建 Pull Request（推荐）— 推送分支并创建 PR
2. 直接合并到主分支 — 合并后清理分支
3. 暂不合并 — 保留分支，稍后手动处理

请回复 1、2 或 3：
```

如果 `isolation_mode = "inline"`，跳过此步。

## 生成总结

优先调用：

```bash
bash ../cx-shared/scripts/cx-workflow-summary.sh \
  --feature <feature-slug> \
  --runner codex \
  --session-id <session-id>
```
