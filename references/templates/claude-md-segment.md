# CLAUDE.md CX 3.0 Segment Template

Keep this segment concise. It should summarize the active CX runtime state, not duplicate workflow docs.

---

## Template

```markdown
<!-- CX-WORKFLOW-START -->
## CX 工作流 (v3.0)

### 命令
/cx-prd <功能名> | /cx-fix <描述> | /cx-exec | /cx-status | /cx-summary

### 当前进度
- 功能: [中文功能名]
- slug: [feature-slug]
- 进度: [X/Y]
- 当前: [task summary]

### 项目规范
- API: [项目接口模式]
- 命名: [关键命名规则]
- 测试: [主要验证命令]
- 提交: [type(scope): desc [cx:slug] [task:n]]
<!-- CX-WORKFLOW-END -->
```

---

## Rules

- 只保留项目当前运行时摘要
- 复杂流程请引用 `references/workflow-guide.md`
- `slug` 仅作内部关联提示，不替代中文功能名
- 不记录历史 feature
- 不记录长篇设计内容
