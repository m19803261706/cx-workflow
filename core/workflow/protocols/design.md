# Design Protocol

## 进入条件

- feature 已有 `需求.md`
- `workflow.needs_design = true`，或用户明确要求补设计

## 问答规则

- 只围绕高风险契约追问
- 优先确认：
  - API 路径与响应结构
  - 状态模型
  - 字段映射
  - 风险与测试重点

## 完成判定

- `设计.md` 已生成
- 契约章节已齐全
- docs 元信息已同步

## 落盘文件

- `.claude/cx/功能/<中文标题>/设计.md`

## 状态迁移

- `workflow.current_phase = "design"`
- `workflow.completion_status = "ready"`
- `workflow.next_route = "cx-plan"`

## 下一步路由

- 默认进入 `cx-plan`
- 重大架构取舍时可追加 `cx-adr`
