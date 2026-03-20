---
name: cx-fix
description: >
  CX 工作流 — Bug 修复。当用户提到"修 bug"、"fix"、"报错"、"debug"、
  "修复"时触发。默认走快速修复路径，复杂问题再升级为更深入的调查。
disable-model-invocation: true
---

# cx-fix: 轻量修复与复杂升级

先快修，只有问题明显复杂时才升级成更重的调查。

## Worktree 检测

cx-fix 对 worktree 的要求比其他 skill 宽松：

- **小修复（bug fix、hotfix）**：允许在当前分支直接修复（`--inline` 模式）
- **大修复（涉及多文件重构）**：建议创建 worktree 隔离

执行前检测：

```bash
check_output=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-worktree.sh check \
  --inline \
  --project-root "$(git rev-parse --show-toplevel)" 2>&1) || true
```

默认 inline 模式，不强制 worktree。

先阅读：

- `core/workflow/README.md`
- `core/workflow/protocols/fix.md`

## 使用方法

```text
/cx:cx-fix {问题描述}
/cx:cx-fix
```

## 默认路径

1. 调查复现
2. 定位根因
3. 最小修复
4. 运行最相关验证
5. 记录修复结论
6. 提交代码

这是 Claude Code 侧的 `cc` adapter 修复入口；如果当前问题归属的 feature 已由 `codex` 持有，先提示 handoff，再决定是否继续。

优先调用共享 runner：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cx-workflow-fix.sh \
  --title "<问题标题>" \
  --runner cc \
  --session-id <session-id>
```

## 升级条件

只有这些情况才把修复升级为复杂模式：

- 根因不明确，需要多假设并行调查
- 涉及多个模块或高风险兼容性
- 修复失败后出现连锁回归
- 需要结构化记录阻塞原因

## 产物与路径

修复记录保存到：

```text
.claude/cx/修复/{问题标题}/修复记录.md
```

如果修复过程被阻塞，也应在修复记录里写明：

- 已尝试了什么
- 当前卡在哪里
- 是否需要用户决策或外部信息

## 提交规范

fix 路径提交使用：

```text
fix(scope): description [cx-fix:<fix-slug>]
```

示例：

```text
fix(liuyao): repair divine transaction path [cx-fix:liuyao-divine-500]
```

## 与 GitHub 的关系

GitHub 只承担同步记录，不是修复主控。
本地 `.claude/cx/修复/` 才是运行时真相。
