# PRD: CX Worktree-Per-Feature 架构迁移

> 日期：2026-03-20
> 状态：草稿
> 范围：CX 工作流核心架构（skills、scripts、core schema）

## 1. 问题陈述

### 1.1 现状

CX 工作流使用 `.claude/cx/状态.json` 作为项目级状态文件，其中 `current_feature` 是一个**全局单指针**。当 CC 和 CX（Codex）同时工作时：

- CC 创建 Feature A 的 PRD → `current_feature = "feature-a"`
- CX 同时创建 Feature B 的 PRD → `current_feature = "feature-b"`（覆盖了 CC 的上下文）

更严重的是，AI 模型会绕过脚本直接用 `Write` 工具全量覆盖 `状态.json`，导致其他 feature 的 tasks 数据丢失。

### 1.2 并发场景矩阵

| 场景 | CC | CX | 当前架构是否支持 |
|------|----|----|:---:|
| 串行交接 | PRD → 交给 CX | Design → Exec | 部分（handoff 协议在，但全局指针冲突）|
| 并行独立 | Feature A 全流程 | Feature B 全流程 | 不支持 |
| 并行同 feature | Task 1 | Task 2 | 不支持 |
| 单 runner 多 feature | 先做 A 再做 B | — | 支持但切换丢状态 |

### 1.3 根因

问题不在存储格式（JSON vs DB），而在**数据模型**：一个全局 `current_feature` 指针无法表达"CC 在做 A，CX 在做 B"。

## 2. 目标

### 2.1 核心目标

**让 CC 和 CX 能在同一个项目中安全并行工作，互不干扰。**

### 2.2 具体目标

1. CC 和 CX 可以同时各自推进不同 feature，状态互不覆盖
2. CC 创建 PRD 后，CX 能自然接手继续执行，无需复杂 handoff 协议
3. 同一 feature 的不同 task 可以被不同 runner 并行执行
4. 废弃全局 `current_feature` 指针，每个 runner 的上下文由 worktree CWD 决定

### 2.3 非目标

- 不改变 CX 的用户命令接口（`/cx:cx-prd`、`/cx:cx-exec` 等保持不变）
- 不引入外部依赖（数据库、消息队列等）
- 不改变 feature 的文档格式（需求.md、设计.md 等保持不变）

## 3. 解决方案：Worktree-Per-Feature 模型

### 3.1 核心思想

**一个 Feature = 一个 Git Worktree = 一个分支。**

参考 Superpowers 5.0.5 的模型：
- `using-git-worktrees` — 创建隔离 worktree
- `finishing-a-development-branch` — merge/PR 回主分支
- git 本身做状态同步和交接

### 3.2 架构变化

**Before（共享 JSON）：**

```
项目根/
├── .claude/cx/状态.json          ← 全局 current_feature（冲突点）
├── .claude/cx/功能/功能A/        ← Feature A 状态
├── .claude/cx/功能/功能B/        ← Feature B 状态
└── .claude/cx/core/              ← 共享控制平面（也被直接覆盖）
```

CC 和 CX 都在同一个目录下读写同一套文件。

**After（Worktree 隔离）：**

```
项目根/ (main)                    ← 主分支，已完成的 feature 合并到这里
├── .worktrees/
│   ├── feature-a/                ← CC 的工作空间（分支 feature/feature-a）
│   │   ├── src/...               ← 业务代码
│   │   └── .claude/cx/功能/功能A/ ← Feature A 的私有状态
│   │
│   └── feature-b/                ← CX 的工作空间（分支 feature/feature-b）
│       ├── src/...
│       └── .claude/cx/功能/功能B/ ← Feature B 的私有状态
```

每个 worktree 是完全独立的工作目录，天然无冲突。

### 3.3 状态同步机制

**Feature 内状态**（tasks、进度、文档）：
- 存在各自 worktree 的 `.claude/cx/功能/{title}/` 里
- 通过 `git commit` 持久化到分支
- 天然隔离，无需同步

**跨 Feature 感知**（"项目里有哪些 feature"）：
- 通过 `git branch --list 'feature/*'` 发现
- 或通过 `git worktree list` 查看活跃 worktree
- 不再依赖 `状态.json` 的 features 索引

