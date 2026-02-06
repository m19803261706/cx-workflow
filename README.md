# cx-workflow

CX 开发工作流插件 — 从需求到交付的完整闭环工具集，专为 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 打造。

## 特性

- **完整开发管线**: PRD -> Design -> Plan -> Exec -> Review -> Summary
- **Bug 修复路径**: Fix -> Investigate -> Test -> Commit
- **API 契约机制**: Design Doc 定义契约，自动校验实现一致性
- **四档 GitHub 同步**: off / local / collab / full，适配单人到团队
- **智能规模评估**: S/M/L 三档自动决定流程复杂度
- **代码审查集成**: 全面审查 / 快速检查 / 跳过
- **CLAUDE.md 守卫**: 自动维护项目规范段落

## 安装

```bash
# 克隆到本地
git clone https://github.com/m19803261706/cx-workflow.git

# 在你的项目中初始化
/cx-init
```

## 命令速查

### 系统命令

| 命令 | 说明 |
|------|------|
| `/cx-init` | 项目初始化（仅运行一次）|
| `/cx-help` | 显示帮助文档 |
| `/cx-status` | 查看当前进度和状态 |
| `/cx-config` | 查看或修改工作流配置 |

### 开发命令

| 命令 | 说明 |
|------|------|
| `/cx-prd <功能名>` | 需求收集与规模评估 |
| `/cx-design` | 技术设计与 API 契约定义 |
| `/cx-adr` | 架构决策记录（L 规模）|
| `/cx-plan` | 任务分解与计划 |
| `/cx-exec` | 执行下一个任务 |
| `/cx-summary` | 功能汇总与发布 |
| `/cx-fix <描述>` | Bug 修复（轻量路径）|

## 工作流程

```
新功能开发：
  /cx-prd -> /cx-design -> /cx-plan -> /cx-exec (循环) -> /cx-summary

Bug 修复：
  /cx-fix <描述> -> 调查 -> 修复 -> 测试 -> 提交
```

### 规模评估

| 规模 | API 数量 | 数据模型 | 流程 |
|------|---------|---------|------|
| S (小) | 0-3 | 1 | PRD -> Plan -> Exec |
| M (中) | 4-10 | 2-5 | PRD -> Design -> Plan -> Exec |
| L (大) | 10+ | 复杂 | PRD -> Design -> ADR -> Plan -> Exec |

### API 契约机制

Design Doc 中定义三大契约章节，锁死前后端对齐规范：

1. **API 端点契约** — 请求/响应结构、状态码
2. **状态枚举契约** — 有效值和允许的状态转换
3. **字段映射契约** — DB snake_case -> DTO camelCase -> FE camelCase

契约生命周期：Design 定义 -> Plan 下沉到任务 -> Exec 自动校验

### GitHub 同步模式

| 模式 | 适用场景 | 行为 |
|------|---------|------|
| `off` | 单人项目 | 纯本地开发 |
| `local` | 小团队回顾 | 完成时创建汇总 Issue |
| `collab` | 团队协作 | PRD/Design 创建为 Issue + PR |
| `full` | 大团队管理 | 所有文档和任务都创建 Issue |

## 项目结构

```
cx-workflow/
├── .claude-plugin/       # 插件元数据
│   ├── plugin.json
│   └── marketplace.json
├── hooks/                # 生命周期钩子
│   ├── hooks.json
│   ├── session-start.sh
│   ├── pre-compact.sh
│   ├── prompt-submit.sh
│   └── post-edit.sh
├── skills/               # 技能定义
│   ├── cx-prd/
│   ├── cx-design/
│   ├── cx-plan/
│   ├── cx-exec/
│   ├── cx-fix/
│   ├── cx-summary/
│   └── ...
├── references/           # 参考文档与模板
│   ├── workflow-guide.md
│   ├── contract-spec.md
│   ├── config-schema.json
│   └── templates/
├── scripts/              # 安装脚本
│   └── cx-init-setup.sh
├── LICENSE               # GPL-3.0
├── README.md
└── CHANGELOG.md
```

## 许可证

本项目基于 [GPL-3.0](LICENSE) 许可证开源。

## 作者

**chengxuan** — [GitHub](https://github.com/m19803261706)
