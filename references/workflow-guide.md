# CX Workflow Guide

纯 `cx 3.0` 的参考指南。目标很简单：插件层提供能力，项目级 `.claude/cx` 提供真相。

## 核心原则

- 只保留 `cx`
- 项目级 `.claude/cx` 是运行时真相
- GitHub 是同步镜像，不是主控面
- 中文目录与文档名面向使用者，英文 JSON 协议面向脚本
- 默认自动路由，普通执行尽量不打断用户

## 初始化

第一次进入项目时运行：

```text
/cx-init
```

初始化负责：

- 创建 `.claude/cx/配置.json`
- 创建 `.claude/cx/状态.json`
- 创建 `功能/` 与 `修复/`
- 注册插件 hooks
- 在每个项目单独确认 `developer_id`

## 需求到交付

### 1. `/cx-prd`

- 多轮收集需求
- 自动评估规模
- 自动判断是否需要 Design
- 产物：`.claude/cx/功能/{功能标题}/需求.md`

### 2. `/cx-design`

- 只服务中大 feature
- 锁接口契约、状态枚举、字段映射、风险点
- 产物：`.claude/cx/功能/{功能标题}/设计.md`

### 3. `/cx-adr`

- 只在 L 规模或重大架构取舍时出现
- 产物：`.claude/cx/功能/{功能标题}/架构决策.md`

### 4. `/cx-plan`

- 默认轻量拆任务
- 仅当 PRD 明显引入新技术时，才进入技术识别支线
- 产物：`.claude/cx/功能/{功能标题}/任务/任务-{n}.md`

### 5. `/cx-exec`

- 默认自动推进可执行任务
- 只在关键决策点暂停
- 每个 task 独立 commit，并追加 `[cx:<feature-slug>] [task:<n>]`

### 6. `/cx-exec --all`

- 启动高自治团队模式
- 按任务图自适应安排 wave
- 尽可能组织 3+ 专业代理

### 7. `/cx-summary`

- 只负责闭环
- 生成 `.claude/cx/功能/{功能标题}/总结.md`
- 清空 `current_feature`
- 同步 GitHub 镜像

## Bug 修复

`/cx-fix` 默认走快速修复路径：

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

## Hook 设计

- `SessionStart`：输出极短恢复摘要
- `PreCompact`：写关键上下文快照
- `UserPromptSubmit`：只在阻塞或待收尾时提醒
- `PostToolUse`：做轻量格式化
- `Stop`：提示下次继续点

## GitHub 模式

- `off`：纯本地
- `local`：闭环时轻量同步
- `collab`：同步关键文档
- `full`：更完整的协作留痕

但不管哪种模式，GitHub 都只是同步镜像。
