import path from "node:path";
import { access, mkdir, readFile, writeFile } from "node:fs/promises";

import type { DashboardRegistry, DashboardRegistryProject, ProjectSummary, RegistrationSource } from "./types.ts";

function nowIso() {
  return new Date().toISOString();
}

async function fileExists(filePath: string) {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
}

export function createDefaultRegistry(now = nowIso()): DashboardRegistry {
  return {
    version: "1.0",
    prompt_state: "unknown",
    auto_register: false,
    projects: {},
    scan_roots: [],
    ignored_roots: [],
    updated_at: now
  };
}

export async function loadRegistry(registryPath: string): Promise<DashboardRegistry> {
  if (!(await fileExists(registryPath))) {
    return createDefaultRegistry();
  }

  const content = await readFile(registryPath, "utf8");
  return JSON.parse(content) as DashboardRegistry;
}

export async function saveRegistry(registryPath: string, registry: DashboardRegistry) {
  await mkdir(path.dirname(registryPath), { recursive: true });
  await writeFile(registryPath, `${JSON.stringify(registry, null, 2)}\n`);
}

export function normalizeRootPath(rootPath: string) {
  return path.resolve(rootPath);
}

function sanitizeProjectId(value: string) {
  const normalized = value
    .toLowerCase()
    .replace(/[^a-z0-9._:-]+/g, "-")
    .replace(/^-+/, "")
    .replace(/-+$/, "");

  return normalized || "project";
}

export function findProjectEntryByRootPath(registry: DashboardRegistry, rootPath: string) {
  const normalizedRoot = normalizeRootPath(rootPath);

  return Object.values(registry.projects).find(
    (project) => normalizeRootPath(project.root_path) === normalizedRoot
  );
}

export function ensureProjectId(registry: DashboardRegistry, rootPath: string, requestedId?: string) {
  const existing = findProjectEntryByRootPath(registry, rootPath);
  if (existing) {
    return existing.id;
  }

  const preferred = sanitizeProjectId(requestedId ?? path.basename(rootPath));
  if (!registry.projects[preferred]) {
    return preferred;
  }

  let suffix = 2;
  while (registry.projects[`${preferred}-${suffix}`]) {
    suffix += 1;
  }

  return `${preferred}-${suffix}`;
}

export function upsertRegisteredProject(
  registry: DashboardRegistry,
  params: {
    rootPath: string;
    displayName?: string;
    id?: string;
    registrationSource: RegistrationSource;
    now?: string;
  }
) {
  const now = params.now ?? nowIso();
  const rootPath = normalizeRootPath(params.rootPath);
  const existing = findProjectEntryByRootPath(registry, rootPath);
  const projectId = existing?.id ?? ensureProjectId(registry, rootPath, params.id);

  const baseRecord: DashboardRegistryProject =
    existing ?? {
      id: projectId,
      root_path: rootPath,
      display_name: params.displayName ?? path.basename(rootPath),
      registration_source: params.registrationSource,
      sync_status: "missing",
      current_feature_slug: null,
      current_feature_title: null,
      lifecycle_stage: null,
      owner_runner: "none",
      worktree_path: null,
      handoff_pending: false,
      progress_completed: 0,
      progress_total: 0,
      feature_status: null,
      feature_record_path: null,
      last_seen_at: now,
      last_synced_at: null
    };

  const nextRecord: DashboardRegistryProject = {
    ...baseRecord,
    id: projectId,
    root_path: rootPath,
    display_name: params.displayName ?? baseRecord.display_name,
    registration_source:
      baseRecord.registration_source === "manual" ? "manual" : params.registrationSource,
    last_seen_at: now
  };

  registry.projects[projectId] = nextRecord;
  registry.updated_at = now;
  return nextRecord;
}

export function mergeSummaryIntoRegistry(
  registry: DashboardRegistry,
  summary: ProjectSummary,
  now = nowIso()
) {
  const existing = registry.projects[summary.id];

  registry.projects[summary.id] = {
    id: summary.id,
    root_path: summary.rootPath,
    display_name: summary.displayName,
    registration_source: existing?.registration_source ?? summary.registrationSource,
    sync_status: summary.syncStatus,
    current_feature_slug: summary.currentFeatureSlug,
    current_feature_title: summary.currentFeatureTitle,
    lifecycle_stage: summary.lifecycleStage,
    owner_runner: summary.ownerRunner,
    worktree_path: summary.worktreePath,
    handoff_pending: summary.handoffPending,
    progress_completed: summary.progressCompleted,
    progress_total: summary.progressTotal,
    feature_status: summary.featureStatus,
    feature_record_path: summary.featureRecordPath,
    last_seen_at: summary.lastSeenAt,
    last_synced_at: summary.lastSyncedAt
  };

  registry.updated_at = now;
}

export function mergeScanRoots(registry: DashboardRegistry, roots: string[]) {
  const merged = new Set(registry.scan_roots.map(normalizeRootPath));
  for (const root of roots) {
    merged.add(normalizeRootPath(root));
  }
  registry.scan_roots = Array.from(merged).sort();
}
