# Summary Protocol

## 进入条件

- feature 已完成执行
- 需要做最终闭环

## 问答规则

- 只围绕结果、验证、设计调整与交付边界
- 不把执行期问题拖到 summary 阶段补救

## 完成判定

- `总结.md` 已落盘
- feature 状态已推进到 `summarized`
- `current_feature` 已清空

## 落盘文件

- `.claude/cx/功能/<中文标题>/总结.md`

## 状态迁移

- feature 中文状态：`summarized`
- shared core lifecycle：`archived`
- `workflow.current_phase = "summary"`
- `workflow.completion_status = "done"`

## 下一步路由

- 无后续 feature：结束
- 如有新需求：回到 `cx-prd`
