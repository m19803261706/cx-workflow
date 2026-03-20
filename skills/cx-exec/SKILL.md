---
name: cx-exec
description: >
  CX 工作流 — 任务执行与自动推进。当用户提到"执行任务"、"开始开发"、
  "实现功能"、"写代码"、"继续做"、"下一个任务"时触发。
  默认读取项目级状态并自动推进可执行任务，完成后再进入 summary 闭环。
---

# cx-exec: 自动执行与任务推进

默认像一个稳健主程一样持续推进；带 `--all` 时，再升级成高自治 agent teams。

## 强制规则

**禁止跳过工作区选择。** 执行前先调用 worktree 检测：

```bash
check_output=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-worktree.sh check \
  --feature "{feature-slug}" \
  --project-root "$(git rev-parse --show-toplevel)" 2>&1) || true
```

<HARD-GATE>
如果返回 `on_main=true`，禁止在主分支上执行。必须先进入 feature worktree。
</HARD-GATE>

如果 `in_worktree=false` 且不在 main 上（可能在非 feature 分支），用 `AskUserQuestion` 列出可用 worktree 供选择。

违反这条规则的行为：
- ❌ `--all` 模式直接在当前分支开干
- ❌ 跳过询问默认选择 inline
- ❌ 在拉起子代理之前没有完成工作区选择

正确的行为：
- ✅ 读取状态 → AskUserQuestion 询问工作区 → 用户回答 → 记录选择 → 然后才开始执行/拉代理

先阅读：

- `${CLAUDE_PLUGIN_ROOT}/core/workflow/README.md`
- `${CLAUDE_PLUGIN_ROOT}/core/workflow/protocols/exec.md`

## 使用方法

```text
/cx:cx-exec
/cx:cx-exec --all
/cx:cx-exec 任务-3
```

## 运行原则

- 项目级 `.claude/cx/配置.json` 和 feature 级 `状态.json` 是执行真相
- `/cx:cx-exec` 默认自动推进，直到完成、阻塞或关键决策点
- `/cx:cx-exec --all` 才进入高自治团队模式
- GitHub 不参与执行态主控，闭环同步交给 `/cx:cx-summary`
- Claude Code 在共享 core 中始终注册为 runner `cc`；如果 feature 当前由 `codex` 持有，必须先 handoff，不能静默抢占
- 允许在用户明确确认“进入执行阶段”或“继续执行”后，由工作流自动衔接到本 skill

## 核心步骤

### Step 0: 读取当前功能和任务图

- 从 `.claude/cx/配置.json` 读取 `current_feature` 和 `worktree_isolation`
- 从项目级 `.claude/cx/状态.json` 找到对应中文目录
- 从 `.claude/cx/功能/{功能标题}/状态.json` 读取 `tasks / phases / execution_order`

### Step 0.3: 工作区选择（每个 feature 首次执行时询问一次）

如果当前 feature 还没有绑定 worktree（`状态.json` 中 `worktree.binding_status` 不是 `bound`），
**必须（MUST）** 使用 `AskUserQuestion` 工具询问用户，**禁止用纯文字列选项**：

```json
{
  "questions": [
    {
      "question": "功能「{feature_title}」即将开始执行，选择工作区模式？",
      "header": "工作区",
      "multiSelect": false,
      "options": [
        {
          "label": "独立工作区 (Recommended)",
          "description": "在隔离 worktree 中开发，主分支不受影响，完成后合并回来"
        },
        {
          "label": "当前分支直接开始",
          "description": "在当前分支上直接开发，适合小改动或快速修复"
        }
      ]
    }
  ]
}
```

如果 `worktree_isolation=true`，"独立工作区" 放首位并标 `(Recommended)`。
如果 `worktree_isolation=false`，"当前分支直接开始" 放首位并标 `(Recommended)`。

**用户选择 1（创建独立工作区）：**

使用 Claude Code 内置的 `EnterWorktree` 工具创建隔离工作区：

```
EnterWorktree(name: "{feature-slug}")
```

这会：
- 在 `<repo>/.claude/worktrees/{feature-slug}/` 创建独立目录
- 自动创建 `worktree-{feature-slug}` 分支
- 将当前会话切换到新工作区

创建成功后，把 worktree 信息记录到 feature 的 `状态.json`：

```json
{
  "worktree": {
    "preferred_branch": "worktree-{feature-slug}",
    "preferred_worktree_path": ".claude/worktrees/{feature-slug}",
    "binding_status": "bound",
    "isolation_mode": "worktree"
  }
}
```

