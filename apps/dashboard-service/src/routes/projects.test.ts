import test from "node:test";
import assert from "node:assert/strict";
import os from "node:os";
import path from "node:path";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";

import { buildServer } from "../server.ts";

const fixtureRoot = path.resolve(process.cwd(), "../../tests/fixtures/dashboard-projects");

async function readFixture<T>(name: string) {
  return JSON.parse(await readFile(path.join(fixtureRoot, name), "utf8")) as T;
}

type SampleProjectOptions = {
  root: string;
  title: string;
  slug: string;
  ownerRunner?: "cc" | "codex";
  worktreePath?: string;
  handoffPending?: boolean;
  completed?: number;
  total?: number;
};

async function writeJson(filePath: string, value: unknown) {
  await mkdir(path.dirname(filePath), { recursive: true });
  await writeFile(filePath, JSON.stringify(value, null, 2));
}

async function createSampleProject(options: SampleProjectOptions) {
  const completed = options.completed ?? 1;
  const total = options.total ?? 3;
  const projectStatusPath = path.join(options.root, ".claude/cx/状态.json");
  const coreProjectPath = path.join(options.root, ".claude/cx/core/projects/project.json");
  const coreFeaturePath = path.join(options.root, `.claude/cx/core/features/${options.slug}.json`);
  const featureStatusPath = path.join(options.root, `.claude/cx/功能/${options.title}/状态.json`);

  await writeJson(projectStatusPath, {
    initialized_at: "2026-03-20T08:00:00Z",
    last_updated: "2026-03-20T08:00:00Z",
    current_feature: options.slug,
    features: {
      [options.slug]: {
        title: options.title,
        path: `功能/${options.title}`,
        status: "executing",
        last_updated: "2026-03-20T08:00:00Z"
      }
    },
    fixes: {}
  });

  await writeJson(coreProjectPath, {
    version: "1.0",
    current_feature: options.slug,
    features: {
      [options.slug]: {
        slug: options.slug,
        title: options.title,
        path: `.claude/cx/core/features/${options.slug}.json`,
        lifecycle: "executing",
        worktree_path: options.worktreePath ?? `/worktrees/${options.slug}`,
        lease_session_id: `${options.ownerRunner ?? "codex"}-session-1`,
        workflow_phase: "exec",
        next_route: "cx-exec",
        last_updated: "2026-03-20T08:00:00Z"
      }
    },
    active_sessions: {
      [`${options.ownerRunner ?? "codex"}-session-1`]: {
        runner: options.ownerRunner ?? "codex",
        session_id: `${options.ownerRunner ?? "codex"}-session-1`,
        branch: `codex/${options.slug}`,
        worktree_path: options.worktreePath ?? `/worktrees/${options.slug}`,
        started_at: "2026-03-20T08:00:00Z",
        last_heartbeat: "2026-03-20T08:00:00Z",
        claimed_feature: options.slug,
        claimed_tasks: [2]
      }
    },
    runtime_roots: {
      projects: ".claude/cx/core/projects",
      features: ".claude/cx/core/features",
      sessions: ".claude/cx/core/sessions",
      handoffs: ".claude/cx/core/handoffs",
      worktrees: ".claude/cx/core/worktrees",
      artifacts: {
        cx: ".claude/cx/runtime/cx",
        cc: ".claude/cx/runtime/cc",
        codex: ".claude/cx/runtime/codex"
      }
    }
  });

  await writeJson(coreFeaturePath, {
    slug: options.slug,
    title: options.title,
    lifecycle: {
      stage: "executing",
      updated_at: "2026-03-20T08:00:00Z"
    },
    planning_owner: {
      runner: options.ownerRunner ?? "codex",
      session_id: `${options.ownerRunner ?? "codex"}-session-1`
    },
    execution_owner: {
      runner: options.ownerRunner ?? "codex",
      session_id: `${options.ownerRunner ?? "codex"}-session-1`
    },
    worktree: {
      branch: `codex/${options.slug}`,
      worktree_path: options.worktreePath ?? `/worktrees/${options.slug}`,
      binding_status: "bound",
      bound_at: "2026-03-20T08:00:00Z"
    },
    lease: {
      runner: options.ownerRunner ?? "codex",
      session_id: `${options.ownerRunner ?? "codex"}-session-1`,
      branch: `codex/${options.slug}`,
      worktree_path: options.worktreePath ?? `/worktrees/${options.slug}`,
      claimed_feature: options.slug,
      claimed_tasks: [2],
      claimed_at: "2026-03-20T08:00:00Z",
      last_heartbeat: "2026-03-20T08:00:00Z",
      expires_at: "2026-03-20T10:00:00Z"
    },
    docs: {
      prd: `.claude/cx/功能/${options.title}/需求.md`
    },
    workflow: {
      protocol_version: "1.0",
      current_phase: "exec",
      completion_status: "ready",
      question_mode: "conversation",
      size: "L",
      needs_design: true,
      needs_adr: false,
      next_route: "cx-exec",
      decision_basis: "执行中",
      last_transition_at: "2026-03-20T08:00:00Z"
    },
    tasks: [
      {
        id: 1,
        title: "任务一",
        phase: 1,
        parallel: false,
        depends_on: [],
        status: "completed",
        owner_session_id: `${options.ownerRunner ?? "codex"}-session-1`,
        path: `.claude/cx/功能/${options.title}/任务/任务-1.md`
      },
      {
        id: 2,
        title: "任务二",
        phase: 1,
        parallel: false,
        depends_on: [1],
        status: "in_progress",
        owner_session_id: `${options.ownerRunner ?? "codex"}-session-1`,
        path: `.claude/cx/功能/${options.title}/任务/任务-2.md`
      }
    ],
    handoffs: options.handoffPending
      ? [
          {
            runner: options.ownerRunner ?? "codex",
            session_id: `${options.ownerRunner ?? "codex"}-session-1`,
            branch: `codex/${options.slug}`,
            worktree_path: options.worktreePath ?? `/worktrees/${options.slug}`,
            claimed_feature: options.slug,
            claimed_tasks: [2],
            handoff_reason: "等待另一端接手",
            created_at: "2026-03-20T08:00:00Z",
            accepted_at: null,
            target_runner: "cc"
          }
        ]
      : []
  });

  await writeJson(featureStatusPath, {
    feature: options.title,
    slug: options.slug,
    created_at: "2026-03-20T08:00:00Z",
    last_updated: "2026-03-20T08:00:00Z",
    status: "executing",
    total,
    completed,
    in_progress: 1,
    phases: [
      {
        number: 1,
        name: "阶段一",
        status: "in_progress",
        tasks: [1, 2]
      }
    ],
    tasks: [
      {
        number: 1,
        title: "任务一",
        phase: 1,
        parallel: false,
        depends_on: [],
        status: "completed"
      },
      {
        number: 2,
        title: "任务二",
        phase: 1,
        parallel: false,
        depends_on: [1],
        status: "in_progress"
      }
    ],
    execution_order: [1, 2],
    docs: {
      prd: `.claude/cx/功能/${options.title}/需求.md`
    },
    workflow: {
      protocol_version: "1.0",
      current_phase: "exec",
      completion_status: "ready",
      question_mode: "conversation",
      size: "L",
      needs_design: true,
      needs_adr: false,
      next_route: "cx-exec",
      decision_basis: "执行中",
      last_transition_at: "2026-03-20T08:00:00Z"
    }
  });
}

