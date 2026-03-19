# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [3.0.0] - 2026-03-19

### Added
- 纯 cx 3.0 协议：项目级 `配置.json`、项目级 `状态.json`、feature 级 `状态.json`
- 中文目录与文档命名：`功能/`、`修复/`、`需求.md`、`设计.md`、`总结.md`
- 低噪声 hook 恢复模型与 `stop-check.sh`
- `--all` 高自治团队模式与 3+ 专业代理语义
- 结构化 `blocked.reason_type` 状态
- 插件级 smoke 校验脚本与最小 fixture

### Changed
- 从 `2.0` 的双轨/重流程叙事收敛为纯 `cx 3.0`
- `cx-init` 改为项目级初始化，hook 只保留插件提供
- `cx-plan` 改为默认轻量，仅在明显引入新技术时进入额外支线
- `cx-exec` 改为默认自动推进，关键决策点才暂停
- `cx-summary` 改为只做闭环，GitHub 为同步镜像
- README、workflow-guide、skill 文档与模板全部升级到纯 `cx 3.0`

## [3.1.0] - 2026-03-20

### Added
- `StopFailure` 与 `ConfigChange` 两个 2026 官方 hooks 事件的最小支持
- 插件 hooks 失败态与配置变更快照文件
- 共享 `cx core` 控制平面：project / feature / session / handoff / worktree schema
- `cx-core-claim.sh`、`cx-core-handoff.sh`、`cx-core-worktree.sh`、`cx-core-migrate.sh`
- Codex adapter 指南与技能契约文档
- Codex adapter 可安装 skill 包与 `install-codex.sh`

### Changed
- 插件名称收敛为 `cx`，命令面统一改为 `/cx:*`
- 强副作用 skills 改为手动触发，符合 2026 skills frontmatter 建议
- `cx-init` 不再向项目 `.claude/settings.json` 写入 hooks，改为完全依赖插件 `hooks/hooks.json`
- README、workflow-guide、模板和技能文档对齐 2026 官方插件规范
- Claude Code 插件被收敛为共享 `cx core` 上的 `cc` adapter
- hooks 运行时快照改为写入 `.claude/cx/runtime/cc/`
- 同一个仓库现在同时承载 CC 插件 adapter 与 Codex skill adapter

### Rollout
- Claude Code 最低版本要求为 `2.1.79`
- Codex 侧需要先同步新的 `cx core` 技能契约，再参与同项目协作
- 已有项目必须先运行 `bash scripts/cx-core-migrate.sh`，再启用双运行器
- Codex 侧默认安装目标切到 `.agents/skills`

## [2.0.0] - 2026-02-06

### Added
- Skills-based architecture with 12 skill modules
- API contract mechanism (3-stage lifecycle: Design -> Sink -> Validate)
- Four GitHub sync modes: off / local / collab / full
- Scale assessment system (S/M/L) for workflow path selection
- Lifecycle hooks: SessionStart, PreCompact, UserPromptSubmit, PostToolUse, Stop, SubagentStop
- Bug fix lightweight path (`/cx-fix`)
- Code review integration (full audit / quick check / skip)
- CLAUDE.md smart guardian with convention detection
- Plugin marketplace metadata
- Reference docs and templates (PRD, Design, Fix, Summary)

## [1.0.0] - 2026-01-01

### Added
- Initial CX workflow system
- Basic PRD -> Plan -> Exec pipeline
- GitHub Issue integration
