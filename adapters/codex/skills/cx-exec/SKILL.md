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

1. 读取 `.claude/cx/core/projects/*.json` 与目标 feature 文件
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
- Codex 运行时快照只写 `.claude/cx/runtime/codex/`
- 如果用户明确要求 `--all`，可以进入高自治并行模式，但仍不能绕过 lease / worktree 规则
- 不能在“完成一个 task”之后自然停下；必须重新 dispatch，除非已经 blocked、completed 或遇到关键决策点

## 收尾

- 单任务完成：更新 task 状态
- 全部任务完成：进入 `cx-summary`
- 遇到关键决策：暂停并请求用户确认
