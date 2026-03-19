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