**串行交接**（CC PRD → CX 接手）：
- CC 在 `feature/xxx` 分支创建 PRD，commit
- CX 基于同一个分支创建自己的 worktree，或直接在同一个 worktree 工作
- Feature 的 `.claude/cx/功能/{title}/状态.json` 记录当前阶段
- CX 看到 `workflow_phase: "prd"` → 知道该做 design 或 plan 了

**Feature 完成**：
- 通过 merge 或 PR 合回 main
- worktree 清理（参考 Superpowers 的 `finishing-a-development-branch`）

### 3.4 `current_feature` 废弃策略

| 原职责 | 新方案 |
|--------|--------|
| "我在做哪个 feature" | Runner 的 CWD（worktree 路径）即上下文 |
| "项目有哪些 feature" | `git branch --list 'feature/*'` 或 `git worktree list` |
| "feature 什么状态" | 各分支内 `.claude/cx/功能/{title}/状态.json` |
| "谁在 own 这个 feature" | 各分支内 `.claude/cx/core/features/{slug}.json` 的 `execution_owner` |

## 4. Skill 约束设计

参考 Superpowers 的多层约束模型：

### 4.1 Hard Gate：强制 Worktree 隔离

所有执行类 skill（`cx-prd`、`cx-design`、`cx-plan`、`cx-exec`、`cx-fix`）必须：

```markdown
<HARD-GATE>
除非用户显式指定 --inline，否则禁止在主分支（main/master）上直接执行。
必须先创建或进入 feature worktree。
</HARD-GATE>
```

### 4.2 REQUIRED 依赖链

```
cx-prd → 创建 worktree（如果不存在）
cx-design → 检测当前 worktree，拒绝在 main 上执行
cx-plan → 检测当前 worktree，拒绝在 main 上执行
cx-exec → 检测当前 worktree，拒绝在 main 上执行
cx-summary → 完成后提供 merge/PR 选项（参考 finishing-a-development-branch）
```

### 4.3 Worktree 生命周期

```
cx-prd 创建:
  git worktree add .worktrees/{feature-slug} -b feature/{feature-slug}

cx-exec 继续:
  检测 CWD 是否在 worktree 中
  如果不在 → 列出可用 worktree 让用户选择
  如果在 → 直接继续

cx-summary 完成:
  所有 task 完成 → 提供 4 个选项：
  1. Merge 回 main
  2. Push + 创建 PR
  3. 保留分支（稍后处理）
  4. 丢弃（需要确认）
```

### 4.4 Red Flags

```
Never:
- 在 main/master 上直接执行 cx-prd/cx-exec（除非 --inline）
- 直接 Write 或 Edit .claude/cx/状态.json（必须通过脚本）
- 跳过 worktree 检测直接开始执行
- 在一个 feature 的 worktree 里操作另一个 feature 的状态
- 在 worktree 里修改不属于当前 feature 的代码（超出分支范围）
```

### 4.5 反合理化表

| 借口 | 现实 |
|------|------|
| "这个改动很小，不需要 worktree" | 小改动也会污染 main 分支上下文 |
| "只有我一个人用，不需要隔离" | 你可能同时开多个 CC 窗口 |
| "创建 worktree 太慢了" | `git worktree add` 是毫秒级操作 |
| "我等下再切 worktree" | 切分支后上下文丢失更痛苦 |
| "这个 feature 很快就做完" | 做完了 merge 回来也很快 |

## 5. 对 CX 现有模块的影响

### 5.1 需要改动的 Skills

| Skill | 改动 |
|-------|------|
| `cx-init` | 初始化时创建 `.worktrees/` 目录 + 添加到 `.gitignore` |
| `cx-prd` | PRD 完成后自动创建 feature worktree |
| `cx-design` | 检测 worktree，拒绝 main 执行 |
| `cx-plan` | 检测 worktree，拒绝 main 执行 |
| `cx-exec` | 检测 worktree，提供 worktree 选择 |
| `cx-fix` | 小修复允许 inline（`--inline` 模式），大修复走 worktree |
| `cx-status` | 聚合所有 worktree 的 feature 状态 |
| `cx-summary` | 完成后提供 merge/PR/keep/discard 4 个选项 |

### 5.2 需要改动的 Scripts

