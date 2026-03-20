---
name: cx-summary
description: >
  CX 工作流 — 汇总发布与闭环。手动触发或在所有任务完成后进入。
  负责生成总结、同步 GitHub 镜像、清理当前 feature 指针。
---

# cx-summary: 闭环与汇总

只负责收尾，不参与执行态主控。

先阅读：

- `core/workflow/README.md`
- `core/workflow/protocols/summary.md`

## 使用方法

```text
/cx:cx-summary
/cx:cx-summary {功能名}
```

## 运行原则

- feature 完成后再进入 summary
- `cx:summary` 不负责补救执行问题
- `GitHub 为同步镜像`，项目级 `.claude/cx` 才是真相
- 这是 Claude Code 侧的 `cc` adapter 收尾动作，不会擅自改写其他 runner 的 lease
- 允许在用户明确确认“开始收尾”后，由工作流自动衔接到本 skill

## 核心步骤

### Step 0: 读取闭环输入

- 当前 feature 的 `状态.json`
- `需求.md / 设计.md / 架构决策.md / 总结.md`
- 本轮相关 git commits

### Step 1: 可选代码审查

如果 `code_review=true`，**必须（MUST）** 使用 `AskUserQuestion` 工具询问：

```json
{
  "questions": [
    {
      "question": "闭环前做代码审查吗？",
      "header": "Code Review",
      "multiSelect": false,
      "options": [
        {
          "label": "全面审查 (Recommended)",
          "description": "完整检查代码质量、契约一致性和测试覆盖"
        },
        {
          "label": "快速审查",
          "description": "只检查关键路径和明显问题"
        },
        {
          "label": "跳过",
          "description": "直接进入总结阶段"
        }
      ]
    }
  ]
}
```

这一步是闭环前检查，不是执行期主控。

### Step 2: 生成总结文档

优先调用共享 runner：

```bash
bash scripts/cx-workflow-summary.sh \
  --feature <feature-slug> \
  --runner cc \
  --session-id <session-id>
```

输出到：

```text
.claude/cx/功能/{功能标题}/总结.md
```

总结只回答这些问题：

- 做了什么
- 关键契约或设计有没有调整
- 最终交付和验证结果是什么

### Step 3: 同步 GitHub 镜像

根据 `github_sync` 决定是否同步：

- `off`：只保留本地
- `local`：轻量同步结果
- `collab / full`：同步关键文档和闭环结果

但无论哪种模式，GitHub 都不是执行真相源。

### Step 4: 分支合并与工作区清理

检查 feature 的 `状态.json` 中的 `worktree.isolation_mode`：

**如果 `isolation_mode = "worktree"`（独立工作区）：**

**必须（MUST）** 使用 `AskUserQuestion` 工具询问合并方式：

```json
{
  "questions": [
    {
      "question": "功能「{feature_title}」已完成，如何合并回主分支？",
      "header": "合并方式",
      "multiSelect": false,
      "options": [
        {
          "label": "创建 Pull Request (Recommended)",
          "description": "推送分支并创建 PR，适合需要 review 的场景"
        },
        {
          "label": "直接合并到主分支",
          "description": "将 worktree 分支合并回主分支并清理"
        },
        {
          "label": "暂不合并",
          "description": "保留工作区和分支，稍后手动处理"
        }
      ]
    }
  ]
}
```

选项 1（创建 PR）：
```bash
git push -u origin worktree-{feature-slug}
gh pr create --title "feat: {feature_title}" --body "..."
```

选项 2（直接合并）：
```bash
# 先退出 worktree 回到主目录
ExitWorktree(save: true)
# 在主分支合并
git merge worktree-{feature-slug}
# 清理 worktree 分支
git branch -d worktree-{feature-slug}
```

选项 3（暂不合并）：
- 保留 worktree 和分支
- 提示用户后续可以通过 `git worktree list` 查看

**如果 `isolation_mode = "inline"`（当前分支直接开发）：**

- 跳过合并步骤，代码已在当前分支上

### Step 5: 收尾状态

闭环完成后：

- feature 状态更新为 `summarized`
- `配置.json.current_feature` 清空
- 历史 feature 文档完整保留
- 如果使用了独立工作区且已合并，worktree 信息标记为 `merged`
