# PRD Protocol

## 进入条件

- 项目已经完成 `cx-init`
- 项目级 `.claude/cx/配置.json` 与 `.claude/cx/状态.json` 存在
- 如果 shared core 还不存在，允许先补建 core 再继续

## 问答规则

- CC 侧 **MUST** 使用 `AskUserQuestion` 工具做结构化问答；Codex 侧使用编号文字列表降级
- **MUST** 主动分析代码和上下文后提出 2-3 个可行方案供用户选择，不能只被动提问
- 每轮最多 4 个问题，每个问题最多 4 个选项
- 通常 2-3 轮收敛，复杂功能不超过 4 轮
- 一次只补当前最关键的缺口，不做漫无边际盘问
- 优先收敛：
  - 实现方向（主动推荐方案 + 单选）
  - 影响范围（多选：前端/后端/数据/基础设施）
  - 核心功能点（多选）
  - 验收标准（多选确认）
  - 明确 out-of-scope（多选）
  - 风险识别（多选）
- 用户明确要求”先生成最小 PRD”时，允许先落一个最小可编辑草稿

## 完成判定

PRD 阶段在以下条件满足时视为 ready：

- 已生成稳定 `slug`
- 已写出 `需求.md`
- 已创建 feature 级 `状态.json`
- 已把 feature 注册进 shared core
- 已给出 `size` 与 `needs_design`

## 落盘文件

- `.claude/cx/功能/<中文标题>/需求.md`
- `.claude/cx/功能/<中文标题>/状态.json`
- `.claude/cx/core/features/<slug>.json`
- `.claude/cx/core/projects/project.json`

## 状态迁移

- feature 中文状态：`drafting`
- shared core lifecycle：`draft`
- `workflow.current_phase = "prd"`
- `workflow.completion_status = "ready"`

## 下一步路由

- `S`：`cx-plan`
- `M / L`：`cx-design`
- `L` 且存在重大架构取舍：允许追加 `cx-adr`