| Script | 改动 |
|--------|------|
| `cx-workflow-prd.sh` | 创建 worktree + 分支，去掉 `update_project_status` 中的 `current_feature` |
| `cx-workflow-exec-dispatch.sh` | 从 worktree CWD 推导 feature，不再读全局指针 |
| `cx-workflow-status.sh` | 遍历 `git worktree list` 聚合状态 |
| `cx-workflow-summary.sh` | 新增 merge/PR 选项 |
| 新增 `cx-worktree.sh` | Worktree 创建、检测、列表、清理的通用工具脚本 |

### 5.3 需要改动的 Schema

| Schema | 改动 |
|--------|------|
| `状态.json` | 去掉 `current_feature`，瘦身为最小索引或废弃 |
| `core/projects/project.json` | 去掉 `current_feature`，保留 features 注册 |
| Feature status schema | 新增 `branch` 和 `worktree_path` 字段 |

### 5.4 Dashboard 影响

Dashboard service 的 `readProjectAggregation` 需要适配：
- 从 `git worktree list` + 各分支的 `.claude/cx/` 聚合状态
- 不再依赖 `状态.json` 的 `current_feature`
- 可以展示多个并行 feature 的状态

### 5.5 Codex Adapter 影响

Codex 的 skill 需要同步添加 worktree 约束：
- `adapters/codex/skills/*/SKILL.md` 加入相同的 Hard Gate
- Codex 的 worktree 创建使用 `../cx-shared/scripts/cx-worktree.sh`

## 6. CC 与 CX (Codex) 双端语法差异与统一约束

### 6.1 现有语法差异清单

两端共享同一套工作流语义，但 skill 语法和交互方式有根本差异：

| 维度 | CC (Claude Code) | CX (Codex) |
|------|-----------------|------------|
| **脚本路径** | `${CLAUDE_PLUGIN_ROOT}/scripts/cx-*.sh` | `../cx-shared/scripts/cx-*.sh` |
| **文件引用** | `@${CLAUDE_PLUGIN_ROOT}/references/...` | `../cx-shared/references/...` |
| **用户交互** | `AskUserQuestion` 工具（结构化 JSON） | 编号文字列表 + 等待用户回复 |
| **Runner 标识** | `--runner cc` | `--runner codex` |
| **Session ID** | CC 自动生成 | Codex 自行管理 |
| **Runtime 目录** | `.claude/cx/runtime/cc/` | `.claude/cx/runtime/codex/` |
| **Subagent 支持** | 有（Agent 工具 + `isolation: "worktree"`） | 无原生 subagent |
| **Skill 触发** | `/cx:cx-prd`（slash command） | skill 名或自然语言路由 |
| **Hooks** | 插件 `hooks/hooks.json` 自动注入 | 无 hooks，靠 skill 自约束 |
| **Worktree 创建** | 可用 Agent isolation worktree 或手动 | 只能手动 `git worktree add` |

### 6.2 Worktree 约束的双端写法

**CC 侧 SKILL.md 写法（参考 Superpowers 模式）：**

```markdown
<HARD-GATE>
禁止在主分支（main/master）上直接执行，除非用户显式传入 --inline。
必须先创建或进入 feature worktree。
</HARD-GATE>

### Worktree 检测

检查当前分支：
!`git branch --show-current`

如果是 main/master：
- 使用 AskUserQuestion 让用户选择或创建 worktree
- 列出已有 worktree：!`git worktree list`
- 创建新 worktree：!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-worktree.sh --create --feature <slug>`
```

**CX (Codex) 侧 SKILL.md 写法：**

```markdown
## 强制规则

**禁止在主分支（main/master）上直接执行，除非用户显式要求 inline 模式。**

### Worktree 检测

先检查当前分支：

```bash
git branch --show-current
```

如果是 main/master，**必须（MUST）** 用编号文字列表询问：

