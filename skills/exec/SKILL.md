---
name: exec
description: >
  CX 工作流 — 任务执行与自动推进。当用户提到"执行任务"、"开始开发"、
  "实现功能"、"写代码"、"继续做"、"下一个任务"时触发。
  默认读取项目级状态并自动推进可执行任务，完成后再进入 summary 闭环。
disable-model-invocation: true
---

# cx-exec: 自动执行与任务推进

默认像一个稳健主程一样持续推进；带 `--all` 时，再升级成高自治 agent teams。

先阅读：

- `core/workflow/README.md`
- `core/workflow/protocols/exec.md`

## 使用方法

```text
/cx:exec
/cx:exec --all
/cx:exec 任务-3
```

## 运行原则

- 项目级 `.claude/cx/配置.json` 和 feature 级 `状态.json` 是执行真相
- `/cx:exec` 默认自动推进，直到完成、阻塞或关键决策点
- `/cx:exec --all` 才进入高自治团队模式
- GitHub 不参与执行态主控，闭环同步交给 `/cx:summary`
- Claude Code 在共享 core 中始终注册为 runner `cc`；如果 feature 当前由 `codex` 持有，必须先 handoff，不能静默抢占

## 核心步骤

### Step 0: 读取当前功能和任务图

- 从 `.claude/cx/配置.json` 读取 `current_feature`
- 从项目级 `.claude/cx/状态.json` 找到对应中文目录
- 从 `.claude/cx/功能/{功能标题}/状态.json` 读取 `tasks / phases / execution_order`

### Step 0.5: 校验 worktree 绑定

在 claim 之前先做 worktree 校验，确保 runner 当前 checkout 与 feature 绑定一致：

```bash
bash scripts/cx-core-worktree.sh \
  --feature {feature-slug} \
  --runner {runner} \
  --session-id {session-id} \
  --branch {branch} \
  --worktree-path {preferred-worktree-path}
```

- 如果脚本返回推荐 worktree，说明还在规划阶段，先落盘推荐再继续
- 如果脚本拒绝当前 checkout，先走 handoff 或切换到正确 worktree，不能直接 claim
- 同一 feature 只能在一个 worktree 中持有活跃执行权，除非已经发生 handoff
- claim helper 注册当前 session 时，runner 固定使用 `cc`

### Step 1: 选择可执行任务

默认选择所有“依赖已满足”的任务，而不是只跑一个就停。

如果没有显式参数：

- 找出第一个可执行任务或当前 wave
- 自动把能连续完成的任务一路推进
- 只有遇到关键决策点才暂停问用户

### Step 2: 实现、验证、更新状态

每个任务都走同一闭环：

1. 读取 `任务/任务-{n}.md`
2. 实现代码
3. 校验契约
4. 运行最相关验证
5. 更新 `状态.json`
6. 提交代码

如果执行失败，优先自救；确实无法继续时，把任务或 feature 标成 `blocked`。

### Step 3: 结构化阻塞

所有阻塞都要落到状态里，不能只靠自然语言描述。

```json
{
  "status": "blocked",
  "blocked": {
    "reason_type": "needs_decision",
    "message": "需要确认接口返回结构"
  }
}
```

任务级也允许记录 `reason_type`，便于 `/cx:status` 和 hook 恢复。

### Step 4: 默认执行模式

普通 `/cx:exec` 的含义是：

- 自动连续推进可执行任务
- 自己处理普通测试失败和局部冲突
- 不在 wave 边界做建议性停顿
- 仅在下面 4 类关键决策点暂停：
  - 多条行为路径且结果差异明显
  - 会改架构、API 契约、数据库结构、状态模型
  - 高风险或不可逆操作
  - 需要用户提供外部信息

### Step 5: `/cx:exec --all`

`/cx:exec --all` 的含义不是简单“全跑完”，而是：

- 进入高自治 agent teams 模式
- 按任务图自适应拆 wave
- 尽可能拉起 `3+ 专业代理`
- 主代理只负责调度、整合、契约校验和关键决策暂停

团队角色不写死，只按任务图临时组队，例如：

- backend-agent
- frontend-agent
- database-agent
- integration-agent
- review-agent

## 提交规范

默认每个 task 独立提交，并在 commit message 末尾追加标记：

```text
[cx:<feature-slug>] [task:<n>]
```

完整示例：

```text
feat(memory): add vector query service [cx:vector-memory] [task:4]
fix(liuyao): guard divine fallback path [cx:liuyao-divine] [task:2]
```

如果是 fix 路径，则使用：

```text
fix(scope): description [cx-fix:<fix-slug>]
```

## 完成条件

当所有任务都完成后：

- feature 状态切到 `completed`
- 如果 `code_review=true`，先建议做闭环审查
- 最后再进入 `/cx:summary`
