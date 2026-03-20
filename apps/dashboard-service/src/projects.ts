import path from "node:path";
import { access, readdir, readFile } from "node:fs/promises";

import { ensureProjectId, findProjectEntryByRootPath, loadRegistry, mergeScanRoots, mergeSummaryIntoRegistry, normalizeRootPath, saveRegistry, upsertRegisteredProject } from "./registry.ts";
import type {
  DashboardRegistry,
  LifecycleStage,
  OwnerRunner,
  ProjectDetail,
  ProjectFeatureDetail,
  ProjectSummary,
  RegistrationSource,
  SyncStatus
} from "./types.ts";

type CollectProjectsOptions = {
  registryPath: string;
  scanRoots?: string[];
};

type RegisterProjectOptions = {
  registryPath: string;
  rootPath: string;
  displayName?: string;
  projectId?: string;
};

type ScanProjectsOptions = {
  registryPath: string;
  roots?: string[];
};

type CandidateProject = {
  id: string;
  rootPath: string;
  displayName: string;
  registrationSource: RegistrationSource;
};

type CoreProjectFeatureRecord = {
  slug: string;
  title: string;
  path: string;
  lifecycle: LifecycleStage;
  worktree_path: string | null;
  lease_session_id?: string | null;
  workflow_phase?: string | null;
  next_route?: string | null;
  last_updated?: string;
};

type CoreProjectRegistry = {
  current_feature: string | null;
  features: Record<string, CoreProjectFeatureRecord>;
  active_sessions: Record<
    string,
    {
      runner: "cx" | "cc" | "codex";
      session_id: string;
      branch: string;
      worktree_path: string;
      started_at: string;
      last_heartbeat: string;
      claimed_feature: string | null;
      claimed_tasks: Array<number | string>;
    }
  >;
};

type CoreFeatureRecord = {
  slug: string;
  title: string;
  lifecycle: {
    stage: LifecycleStage;
    updated_at: string;
  };
  planning_owner?: {
    runner: "cx" | "cc" | "codex";
    session_id: string;
  } | null;
  execution_owner?: {
    runner: "cx" | "cc" | "codex";
    session_id: string;
  } | null;
  worktree: {
    branch: string;
    worktree_path: string;
    binding_status: string;
  };
  workflow?: {
    current_phase?: string | null;
    next_route?: string | null;
  };
  docs?: Record<string, string>;
  tasks?: Array<{
    id: number | string;
    title: string;
    status: string;
    phase?: number;
    parallel?: boolean;
    depends_on?: Array<number | string>;
    parallel_group?: string;
  }>;
  handoffs?: Array<{
    accepted_at?: string | null;
  }>;
};

type FeatureStatusFile = {
  completed: number;
  total: number;
  status: string;
};

