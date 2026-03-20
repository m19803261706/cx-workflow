export type PromptState = "unknown" | "accepted" | "declined";
export type RegistrationSource = "manual" | "auto_register" | "auto_scan";
export type SyncStatus = "healthy" | "stale" | "missing" | "error";
export type OwnerRunner = "cc" | "codex" | "none";
export type LifecycleStage =
  | "draft"
  | "planned"
  | "ready"
  | "executing"
  | "blocked"
  | "handoff_pending"
  | "completed"
  | "archived";

export type DashboardRegistryProject = {
  id: string;
  root_path: string;
  display_name: string;
  registration_source: RegistrationSource;
  sync_status: SyncStatus;
  current_feature_slug: string | null;
  current_feature_title: string | null;
  lifecycle_stage: LifecycleStage | null;
  owner_runner: OwnerRunner;
  worktree_path: string | null;
  handoff_pending: boolean;
  progress_completed: number;
  progress_total: number;
  feature_status: string | null;
  feature_record_path: string | null;
  last_seen_at: string;
  last_synced_at: string | null;
};

export type DashboardRegistry = {
  version: "1.0";
  prompt_state: PromptState;
  auto_register: boolean;
  projects: Record<string, DashboardRegistryProject>;
  scan_roots: string[];
  ignored_roots: string[];
  updated_at: string;
};

export type ProjectSummary = {
  id: string;
  rootPath: string;
  displayName: string;
  registrationSource: RegistrationSource;
  syncStatus: SyncStatus;
  currentFeatureSlug: string | null;
  currentFeatureTitle: string | null;
  lifecycleStage: LifecycleStage | null;
  ownerRunner: OwnerRunner;
  worktreePath: string | null;
  handoffPending: boolean;
  progressCompleted: number;
  progressTotal: number;
  featureStatus: string | null;
  featureRecordPath: string | null;
  lastSeenAt: string;
  lastSyncedAt: string | null;
};

export type ProjectFeatureDetail = {
  slug: string;
  title: string;
  workflowPhase: string | null;
  nextRoute: string | null;
  ownerRunner: OwnerRunner;
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
  feature: ProjectFeatureDetail | null;
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