async function createRegistry(registryPath: string, projectRoot: string, displayName: string) {
  await writeJson(registryPath, {
    version: "1.0",
    prompt_state: "accepted",
    auto_register: true,
    projects: {
      "manual-project": {
        id: "manual-project",
        root_path: projectRoot,
        display_name: displayName,
        registration_source: "manual",
        sync_status: "healthy",
        owner_runner: "none",
        handoff_pending: false,
        progress_completed: 0,
        progress_total: 0,
        last_seen_at: "2026-03-20T08:00:00Z",
        last_synced_at: null,
        current_feature_slug: null,
        current_feature_title: null,
        lifecycle_stage: null,
        worktree_path: null,
        feature_status: null,
        feature_record_path: null
      }
    },
    scan_roots: [
      path.dirname(projectRoot)
    ],
    ignored_roots: [],
    updated_at: "2026-03-20T08:00:00Z"
  });
}

test("GET /api/dashboard/projects merges manual registry with auto-scanned shared core projects", async () => {
  const expectations = await readFixture<{
    manual: {
      id: string;
      registrationSource: string;
      currentFeatureSlug: string;
      progressCompleted: number;
      progressTotal: number;
    };
    scanned: {
      currentFeatureSlug: string;
      registrationSource: string;
      ownerRunner: string;
      handoffPending: boolean;
    };
  }>("summary-expectations.json");
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "cx-dashboard-projects-"));
  const registryPath = path.join(tempRoot, "dashboard/registry.json");
  const manualProjectRoot = path.join(tempRoot, "workspace/manual-project");
  const scannedProjectRoot = path.join(tempRoot, "workspace/scanned-project");

  await createSampleProject({
    root: manualProjectRoot,
    title: "手动项目功能",
    slug: "manual-feature",
    ownerRunner: "codex",
    completed: 2,
    total: 5
  });
  await createSampleProject({
    root: scannedProjectRoot,
    title: "扫描项目功能",
    slug: "scanned-feature",
    ownerRunner: "cc",
    handoffPending: true,
    completed: 1,
    total: 4
  });
  await createRegistry(registryPath, manualProjectRoot, "手动项目");

  const server = buildServer({ registryPath });
  const response = await server.inject({
    method: "GET",
    url: "/api/dashboard/projects"
  });

  assert.equal(response.statusCode, 200);
  const payload = response.json();
  assert.equal(payload.projects.length, 2);

  const manualProject = payload.projects.find((item: { id: string }) => item.id === expectations.manual.id);
  assert.ok(manualProject);
  assert.equal(manualProject.registrationSource, expectations.manual.registrationSource);
  assert.equal(manualProject.currentFeatureSlug, expectations.manual.currentFeatureSlug);
  assert.equal(manualProject.progressCompleted, expectations.manual.progressCompleted);
  assert.equal(manualProject.progressTotal, expectations.manual.progressTotal);

  const scannedProject = payload.projects.find(
    (item: { currentFeatureSlug: string }) =>
      item.currentFeatureSlug === expectations.scanned.currentFeatureSlug
  );
  assert.ok(scannedProject);
  assert.equal(scannedProject.registrationSource, expectations.scanned.registrationSource);
  assert.equal(scannedProject.ownerRunner, expectations.scanned.ownerRunner);
  assert.equal(scannedProject.handoffPending, expectations.scanned.handoffPending);

  await server.close();
});

