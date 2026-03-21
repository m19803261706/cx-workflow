# Codex Adapter Guide

Codex 不是 `cx core` 的旁路工具，而是共享控制平面与共享工作流大脑上的第二个正式运行器。

目标很明确：

- 让 Codex 以 runner `codex` 身份接入共享 `cx core`
- 与 Claude Code 的 `cc` adapter 共用一套 feature / lease / handoff / worktree 规则
- 与 Claude Code 的 `cc` adapter 共用一套 PRD / Design / Plan / Exec / Fix / Status / Summary 规则
- 支持并行 feature、跨运行器 handoff，以及中途接手继续执行

## 安装方式

Codex adapter 现在以独立 skill 包形式放在仓库里：

- 源码目录：`adapters/codex/skills/`
- 安装说明：`adapters/codex/README.md`
- 安装脚本：`scripts/install-codex.sh`

推荐安装到最新文档约定的用户级 `.agents/skills`：

```bash
bash scripts/install-codex.sh
```

开发期如果希望直接跟随当前仓库更新：

```bash
bash scripts/install-codex.sh --mode symlink
```

如果需要兼容旧的本地约定，可以额外安装到 `.codex/skills`：

```bash
bash scripts/install-codex.sh --also-legacy
```

## Codex 的职责

Codex adapter 必须做到：

- 从项目内 `.cx/core/projects/*.json` 读取共享项目注册表
- 以 runner `codex` 注册当前 session
- 在执行前先检查 worktree 绑定
- 在写 feature / task 状态前先拿到 lease
- 当 feature 已由 `cc` 持有时，优先提示 handoff，而不是静默覆盖
- 把运行时临时产物写到 `.cx/runtime/codex/`
- 在 `cx-init` / `cx-prd` 这类高频入口复用共享 dashboard bridge，而不是单独实现一套面板检测逻辑

Codex adapter 安装后的 skill 包还必须做到：

- 所有 `cx-*` skills 都可以从同一个仓库产出
- 共享引用通过 `cx-shared/` 复用协议、模板和脚本
- 不复制第二套 `cx core`
- phase 行为优先引用 `cx-shared/core/workflow/protocols/*.md`

Codex adapter 不应该：

- 绕过 lease 直接写共享状态
- 偷抢 `cc` 已持有的 feature
- 把自己的临时快照写进 `runtime/cc/`
- 在同一 feature 上绕过 worktree 规则并发执行
- 绕过共享 dashboard bridge 直接自行维护用户级项目注册表

## 共享入口

Codex 侧不要求完全复刻 Claude Code 的 slash command 形态，但语义必须一致。

推荐的 skill/命令语义：

- `cx-init`
- `cx-prd`
- `cx-design`
- `cx-adr`
- `cx-plan`
- `cx-exec`
- `cx-fix`
- `cx-status`
- `cx-summary`

允许的偏差：

- Claude Code 使用 `/cx:*`
- Codex 可以使用 `$cx-*`、skill 名或自然语言触发

不允许的偏差：

- 同名命令做出不同 lease / handoff / worktree 语义

## Codex 执行顺序

### 1. 读取共享项目真相

优先读取：

- `.cx/core/projects/*.json`
- `.cx/core/features/*.json`
- `.cx/core/sessions/*.json`

如果项目还未迁移到 core 结构，先走迁移或初始化，不要在半新半旧状态里直接执行。

### 2. 注册 runner `codex`

Codex 启动一个 feature 前，先把当前 session 注册到共享控制平面：

- `runner = codex`
- `session_id`
- `branch`
- `worktree_path`

### 3. worktree 检查先于 claim

在真正 claim 之前，先调用：

```bash
bash scripts/cx-core-worktree.sh \
  --feature <feature-slug> \
  --runner codex \
  --session-id <session-id> \
  --branch <branch> \
  --worktree-path <worktree-path>
```

如果当前 checkout 与 feature 绑定不一致：

- 先切到正确 worktree
- 或先完成 handoff

不要跳过这一层直接 claim。

### 4. 拿 lease 再写状态

执行前调用：

```bash
bash scripts/cx-core-claim.sh \
  --runner codex \
  --session-id <session-id> \
  --branch <branch> \
  --worktree-path <worktree-path> \
  --feature <feature-slug> \
  --tasks <task-ids>
```

只有拿到 lease 后，Codex 才能写：

- feature 执行状态
- task owner
- 任务完成度
- handoff 后的接续状态

## 四种跨运行器场景

### 1. CC 创建 feature A，Codex 创建 feature B

- 两边都向同一个 `cx core` 注册
- 每个 feature 绑定各自 worktree
- 并行执行是安全的

### 2. CC 规划，Codex 执行

- `cc` adapter 写 PRD / Design / Plan
- Codex 读取同一 feature 的共享文档与状态
- 通过 `claim + worktree` 接管执行

### 3. Codex 规划，CC 执行

- Codex 写需求或规划状态
- Claude Code 侧读取共享状态
- `cc` adapter 只在 lease 可用或 handoff 完成后继续执行

### 4. 中途 handoff，任一方向都成立

- 当前 owner 写 handoff record
- 目标 runner 接受 handoff
- lease 转移
- worktree 绑定保持一致或明确更新
- 之后由新 owner 继续推进

## Codex 运行时产物

Codex 私有产物统一落到：

```text
.cx/runtime/codex/
```

例如：

- context snapshot
- failure snapshot
- config change note
- codex-specific recovery memo

这些文件不能反向污染 `runtime/cc/`。

## Dashboard Bridge Contract

Codex 侧高频入口最终要与 Claude Code 使用同一套 dashboard bridge 语义：

- 检测全局面板服务是否已运行
- 读取用户级 prompt state
- 只在首次使用或未决状态下提醒用户存在全局面板能力
- 用户已接受后自动注册当前项目
- 用户未接受时不阻塞 `cx-init` / `cx-prd`

这部分共享契约见：

- `docs/dashboard-architecture.md`
- `references/dashboard-registry-schema.json`
- `references/dashboard-runtime-schema.json`

## 最小成功标准

只要 Codex adapter 满足下面 5 条，就算接入成功：

- 明确以 runner `codex` 注册
- 写共享状态前先拿 lease
- 执行前先过 worktree 检查
- 遇到 `cc` owner 时优先走 handoff
- 临时产物只写到 `runtime/codex/`
