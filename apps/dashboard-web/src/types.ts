export type DashboardHealth = {
  serviceStatus: "stopped" | "running" | "degraded";
  serviceHost: string;
  backendPort: number | null;
  frontendPort: number | null;
  apiBaseUrl: string | null;
  frontendUrl: string | null;
  registryPath: string;
  lastStartedAt: string | null;
  lastCheckedAt: string;
  lastError: string | null;
};

export type ProjectSummary = {
  id: string;
  rootPath: string;
  displayName: string;
  registrationSource: "manual" | "auto_register" | "auto_scan";
  syncStatus: "healthy" | "stale" | "missing" | "error";
  currentFeatureSlug: string | null;
  currentFeatureTitle: string | null;
  lifecycleStage: string | null;
  ownerRunner: "cc" | "codex" | "none";
  worktreePath: string | null;
  handoffPending: boolean;
  progressCompleted: number;
  progressTotal: number;
  featureStatus?: string | null;
  workflowPhase: string | null;
  activeFeatureCount?: number;
};

export type FeatureDetail = {
  slug: string;
  title: string;
  workflowPhase: string | null;
  nextRoute: string | null;
  ownerRunner: "cc" | "codex" | "none";
  ownerSessionId: string | null;
  worktreePath: string | null;
  bindingStatus: string | null;
  handoffPending: boolean;
  progress: {
    completed: number;
    total: number;
  };
  docs: Record<string, string>;
  tasks: Array<{
    id: number | string;
    title: string;
    status: string;
    phase: number | null;
    parallel: boolean;
    dependsOn: Array<number | string>;
    parallelGroup: string | null;
  }>;
};

export type ProjectDetail = {
  project: ProjectSummary;
  features: Array<FeatureDetail>;
  activeSessions: Array<{
    sessionId: string;
    runner: "cx" | "cc" | "codex";
    branch: string;
    worktreePath: string;
    claimedFeature: string | null;
    claimedTasks: Array<number | string>;
    lastHeartbeat: string;
  }>;
};