async function fileExists(filePath: string) {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function readJsonFile<T>(filePath: string): Promise<T> {
  return JSON.parse(await readFile(filePath, "utf8")) as T;
}

function nowIso() {
  return new Date().toISOString();
}

function isIgnoredDirectory(name: string) {
  return name === ".git" || name === "node_modules" || name === ".worktrees";
}

function resolveRelativeProjectPath(projectRoot: string, candidatePath: string) {
  if (path.isAbsolute(candidatePath)) {
    return candidatePath;
  }

  const normalized = candidatePath.startsWith(".claude/cx/")
    ? candidatePath
    : path.join(".claude/cx", candidatePath);
  return path.join(projectRoot, normalized);
}

async function discoverProjectRoots(scanRoot: string, ignoredRoots: Set<string>) {
  const normalizedRoot = normalizeRootPath(scanRoot);
  const discovered = new Set<string>();

  async function walk(currentPath: string): Promise<void> {
    if (ignoredRoots.has(currentPath)) {
      return;
    }

    const marker = path.join(currentPath, ".claude/cx/core/projects/project.json");
    if (await fileExists(marker)) {
      discovered.add(currentPath);
      return;
    }

    let entries;
    try {
      entries = await readdir(currentPath, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      if (!entry.isDirectory()) {
        continue;
      }
      if (isIgnoredDirectory(entry.name)) {
        continue;
      }
      await walk(path.join(currentPath, entry.name));
    }
  }

  await walk(normalizedRoot);
  return Array.from(discovered);
}

function buildProjectSummary(params: {
  candidate: CandidateProject;
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
  workflowPhase: string | null;
  activeFeatureCount: number;
}): ProjectSummary {
  return {
    id: params.candidate.id,
    rootPath: params.candidate.rootPath,
    displayName: params.candidate.displayName,
    registrationSource: params.candidate.registrationSource,
    syncStatus: params.syncStatus,
    currentFeatureSlug: params.currentFeatureSlug,
    currentFeatureTitle: params.currentFeatureTitle,
    lifecycleStage: params.lifecycleStage,
    ownerRunner: params.ownerRunner,
    worktreePath: params.worktreePath,
    handoffPending: params.handoffPending,
    progressCompleted: params.progressCompleted,
    progressTotal: params.progressTotal,
    featureStatus: params.featureStatus,
    featureRecordPath: params.featureRecordPath,
    lastSeenAt: params.lastSeenAt,
    lastSyncedAt: params.lastSyncedAt,
    workflowPhase: params.workflowPhase,
    activeFeatureCount: params.activeFeatureCount
  };
}

async function readFeatureStatus(projectRoot: string, featurePath: string | undefined) {
  if (!featurePath) {
    return null;
  }

  const featureStatusPath = path.join(resolveRelativeProjectPath(projectRoot, featurePath), "状态.json");
  if (!(await fileExists(featureStatusPath))) {
    return null;
  }

  return readJsonFile<FeatureStatusFile>(featureStatusPath);
}

async function readProjectAggregation(candidate: CandidateProject, timestamp = nowIso()) {
  const projectRoot = candidate.rootPath;
  const projectStatusPath = path.join(projectRoot, ".claude/cx/状态.json");
  const coreProjectPath = path.join(projectRoot, ".claude/cx/core/projects/project.json");

  if (!(await fileExists(projectStatusPath)) || !(await fileExists(coreProjectPath))) {
    return {
      summary: buildProjectSummary({
        candidate,
        syncStatus: "missing",
        currentFeatureSlug: null,
        currentFeatureTitle: null,
        lifecycleStage: null,
        ownerRunner: "none",
        worktreePath: null,
        handoffPending: false,
        progressCompleted: 0,
        progressTotal: 0,
        featureStatus: null,
        featureRecordPath: null,
        lastSeenAt: timestamp,
        lastSyncedAt: null,
        workflowPhase: null,
        activeFeatureCount: 0
      }),
      detail: null
    };
  }

  try {
    const projectStatus = await readJsonFile<{
      current_feature?: string | null;
      features?: Record<string, { title?: string; path?: string; status?: string }>;
    }>(projectStatusPath);
    const coreProject = await readJsonFile<CoreProjectRegistry>(coreProjectPath);

    const activeSessions = Object.values(coreProject.active_sessions ?? {}).map((session) => ({
      sessionId: session.session_id,
      runner: session.runner,
      branch: session.branch,
      worktreePath: session.worktree_path,
      claimedFeature: session.claimed_feature,
      claimedTasks: session.claimed_tasks,
      lastHeartbeat: session.last_heartbeat
    }));

    // 遍历所有 feature，而非只读取 current_feature
    const allFeatureSlugs = Object.keys(coreProject.features ?? {});
    const detailFeatures: ProjectFeatureDetail[] = [];
    const completedPhases = new Set(["completed", "archived", "summarized"]);

    for (const slug of allFeatureSlugs) {
      const featureSummary = coreProject.features[slug];
      if (!featureSummary) {
        continue;
      }

      try {
        const featureRecordPath = resolveRelativeProjectPath(projectRoot, featureSummary.path);
        const coreFeature = await readJsonFile<CoreFeatureRecord>(featureRecordPath);
        const featureStatus = await readFeatureStatus(projectRoot, projectStatus.features?.[slug]?.path);
        const handoffPending = (coreFeature.handoffs ?? []).some((handoff) => !handoff.accepted_at);
        const ownerRunner =
          (coreFeature.execution_owner?.runner ?? coreFeature.planning_owner?.runner ?? "none") as OwnerRunner;

        detailFeatures.push({
          slug,
          title: projectStatus.features?.[slug]?.title ?? featureSummary.title ?? coreFeature.title,
          workflowPhase: coreFeature.workflow?.current_phase ?? featureSummary.workflow_phase ?? null,
          nextRoute: coreFeature.workflow?.next_route ?? featureSummary.next_route ?? null,
          ownerRunner,
          ownerSessionId: coreFeature.execution_owner?.session_id ?? coreFeature.planning_owner?.session_id ?? null,
          worktreePath: coreFeature.worktree.worktree_path ?? null,
          bindingStatus: coreFeature.worktree.binding_status ?? null,
          handoffPending,
          progress: {
            completed: featureStatus?.completed ?? 0,
            total: featureStatus?.total ?? 0
          },
          docs: coreFeature.docs ?? {},
          tasks: (coreFeature.tasks ?? []).map((task) => ({
            id: task.id,
            title: task.title,
            status: task.status,
            phase: task.phase ?? null,
            parallel: task.parallel ?? false,
            dependsOn: task.depends_on ?? [],
            parallelGroup: task.parallel_group ?? null
          }))
        });
      } catch {
        // feature 记录文件缺失或损坏，跳过该 feature
        continue;
      }
    }

    // 找到第一个活跃的 feature（非 completed/archived/summarized）作为主显示 feature
    const activeFeatures = detailFeatures.filter(
      (f) => f.workflowPhase && !completedPhases.has(f.workflowPhase)
    );
    const primaryFeature = activeFeatures[0] ?? detailFeatures[0] ?? null;

    if (!primaryFeature) {
      const summary = buildProjectSummary({
        candidate,
        syncStatus: "healthy",
        currentFeatureSlug: null,
        currentFeatureTitle: null,
        lifecycleStage: null,
        ownerRunner: "none",
        worktreePath: null,
        handoffPending: false,
        progressCompleted: 0,
        progressTotal: 0,
        featureStatus: null,
        featureRecordPath: null,
        lastSeenAt: timestamp,
        lastSyncedAt: timestamp,
        workflowPhase: null,
        activeFeatureCount: 0
      });
      return {
        summary,
        detail: {
          project: summary,
          features: detailFeatures,
          activeSessions
        } satisfies ProjectDetail
      };
    }

    // 使用主 feature 填充 summary（向后兼容 currentFeatureSlug/currentFeatureTitle）
    const primarySlug = primaryFeature.slug;
    const primaryCoreSummary = coreProject.features[primarySlug];
    const primaryRecordPath = resolveRelativeProjectPath(projectRoot, primaryCoreSummary.path);

    const summary = buildProjectSummary({
      candidate,
      syncStatus: "healthy",
      currentFeatureSlug: primarySlug,
      currentFeatureTitle: primaryFeature.title,
      lifecycleStage: primaryCoreSummary.lifecycle as LifecycleStage,
      ownerRunner: primaryFeature.ownerRunner,
      worktreePath: primaryFeature.worktreePath ?? primaryCoreSummary.worktree_path ?? null,
      handoffPending: primaryFeature.handoffPending,
      progressCompleted: primaryFeature.progress.completed,
      progressTotal: primaryFeature.progress.total,
      featureStatus: projectStatus.features?.[primarySlug]?.status ?? null,
      featureRecordPath: path.relative(projectRoot, primaryRecordPath),
      lastSeenAt: timestamp,
      lastSyncedAt: timestamp,
      workflowPhase: primaryFeature.workflowPhase,
      activeFeatureCount: activeFeatures.length
    });

    return {
      summary,
      detail: {
        project: summary,
        features: detailFeatures,
        activeSessions
      } satisfies ProjectDetail
    };
  } catch {
    return {
      summary: buildProjectSummary({
        candidate,
        syncStatus: "error",
        currentFeatureSlug: null,
        currentFeatureTitle: null,
        lifecycleStage: null,
        ownerRunner: "none",
        worktreePath: null,
        handoffPending: false,
        progressCompleted: 0,
        progressTotal: 0,
        featureStatus: null,
        featureRecordPath: null,
        lastSeenAt: timestamp,
        lastSyncedAt: null,
        workflowPhase: null,
        activeFeatureCount: 0
      }),
      detail: null
    };
  }
}

async function buildCandidates(registry: DashboardRegistry, extraScanRoots: string[]) {
  const byRootPath = new Map<string, CandidateProject>();

  for (const project of Object.values(registry.projects)) {
    const normalizedRoot = normalizeRootPath(project.root_path);
    byRootPath.set(normalizedRoot, {
      id: project.id,
      rootPath: normalizedRoot,
      displayName: project.display_name,
      registrationSource: project.registration_source
    });
  }

  const ignoredRoots = new Set(registry.ignored_roots.map(normalizeRootPath));
  const scanRoots = Array.from(
    new Set([...registry.scan_roots, ...extraScanRoots].map(normalizeRootPath))
  );

  for (const root of scanRoots) {
    const discoveredRoots = await discoverProjectRoots(root, ignoredRoots);
    for (const discoveredRoot of discoveredRoots) {
      if (byRootPath.has(discoveredRoot)) {
        continue;
      }

      const existing = findProjectEntryByRootPath(registry, discoveredRoot);
      byRootPath.set(discoveredRoot, {
        id: existing?.id ?? ensureProjectId(registry, discoveredRoot),
        rootPath: discoveredRoot,
        displayName: existing?.display_name ?? path.basename(discoveredRoot),
        registrationSource: existing?.registration_source ?? "auto_scan"
      });
    }
  }

  return Array.from(byRootPath.values());
}

export async function collectProjects(options: CollectProjectsOptions) {
  const registry = await loadRegistry(options.registryPath);
  const extraScanRoots = options.scanRoots ?? [];
  mergeScanRoots(registry, extraScanRoots);

  const timestamp = nowIso();
  const candidates = await buildCandidates(registry, extraScanRoots);
  const detailsById = new Map<string, ProjectDetail>();
  const summaries: ProjectSummary[] = [];

  for (const candidate of candidates) {
    const { summary, detail } = await readProjectAggregation(candidate, timestamp);
    mergeSummaryIntoRegistry(registry, summary, timestamp);
    summaries.push(summary);
    if (detail) {
      detailsById.set(summary.id, detail);
    }
  }

  summaries.sort((left, right) => left.displayName.localeCompare(right.displayName, "zh-Hans-CN"));
  await saveRegistry(options.registryPath, registry);

  return {
    registry,
    projects: summaries,
    detailsById
  };
}

export async function getProjectDetail(registryPath: string, projectId: string) {
  const { detailsById } = await collectProjects({ registryPath });
  return detailsById.get(projectId) ?? null;
}

export async function registerProject(options: RegisterProjectOptions) {
  const registry = await loadRegistry(options.registryPath);
  upsertRegisteredProject(registry, {
    rootPath: options.rootPath,
    displayName: options.displayName,
    id: options.projectId,
    registrationSource: "manual"
  });
  await saveRegistry(options.registryPath, registry);

  const { projects } = await collectProjects({ registryPath: options.registryPath });
  return projects.find((project) => normalizeRootPath(project.rootPath) === normalizeRootPath(options.rootPath)) ?? null;
}

export async function scanProjects(options: ScanProjectsOptions) {
  const { projects } = await collectProjects({
    registryPath: options.registryPath,
    scanRoots: options.roots ?? []
  });

  return projects;
}
