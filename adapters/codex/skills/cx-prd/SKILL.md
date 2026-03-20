---
name: cx-prd
description: "Codex 侧 CX 需求收集。创建需求文档、评估规模，并同步共享 cx core 的 feature 注册信息。"
---

# CX PRD (Codex Adapter)

先阅读：

- `../cx-shared/core/workflow/README.md`
- `../cx-shared/core/workflow/protocols/prd.md`
- `../cx-shared/references/codex-skill-contract.md`
- `../cx-shared/references/templates/prd.md`
- `../cx-shared/references/core-schema-overview.md`

## 目标

- 在 `.claude/cx/功能/<中文标题>/需求.md` 写出 PRD
- 为 feature 生成稳定 slug
- 在共享 `cx core` 中注册或更新该 feature
- 优先通过 `../cx-shared/scripts/cx-workflow-prd.sh` 做确定性 scaffold，再继续补充问答内容

## Worktree 隔离（强制）

禁止在主分支（main/master）上创建 PRD，除非用户显式要求 inline 模式。

执行前检测：

```bash
check_output=$(bash ../cx-shared/scripts/cx-worktree.sh check \
  --project-root "$(git rev-parse --show-toplevel)" 2>&1) || true
```

如果在主分支上，**必须（MUST）** 用编号文字列表询问：

```
当前在主分支上，需要为新功能创建隔离工作区：

1. 创建 Feature Worktree（推荐）— 自动创建隔离分支和工作目录
2. 在当前分支直接开始（不推荐）— 不隔离

请回复编号：
```

用户选 1 时：
```bash
bash ../cx-shared/scripts/cx-worktree.sh create \
  --feature "{feature-slug}" \
  --runner codex \
  --project-root "$(git rev-parse --show-toplevel)"
```

然后 `cd` 到新 worktree 路径继续后续步骤。

用户选 2 时，继续在当前分支执行。

## 执行规则

- PRD 阶段不需要 claim lease
- 但如果发现同名 feature 已由 `cc` 持有并正在执行，先提醒用户复用或 handoff，不要直接覆盖
- `current_feature` 可以指向新 slug，但必须保证项目注册表与 feature 文件同步
- 在开始长问答前，先确保 shared runner 已经把最小 PRD 和 feature 注册落盘
- 不要把大量时间花在无关文档搜索上；先 scaffold，再继续问答收敛

## 多轮问答规则（Codex 文字降级）

Codex 没有 `AskUserQuestion` 工具，**必须（MUST）** 使用编号文字列表 + 等待用户回复。

**MUST** 主动分析代码后提出 2-3 个可行方案，不能只被动提问。

每轮用以下格式：

```
[当前理解复述]

--- 实现方向 ---
1. 方案 A（推荐）— {优势、工作量}
2. 方案 B — {优势、工作量}
3. 方案 C — {优势、工作量}

请回复编号，或补充你的想法：

--- 影响范围（多选，用逗号分隔）---
1. 前端 UI/交互
2. 后端 API/逻辑
3. 数据库/状态
4. 基础设施/部署

请回复编号（如 1,2,3）：
```

通常 2-3 轮收敛，复杂功能不超过 4 轮。

推荐先执行：

```bash
bash ../cx-shared/scripts/cx-workflow-prd.sh \
  --project-root "$(git rev-parse --show-toplevel)" \
  --title "<功能标题>" \
  --slug "<feature-slug>" \
  --runner codex \
  --session-id "<session-id>" \
  --size "<S|M|L>" \
  --needs-design "<true|false>" \
  --question-mode conversation
```

在 shared runner 完成最小 scaffold 后，统一调用：

```bash
bash ../cx-shared/scripts/cx-dashboard-bridge.sh \
  --project-root "$(git rev-parse --show-toplevel)" \
  --display-name "$(basename "$(git rev-parse --show-toplevel)")"
```

然后按这些规则继续：

- 如果 `should_prompt=true`
  - 先用对话方式提醒用户存在全局 Web 管理面板
  - 用户接受时执行 bridge + `--decision accept`
  - 用户暂不启用时执行 bridge + `--decision decline`
  - 两种情况都不要阻塞当前 PRD

- 如果 `prompt_state=accepted` 且 `auto_register=true`
  - 当前项目应已自动注册
  - 不要重复提醒

## 输出

- `需求.md`
- `功能/<标题>/状态.json`
- `.claude/cx/core/features/<slug>.json`
- `.claude/cx/core/projects/project.json` 中的 feature 索引

## 路由

- S 规模：进入 `cx-plan`
- M/L 规模：进入 `cx-design`
