# Codex Adapter

这里存放 `cx` 在 Codex 侧的可安装技能源文件。

目标很明确：

- 与 Claude Code 插件共用同一套 `cx core`
- 与 Claude Code 插件共用同一套 `shared workflow core`
- 让 Codex 以 runner `codex` 身份接入共享控制平面
- 支持独立安装到用户级或项目级技能目录

## 安装方式

推荐使用仓库根目录的安装脚本：

```bash
bash scripts/install-codex.sh
```

默认会安装到用户级 `~/.agents/skills`。

开发期如果希望跟随当前仓库实时更新，可以使用符号链接模式：

```bash
bash scripts/install-codex.sh --mode symlink
```

如果希望安装到项目级技能目录：

```bash
bash scripts/install-codex.sh --scope project --project-root /path/to/project
```

## 目录说明

- `skills/`：Codex 侧真正可安装的 skill 包
- 安装后会额外生成 `cx-shared/`
  - `core/`：共享控制面与共享工作流大脑
  - `references/`：共享协议与模板
  - `scripts/`：共享 core 脚本

## 兼容策略

- 最新推荐路径：`.agents/skills` / `~/.agents/skills`
- 如需兼容旧的本地约定，可额外安装到 `.codex/skills` / `~/.codex/skills`
- 共享真相始终是项目里的 `.claude/cx` 与 `.claude/cx/core`
