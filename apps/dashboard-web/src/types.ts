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
};
