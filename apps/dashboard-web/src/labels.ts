export function formatOwnerRunner(value: "cc" | "codex" | "none") {
  switch (value) {
    case "cc":
      return "Claude Code";
    case "codex":
      return "Codex";
    default:
      return "待分配";
  }
}

export function formatLifecycleStage(value: string | null) {
  switch (value) {
    case "draft":
      return "草稿";
    case "planned":
      return "已规划";
    case "ready":
      return "就绪";
    case "executing":
      return "执行中";
    case "blocked":
      return "已阻塞";
    case "handoff_pending":
      return "等待交接";
    case "completed":
      return "已完成";
    case "archived":
      return "已归档";
    case "summary":
      return "已总结";
    case "summarized":
      return "已总结";
    default:
      return "未知";
  }
}

export function formatSyncStatus(value: "healthy" | "stale" | "missing" | "error") {
  switch (value) {
    case "healthy":
      return "同步健康";
    case "stale":
      return "等待同步";
    case "missing":
      return "未接入";
    case "error":
      return "采集异常";
    default:
      return value;
  }
}

export function formatTaskStatus(value: string) {
  switch (value) {
    case "pending":
      return "待调度";
    case "ready":
      return "可执行";
    case "claimed":
      return "已认领";
    case "in_progress":
      return "进行中";
    case "completed":
      return "已完成";
    case "blocked":
      return "已阻塞";
    default:
      return value;
  }
}

export function formatServiceStatus(value: "stopped" | "running" | "degraded") {
  switch (value) {
    case "running":
      return "在线";
    case "degraded":
      return "降级";
    case "stopped":
      return "未启动";
    default:
      return value;
  }
}

export function formatWorkflowPhase(value: string | null) {
  switch (value) {
    case "prd":
      return "PRD 收敛";
    case "design":
      return "设计定稿";
    case "plan":
      return "任务规划";
    case "exec":
      return "执行调度";
    case "summary":
      return "结果收口";
    default:
      return value ?? "未进入";
  }
}

export function formatBindingStatus(value: string | null) {
  switch (value) {
    case "bound":
      return "已绑定 worktree";
    case "pending":
      return "等待绑定";
    case "unbound":
      return "未绑定 worktree";
    default:
      return value ?? "未知";
  }
}