```
当前在主分支上，需要切换到 feature 工作区：

1. 创建新 worktree（推荐）— git worktree add .worktrees/{slug} -b feature/{slug}
2. 进入已有 worktree — [列出可用 worktree]
3. 在当前分支直接开始（不推荐）

请回复编号：
```
```

### 6.3 交接场景的双端协调

**CC 创建 PRD → CX 接手执行：**

CC 侧（PRD 完成后 commit 到 feature 分支）：
```bash
# CC 在 worktree 中完成 PRD 后
git add .claude/cx/功能/{title}/
git commit -m "cx-prd: {title} [cc]"
git push -u origin feature/{slug}
```

CX 侧（发现并接手）：
```bash
# CX 发现待执行的 feature 分支
git branch -r --list 'origin/feature/*'
# 创建 worktree 基于该分支
git worktree add .worktrees/{slug} feature/{slug}
# 在 worktree 中读取 PRD，继续 design/plan/exec
```

**CX 先做 PRD → CC 接手执行（反向交接）：**

CX 侧完成 PRD 后 push 分支，CC 侧通过 `git worktree list` 或 `git branch -r` 发现分支，创建自己的 worktree 继续。

**关键约束：同一个 feature 的分支只有一个，两端通过 push/pull 同步。**

### 6.4 共享脚本的双端路径约定

新增的 `cx-worktree.sh` 脚本两端都需要调用，路径约定：

| 操作 | CC 写法 | CX 写法 |
|------|--------|--------|
| 创建 worktree | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-worktree.sh --create` | `bash ../cx-shared/scripts/cx-worktree.sh --create` |
| 检测 worktree | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-worktree.sh --check` | `bash ../cx-shared/scripts/cx-worktree.sh --check` |
| 列出 worktree | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-worktree.sh --list` | `bash ../cx-shared/scripts/cx-worktree.sh --list` |
| 清理 worktree | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-worktree.sh --cleanup` | `bash ../cx-shared/scripts/cx-worktree.sh --cleanup` |

### 6.5 统一约束清单（两端必须同时实现）

以下约束 CC 和 CX 的 SKILL.md 都必须包含，只是语法不同：

| 约束 | 说明 |
|------|------|
| **Worktree Hard Gate** | 非 main 分支才能执行 prd/design/plan/exec |
| **分支命名规范** | `feature/{slug}`（CC）或 `codex/{slug}`（CX）或统一 `feature/{slug}` |
| **Commit 纪律** | 每个阶段完成后必须 commit + push |
| **禁止直接 Write 状态文件** | 所有状态写入必须通过 `cx-worktree.sh` / `cx-workflow-*.sh` 脚本 |
| **Feature 发现** | 通过 `git branch --list 'feature/*'` + `git worktree list` 发现可接手的 feature |
| **Lease 检测** | 执行前检查 feature 分支的 `core/features/{slug}.json` 是否有其他 runner 的活跃 lease |
| **Summary 闭环** | 完成后提供 merge/PR/keep/discard 四选项 |

### 6.6 参考：Superpowers 的跨平台兼容模式

Superpowers 通过 `GEMINI.md` + `references/gemini-tools.md` 提供工具映射表，让同一套 skill 逻辑在不同 CLI 平台上运行。CX 可以参考这种模式：

- 在 `references/` 中维护一份 **CC ↔ Codex 工具映射表**
- Skill 正文用统一的伪代码描述逻辑
- 具体的工具调用语法在映射表中查找

## 7. 迁移策略

### 6.1 向后兼容

- 已存在的 `状态.json` 不立即删除，保留为只读备份
- 脚本检测到 `状态.json` 中有 `current_feature` 时，打印迁移提示
- `--inline` 模式允许用户在 main 上直接工作（opt-out 安全阀）

### 6.2 迁移步骤

1. 新的 `cx-worktree.sh` 脚本先落地
2. Skills 添加 worktree 检测逻辑（先 warn，不 block）
3. 稳定后 Hard Gate 生效（block）
4. `current_feature` 从写入逻辑中移除
5. Dashboard 适配新数据源

## 8. 成功指标

- CC 和 CX 可以同时各自推进不同 feature，零冲突
- 单个 CC 窗口创建 PRD 不会覆盖其他窗口的 feature 上下文
- Feature 交接通过 git 分支自然完成，无需手动 handoff 命令
- `状态.json` 不再被 AI 模型直接 Write 覆盖

## 9. 规模评估

**L（大）** — 涉及核心架构变更：7 个 skill、6+ 个 script、3 个 schema、dashboard service、codex adapter。建议分阶段实施。
