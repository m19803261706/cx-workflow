# 任务 {number}: {title}

## 元信息

- 功能: {feature_title}
- slug: {feature_slug}
- 阶段: {phase_name}
- 依赖: {depends_on}

## 任务目标

{goal}

## 目标文件

- 修改: `{modified_files}`
- 新增: `{created_files}`
- 测试: `{test_files}`

## 验收标准

- [ ] {acceptance_1}
- [ ] {acceptance_2}
- [ ] 契约与状态字段保持一致
- [ ] 提交信息使用 `[cx:{feature_slug}] [task:{number}]`

## 契约片段

### 关联接口

{api_contracts}

### 关联枚举

{enum_contracts}

### 字段映射

{field_mappings}

## 阻塞处理

如任务进入 `blocked`，请在 feature 级 `状态.json` 中记录:

```json
{
  "reason_type": "needs_decision",
  "message": "需要确认 API 契约调整"
}
```
