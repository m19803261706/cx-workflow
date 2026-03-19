---
name: summary
description: >
  CX 工作流 — 汇总发布与闭环。手动触发或在所有任务完成后进入。
  负责生成总结、同步 GitHub 镜像、清理当前 feature 指针。
disable-model-invocation: true
---

# cx-summary: 闭环与汇总

只负责收尾，不参与执行态主控。

## 使用方法

```text
/cx:summary
/cx:summary {功能名}
```

## 运行原则

- feature 完成后再进入 summary
- `cx:summary` 不负责补救执行问题
- `GitHub 为同步镜像`，项目级 `.claude/cx` 才是真相

## 核心步骤

### Step 0: 读取闭环输入

- 当前 feature 的 `状态.json`
- `需求.md / 设计.md / 架构决策.md / 总结.md`
- 本轮相关 git commits

### Step 1: 可选代码审查

如果 `code_review=true`，在闭环前做一次完整审查选择：

- 全面审查
- 快速审查
- 跳过

但这一步是闭环前检查，不是执行期主控。

### Step 2: 生成总结文档

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

### Step 4: 收尾状态

闭环完成后：

- feature 状态更新为 `summarized`
- `配置.json.current_feature` 清空
- 历史 feature 文档完整保留