test("GET /api/dashboard/projects/:projectId returns aggregated feature detail", async () => {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "cx-dashboard-project-detail-"));
  const registryPath = path.join(tempRoot, "dashboard/registry.json");
  const projectRoot = path.join(tempRoot, "workspace/manual-project");

  await createSampleProject({
    root: projectRoot,
    title: "详情项目功能",
    slug: "detail-feature",
    ownerRunner: "codex",
    handoffPending: true,
    completed: 3,
    total: 6
  });
  await createRegistry(registryPath, projectRoot, "详情项目");

  const server = buildServer({ registryPath });
  const response = await server.inject({
    method: "GET",
    url: "/api/dashboard/projects/manual-project"
  });

  assert.equal(response.statusCode, 200);
  const payload = response.json();
  assert.equal(payload.project.id, "manual-project");
  assert.equal(payload.project.currentFeatureSlug, "detail-feature");
  assert.equal(payload.project.handoffPending, true);
  assert.equal(payload.feature.slug, "detail-feature");
  assert.equal(payload.feature.ownerRunner, "codex");
  assert.equal(payload.feature.progress.completed, 3);
  assert.equal(payload.feature.progress.total, 6);

  await server.close();
});

test("POST /api/dashboard/projects/register persists a manual project registration", async () => {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "cx-dashboard-register-"));
  const registryPath = path.join(tempRoot, "dashboard/registry.json");
  const projectRoot = path.join(tempRoot, "workspace/new-project");

  await createSampleProject({
    root: projectRoot,
    title: "注册项目功能",
    slug: "register-feature",
    ownerRunner: "codex"
  });

  const server = buildServer({ registryPath });
  const response = await server.inject({
    method: "POST",
    url: "/api/dashboard/projects/register",
    payload: {
      rootPath: projectRoot,
      displayName: "注册项目"
    }
  });

  assert.equal(response.statusCode, 201);
  const payload = response.json();
  assert.equal(payload.project.registrationSource, "manual");
  assert.equal(payload.project.currentFeatureSlug, "register-feature");

  const registry = JSON.parse(await readFile(registryPath, "utf8"));
  assert.equal(Object.keys(registry.projects).length, 1);
  assert.equal(registry.projects[payload.project.id].display_name, "注册项目");

  await server.close();
});

test("POST /api/dashboard/projects/scan discovers shared core projects and persists scan roots", async () => {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "cx-dashboard-scan-"));
  const registryPath = path.join(tempRoot, "dashboard/registry.json");
  const scanRoot = path.join(tempRoot, "workspace");
  const scannedProjectRoot = path.join(scanRoot, "scanned-project");

  await createSampleProject({
    root: scannedProjectRoot,
    title: "扫描注册项目",
    slug: "scan-feature",
    ownerRunner: "cc"
  });

  const server = buildServer({ registryPath });
  const response = await server.inject({
    method: "POST",
    url: "/api/dashboard/projects/scan",
    payload: {
      roots: [scanRoot]
    }
  });

  assert.equal(response.statusCode, 200);
  const payload = response.json();
  assert.equal(payload.projects.length, 1);
  assert.equal(payload.projects[0].registrationSource, "auto_scan");
  assert.equal(payload.projects[0].currentFeatureSlug, "scan-feature");

  const registry = JSON.parse(await readFile(registryPath, "utf8"));
  assert.deepEqual(registry.scan_roots, [scanRoot]);
  assert.equal(Object.keys(registry.projects).length, 1);

  await server.close();
});
