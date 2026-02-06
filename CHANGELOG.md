# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
