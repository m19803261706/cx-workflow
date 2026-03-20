# CX Dashboard Smoke Test

这份 smoke 文档用于重复验证 `cx dashboard` 的最小闭环：

- 端口顺位分配
- 本地服务与前端启动
- `cx:init / cx:prd` 的首次提醒
- 已接受后的自动注册
- 列表页与项目详情页聚合展示

## 1. 预分配端口

先生成或刷新用户级 runtime：

```bash
bash scripts/cx-dashboard-ensure.sh
```

默认策略：

- 后端从 `43120` 开始顺位找空闲端口
- 前端从 `43130` 开始顺位找空闲端口

查看当前选择结果：

```bash
cat ~/.cx/dashboard/runtime.json
```

也可以直接提取：

```bash
BACKEND_PORT=$(jq -r '.backend_port' ~/.cx/dashboard/runtime.json)
FRONTEND_PORT=$(jq -r '.frontend_port' ~/.cx/dashboard/runtime.json)
REGISTRY_PATH=$(jq -r '.registry_path' ~/.cx/dashboard/runtime.json)
```

## 2. 启动本地服务与前端

启动后端：

```bash
cd apps/dashboard-service
CX_DASHBOARD_REGISTRY_PATH="$REGISTRY_PATH" \
CX_DASHBOARD_PORT="$BACKEND_PORT" \
npm start
```

启动前端：

```bash
cd apps/dashboard-web
npm run dev -- --host 127.0.0.1 --port "$FRONTEND_PORT"
```

## 3. 验证 bridge 首次提醒

在任意启用 `cx` 的项目里执行：

```bash
bash scripts/cx-dashboard-bridge.sh \
  --project-root /path/to/project \
  --display-name "示例项目"
```

首次使用预期：

- `prompt_state=unknown`
- `should_prompt=true`
- `project_registered=false`

## 4. 验证接受后的自动注册

用户接受后执行：

```bash
bash scripts/cx-dashboard-bridge.sh \
  --project-root /path/to/project \
  --display-name "示例项目" \
  --decision accept
```

预期：

- `prompt_state=accepted`
- `auto_register=true`
- `project_registered=true`

后续再次执行 bridge，不应重复提醒：

```bash
bash scripts/cx-dashboard-bridge.sh \
  --project-root /path/to/project \
  --display-name "示例项目"
```

预期：

- `should_prompt=false`
- `project_registered=true`

## 5. 验证服务接口

检查健康接口：

```bash
curl -s "http://127.0.0.1:${BACKEND_PORT}/api/dashboard/health" | jq
```

检查项目列表：

```bash
curl -s "http://127.0.0.1:${BACKEND_PORT}/api/dashboard/projects" | jq
```

检查 prompt-state：

```bash
curl -s "http://127.0.0.1:${BACKEND_PORT}/api/dashboard/runtime/prompt-state" | jq
```

## 6. 打开当前面板

```bash
bash scripts/cx-dashboard-open.sh
```

如果当前机器上已经有多个 `CC / Codex` 窗口并行工作，这个面板应该能够持续反映：

- 项目注册来源：`manual / auto_register / auto_scan`
- 当前 feature
- owner runner
- worktree
- handoff 状态
- 任务进度
