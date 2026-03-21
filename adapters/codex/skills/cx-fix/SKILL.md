---
name: cx-fix
description: "Codex 侧 CX 缺陷修复。调查、定位、修复、测试，并在需要时遵守共享 lease 与 handoff 规则。"
---

# CX Fix (Codex Adapter)

先阅读：

- `../cx-shared/core/workflow/README.md`
- `../cx-shared/core/workflow/protocols/fix.md`
- `../cx-shared/references/codex-skill-contract.md`
- `../cx-shared/references/templates/fix.md`

## Worktree 检测

cx-fix 对 worktree 的要求比其他 skill 宽松：

- **小修复（bug fix、hotfix）**：允许在当前分支直接修复（`--inline` 模式）
- **大修复（涉及多文件重构）**：建议创建 worktree 隔离

执行前检测：

```bash
check_output=$(bash ../cx-shared/scripts/cx-worktree.sh check \
  --inline \
  --project-root "$(git rev-parse --show-toplevel)" 2>&1) || true
```

默认 inline 模式，不强制 worktree。

## 目标

- 生成 `开发文档/CX工作流/修复/<问题标题>/修复记录.md`
- 修完后更新相关 feature 或 fix 状态

## 规则

- 如果问题明确归属某个活跃 feature，先检查 owner
- 如果该 feature 由 `cc` 持有，先建议 handoff，再决定是否继续
- 如果是独立 fix，可以单独记录，不必强行占用无关 feature 的 lease
- 修复后的运行时临时说明写入 `.cx/runtime/codex/`

优先调用：

```bash
bash ../cx-shared/scripts/cx-workflow-fix.sh \
  --title "<问题标题>" \
  --runner codex \
  --session-id <session-id>
```