**用户选择 2（当前分支直接开始）：**

记录用户选择，后续不再询问：

```json
{
  "worktree": {
    "preferred_branch": "{当前分支名}",
    "preferred_worktree_path": "{当前目录}",
    "binding_status": "bound",
    "isolation_mode": "inline"
  }
}
```

**如果 feature 已经绑定了 worktree：**

- `isolation_mode = "worktree"` 且当前不在该 worktree 中：提示用户切换或使用 `EnterWorktree` 进入
- `isolation_mode = "inline"`：直接继续
- 不再重复询问

### Step 0.5: 校验 worktree 绑定

在 claim 之前做最终校验，确保 runner 当前 checkout 与 feature 绑定一致：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-core-worktree.sh \
  --feature {feature-slug} \
  --runner {runner} \
  --session-id {session-id} \
  --branch {branch} \
  --worktree-path {preferred-worktree-path}
```

- 如果脚本拒绝当前 checkout，先走 handoff 或切换到正确 worktree，不能直接 claim
- 同一 feature 只能在一个 worktree 中持有活跃执行权，除非已经发生 handoff
- claim helper 注册当前 session 时，runner 固定使用 `cc`

### Step 1: 通过 shared dispatch helper 选择可执行任务

先调用共享调度 helper，而不是自己凭感觉决定“做到哪停”：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-workflow-exec-dispatch.sh \
  --feature {feature-slug} \
  --runner cc \
  --session-id {session-id} \
  --mode {auto|all}
```

dispatch helper 会返回统一决策：

- `continue`：继续当前 `in_progress` 或下一个 `ready` task
- `ask_parallel`：检测到同一 `parallel_group` 下有 2+ ready task，允许问用户一次是否切到团队模式
- `parallel`：`--all` 下直接推进多任务
- `blocked`：进入阻塞说明或关键决策
- `completed`：全部完成，进入 `/cx:summary`

如果没有显式参数：

- 优先继续当前 `in_progress` 任务
- 没有 `in_progress` 时，由 dispatch helper 选择下一个 `ready` 任务
- 完成一个 task 后，重新运行 dispatch helper，直到 `blocked` / `completed` / 关键决策点
- 不允许在普通 task 边界自然停下

### Step 2: 实现、验证、更新状态

每个任务都走同一闭环：

1. 读取 `任务/任务-{n}.md`
2. **读取 `契约.md`，确认本任务引用的 API 路径、数据模型**
3. 实现代码
4. **契约一致性校验（MUST）**：
   - 后端任务：实际路由是否与契约中的路径一致
   - 前端任务：API 调用路径是否与契约中的路径一致
   - 数据模型：字段名、类型是否与契约一致
   - 如果不一致：**先更新契约文件，再继续**，不能静默忽略
5. 运行最相关验证
6. 更新 `状态.json`
7. 提交代码

如果执行失败，优先自救；确实无法继续时，把任务或 feature 标成 `blocked`。

### Step 2.5: 完成后立即重新调度

一个 task 完成并更新共享状态后：

1. 重新运行 `${CLAUDE_PLUGIN_ROOT}/scripts/cx-workflow-exec-dispatch.sh`
2. 如果返回 `continue`，直接接着做下一个 task
3. 如果返回 `ask_parallel`，可以问用户一次是否切到 `--all`
4. 如果返回 `parallel`，进入团队模式
5. 如果返回 `blocked` 或 `completed`，再停

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

任务级也允许记录 `reason_type`，便于 `/cx:cx-status` 和 hook 恢复。

### Step 4: 默认执行模式

普通 `/cx:cx-exec` 的含义是：

- 自动连续推进可执行任务
- 自己处理普通测试失败和局部冲突
- 不在普通 task 边界或 wave 边界做建议性停顿
- 仅在下面 4 类关键决策点暂停：
  - 多条行为路径且结果差异明显
  - 会改架构、API 契约、数据库结构、状态模型
  - 高风险或不可逆操作
  - 需要用户提供外部信息
- 如果检测到明确的并行机会，可以问用户一次是否升级到 `--all`；若用户没有明确切换，默认继续串行推进

### Step 5: `/cx:cx-exec --all`

`/cx:cx-exec --all` 的含义不是简单“全跑完”，而是：

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
- 最后再进入 `/cx:cx-summary`
