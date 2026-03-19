# CX Workflow Guide

纯 `cx 3.1` 的参考指南。目标很简单：插件层提供能力，项目级 `.claude/cx` 提供真相。
在双运行器模式下，Claude Code 插件只是共享 `cx core` 上的 `cc` adapter，不再把自己视为整个系统。
从这版开始，`core/workflow/` 也开始承载共享工作流大脑。

## 核心原则

- 只保留 `cx`
- 插件命令遵循官方 namespaced 形式：`/cx:*`
- 项目级 `.claude/cx` 是运行时真相
- 共享 `cx core` 允许 `cc` / `codex` 两个 runner 协作
- `shared workflow core` 统一 PRD / Design / Plan / Exec / Fix / Status / Summary 的规则
- `cx dashboard` 作为全局观察台聚合多个项目状态，但不替代项目级真相源
- GitHub 是同步镜像，不是主控面
- 中文目录与文档名面向使用者，英文 JSON 协议面向脚本
- 默认自动路由，普通执行尽量不打断用户
- 强副作用 skill 默认手动触发
- 插件 hooks 由 `hooks/hooks.json` 自动接线，不再通过 init 写项目 settings

## 初始化

第一次进入项目时运行：

```text
/cx:init
```

初始化负责：

- 创建 `.claude/cx/配置.json`
- 创建 `.claude/cx/状态.json`
- 创建 `功能/` 与 `修复/`
- 在每个项目单独确认 `developer_id`
- 检查 Git / GitHub 接入状态
- 后续通过 `cx-dashboard-bridge` 接入全局面板检测与自动注册

如果项目已经带有旧版 `.claude/cx`，先运行：

```text
bash scripts/cx-core-migrate.sh
```

迁移完成后再进入双运行器模式。

## 需求到交付

### 1. `/cx:prd`

- 多轮收集需求
- 自动评估规模
- 自动判断是否需要 Design
- 通过共享 runner `scripts/cx-workflow-prd.sh` 做确定性落盘
- 后续会复用 `scripts/cx-dashboard-bridge.sh` 做全局面板检测、首次提醒与项目自动注册
- 产物：`.claude/cx/功能/{功能标题}/需求.md`

### 2. `/cx:design`

- 只服务中大 feature
- 锁接口契约、状态枚举、字段映射、风险点
- 产物：`.claude/cx/功能/{功能标题}/设计.md`

### 3. `/cx:adr`

- 只在 L 规模或重大架构取舍时出现
- 产物：`.claude/cx/功能/{功能标题}/架构决策.md`

### 4. `/cx:plan`

- 默认轻量拆任务
- 仅当 PRD 明显引入新技术时，才进入技术识别支线
- 先记录 feature 的推荐 worktree，再拆任务和状态
- 产物：`.claude/cx/功能/{功能标题}/任务/任务-{n}.md`

### 5. `/cx:exec`

- 默认自动推进可执行任务
- 只在关键决策点暂停
- 在 claim 前先调用 worktree 绑定检查，确认 runner 当前 checkout 与 feature 绑定一致
- 同一 feature 如果已经绑定到另一个 worktree，必须先走 handoff，不能直接并行 claim
- 每个 task 独立 commit，并追加 `[cx:<feature-slug>] [task:<n>]`

### 6. `/cx:exec --all`

- 启动高自治团队模式
- 按任务图自适应安排 wave
- 尽可能组织 3+ 专业代理

### 7. `/cx:summary`

- 只负责闭环
- 生成 `.claude/cx/功能/{功能标题}/总结.md`
- 清空 `current_feature`
- 同步 GitHub 镜像

## Bug 修复

`/cx:fix` 默认走快速修复路径：

- 调查
- 定位
- 修复
- 验证
- 提交
- 写修复记录

复杂问题才升级成更深入调查。

## 状态模型

### 项目级

`.claude/cx/状态.json` 维护：

- `current_feature`
- `features`
- `fixes`

### 功能级

`.claude/cx/功能/{功能标题}/状态.json` 维护：

- `status`
- `total`
- `completed`
- `phases`
- `tasks`
- `execution_order`
- `blocked.reason_type`

## 阻塞与恢复

阻塞必须结构化落盘：

```json
{
  "blocked": {
    "reason_type": "needs_decision",
    "message": "需要确认接口行为"
  }
}
```

恢复依赖 hook 和状态文件，而不是模型记忆。

## Worktree 规则

- 一个 feature 绑定一个 preferred worktree
- 不同 feature 可以落在不同 worktree 并行执行
- 同一 feature 未经 handoff 不能在多个 worktree 中同时执行
- `plan` 负责写推荐，`exec` 负责在 claim 前校验当前位置并拒绝错位 checkout

## 双运行器场景

- CC 创建 feature A，同时 Codex 创建 feature B
- CC 规划，Codex 执行
- Codex 规划，CC 执行
- 任一方向都可以中途 handoff

## Shared Workflow Core

共享工作流层位于：

- `core/workflow/README.md`
- `core/workflow/protocols/*.md`

这些协议定义的不是某个 adapter 的私有行为，而是两边共用的流程规则。
adapter 只负责入口与交互载体，不能再各自重新解释 PRD、Plan 或 Exec 语义。

## CX Dashboard

`cx dashboard` 是共享 `cx core` 的全局观察台。

稳定边界：

- 项目 `.claude/cx` 继续是真相源
- 本地服务负责聚合多个项目
- Web 前端只读展示聚合结果
- `cx:init` / `cx:prd` 通过同一 bridge helper 感知“面板是否已运行、是否需要提醒、是否自动注册当前项目”

第一版约束：

- 允许：查看项目列表、项目详情、feature/handoff 进度摘要、打开项目目录、复制建议命令、触发重扫
- 不允许：直接从面板发起 `cx:plan`、`cx:exec` 或写项目级真相

关键契约文件：

- `docs/dashboard-architecture.md`
- `references/dashboard-registry-schema.json`
- `references/dashboard-runtime-schema.json`

## Codex Adapter 安装

同一个 `cx` 仓库同时产出：

- Claude Code 插件 adapter
- Codex skill adapter

Codex 侧安装入口：

```bash
bash scripts/install-codex.sh
```

推荐目标：

- 用户级：`~/.agents/skills`
- 项目级：`<project>/.agents/skills`

如需兼容旧本地路径，可额外镜像到：

- `~/.codex/skills`
- `<project>/.codex/skills`

## Hook 设计

- `SessionStart`：输出极短恢复摘要
- `PreCompact`：写关键上下文快照
- `UserPromptSubmit`：只在阻塞或待收尾时提醒
- `PostToolUse`：做轻量格式化
- `Stop`：提示下次继续点
- `StopFailure`：记录 API 失败态快照
- `ConfigChange`：记录项目配置变动快照

## GitHub 模式

- `off`：纯本地
- `local`：闭环时轻量同步
- `collab`：同步关键文档
- `full`：更完整的协作留痕

但不管哪种模式，GitHub 都只是同步镜像。
