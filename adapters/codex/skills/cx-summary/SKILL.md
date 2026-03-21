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

- 生成 `开发文档/CX工作流/功能/<标题>/总结.md`
- 把 feature 状态推进到 completed / archived / summarized

## 规则

- 只有在 Codex 合法持有该 feature lease，或已经完成 handoff 后，才能推进执行闭环状态
- 如果 feature 当前属于 `cc`，Codex 只能给出建议，不要直接改共享完成态
- `GitHub` 仍然只是同步镜像，`开发文档/CX工作流` 与 `.cx/core` 才是真相

## 分支整合（Worktree 模式）

如果当前在 feature worktree 中（非 inline 模式），summary 完成后提供整合选项。

Codex 没有 `AskUserQuestion` 工具，**必须（MUST）用编号文字列表 + 等待用户回复**：

```
所有任务已完成，如何处理这个 feature 分支？

1. Merge 回主分支（合并后清理 worktree）
2. Push + 创建 Pull Request
3. 保留分支（稍后处理）
4. 丢弃（需确认）

请回复编号：
```

**选项 1 — Merge：**
```bash
git checkout main && git pull && git merge {feature-branch}
# 验证测试通过后
bash ../cx-shared/scripts/cx-worktree.sh cleanup --feature {slug}
git branch -d {feature-branch}
```

**选项 2 — PR：**
```bash
git push -u origin {feature-branch}
gh pr create --title "{feature-title}" --body "..."
```

**选项 3 — 保留：**
不执行任何操作。

**选项 4 — 丢弃：**
用编号文字列表二次确认后：
```bash
bash ../cx-shared/scripts/cx-worktree.sh cleanup --feature {slug} --force
git branch -D {feature-branch}
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
