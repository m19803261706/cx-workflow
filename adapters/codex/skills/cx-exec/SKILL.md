---
name: cx-exec
description: "Codex 侧 CX 任务执行。先做 worktree 检查，再 claim lease，然后实现、测试并更新共享状态。"
---

# CX Exec (Codex Adapter)

先阅读：

- `../cx-shared/core/workflow/README.md`
- `../cx-shared/core/workflow/protocols/exec.md`
- `../cx-shared/references/codex-skill-contract.md`
- `../cx-shared/references/core-schema-overview.md`

然后严格遵守这个顺序：

0. **Worktree 检测（强制）**

执行前先调用 worktree 检测：

```bash
check_output=$(bash ../cx-shared/scripts/cx-worktree.sh check \
  --feature "{feature-slug}" \
  --project-root "$(git rev-parse --show-toplevel)" 2>&1) || true
```

<HARD-GATE>
如果返回 `on_main=true`，禁止在主分支上执行。必须先进入 feature worktree。
</HARD-GATE>

如果在主分支上，**必须（MUST）用编号文字列表 + 等待用户回复**：

```
当前在主分支上，无法直接执行任务。请选择：

1. 运行 /cx:cx-prd 创建新功能的 worktree
2. 手动进入已有 worktree

请回复编号：
```

如果 `in_worktree=false` 且不在 main 上（可能在非 feature 分支），列出可用 worktree 供选择：

```
当前不在 feature worktree 中，可用的 worktree：

1. {worktree-1-path} — {branch-1}
2. {worktree-2-path} — {branch-2}
3. 在当前分支直接开始（不推荐）

请回复编号：
```

已绑定 worktree 时不再重复询问。

1. 读取 `.cx/core/projects/*.json` 与目标 feature 文件
2. 确认当前 feature、owner、claimed tasks
3. 先跑 shared dispatch helper，判断是继续、提问并行、阻塞还是收尾：

```bash
bash ../cx-shared/scripts/cx-workflow-exec-dispatch.sh \
  --feature <slug> \
  --runner codex \
  --session-id <session-id> \
  --mode <auto|all>
```

4. 如果 dispatch 返回 `ask_parallel`，可以问用户一次是否切到 `--all`；如果用户没有明确切换，默认继续串行
5. 在真正执行某个 task 前再跑：

```bash
bash ../cx-shared/scripts/cx-core-worktree.sh --feature <slug> --runner codex --session-id <session-id> --branch <branch> --worktree-path <worktree-path>
```

6. worktree 通过后再跑：

```bash
bash ../cx-shared/scripts/cx-core-claim.sh --runner codex --session-id <session-id> --branch <branch> --worktree-path <worktree-path> --feature <slug> --tasks <task-ids>
```

7. 只有 claim 成功后，才能改 feature / task 状态
8. 完成后运行相关测试，并把状态写回共享 core 与中文状态文档
9. 单个 task 完成后重新跑 dispatch helper，直到 `blocked` / `completed` / 关键决策点才停

## 关键规则

- 如果 `cc` 已持有该 feature，先提示 handoff，不要静默抢占
- 同一 feature 未经 handoff 不能跨 worktree 并行执行
- Codex 运行时快照只写 `.cx/runtime/codex/`
- 如果用户明确要求 `--all`，可以进入高自治并行模式，但仍不能绕过 lease / worktree 规则
- 不能在“完成一个 task”之后自然停下；必须重新 dispatch，除非已经 blocked、completed 或遇到关键决策点

## 收尾

- 单任务完成：更新 task 状态
- 全部任务完成：进入 `cx-summary`
- 遇到关键决策：暂停并请求用户确认
