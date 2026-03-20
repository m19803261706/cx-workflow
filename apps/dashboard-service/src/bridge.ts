import path from "node:path";
import { access } from "node:fs/promises";

import { findProjectEntryByRootPath, loadRegistry, saveRegistry, upsertRegisteredProject } from "./registry.ts";
import { inferRuntimePathFromRegistryPath, loadDashboardRuntime, resolveDashboardPaths } from "./runtime.ts";
import type { DashboardRegistry, PromptState } from "./types.ts";

export type DashboardBridgeDecision = "none" | "accept" | "decline";

export type DashboardBridgeResult = {
  promptState: PromptState;
  autoRegister: boolean;
  shouldPrompt: boolean;
  shouldAutoRegister: boolean;
  serviceStatus: "stopped" | "running" | "degraded";
  serviceRunning: boolean;
  frontendUrl: string | null;
  apiBaseUrl: string | null;
  registryPath: string;
  runtimePath: string;
  projectRoot: string | null;
  projectRegistered: boolean;
  projectId: string | null;
  registrationSource: "manual" | "auto_register" | "auto_scan" | null;
  decisionApplied: DashboardBridgeDecision;
};

type DashboardBridgeOptions = {
  registryPath?: string;
  runtimePath?: string;
  projectRoot?: string;
  displayName?: string;
  projectId?: string;
  decision?: DashboardBridgeDecision;
};

async function fileExists(filePath: string) {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function ensureRegistryFile(registryPath: string) {
  const existed = await fileExists(registryPath);
  const registry = await loadRegistry(registryPath);
  if (!existed) {
    await saveRegistry(registryPath, registry);
  }
  return registry;
}

async function probeDashboardHealth(apiBaseUrl: string | null, serviceStatus: string) {
  if (serviceStatus !== "running" || !apiBaseUrl) {
    return false;
  }

  try {
    const response = await fetch(`${apiBaseUrl}/health`, {
      signal: AbortSignal.timeout(800)
    });
    return response.ok;
  } catch {
    return false;
  }
}

function applyPromptDecision(registry: DashboardRegistry, decision: DashboardBridgeDecision) {
  if (decision === "accept") {
    const changed = registry.prompt_state !== "accepted" || !registry.auto_register;
    registry.prompt_state = "accepted";
    registry.auto_register = true;
    return changed;
  }

  if (decision === "decline") {
    const changed = registry.prompt_state !== "declined" || registry.auto_register;
    registry.prompt_state = "declined";
    registry.auto_register = false;
    return changed;
  }

  return false;
}

export async function runDashboardBridge(
  options: DashboardBridgeOptions = {}
): Promise<DashboardBridgeResult> {
  const defaults = resolveDashboardPaths();
  const registryPath = path.resolve(options.registryPath ?? defaults.registryPath);
  const runtimePath = path.resolve(options.runtimePath ?? inferRuntimePathFromRegistryPath(registryPath));
  const projectRoot = options.projectRoot ? path.resolve(options.projectRoot) : null;
  const decision = options.decision ?? "none";

  const registry = await ensureRegistryFile(registryPath);
  let changed = applyPromptDecision(registry, decision);

  const shouldAutoRegister = registry.prompt_state === "accepted" && registry.auto_register;
  let projectEntry = projectRoot ? findProjectEntryByRootPath(registry, projectRoot) ?? null : null;

  if (projectRoot && shouldAutoRegister && !projectEntry) {
    projectEntry = upsertRegisteredProject(registry, {
      rootPath: projectRoot,
      displayName: options.displayName,
      id: options.projectId,
      registrationSource: "auto_register"
    });
    changed = true;
  }

  if (changed) {
    await saveRegistry(registryPath, registry);
  }

  const runtime = await loadDashboardRuntime(runtimePath, registryPath);
  const serviceRunning = await probeDashboardHealth(runtime.api_base_url, runtime.service_status);

  return {
    promptState: registry.prompt_state,
    autoRegister: registry.auto_register,
    shouldPrompt: registry.prompt_state === "unknown",
    shouldAutoRegister,
    serviceStatus: runtime.service_status,
    serviceRunning,
    frontendUrl: runtime.frontend_url,
    apiBaseUrl: runtime.api_base_url,
    registryPath,
    runtimePath,
    projectRoot,
    projectRegistered: Boolean(projectEntry),
    projectId: projectEntry?.id ?? null,
    registrationSource: projectEntry?.registration_source ?? null,
    decisionApplied: decision
  };
}

function parseArgs(argv: string[]) {
  const options = new Map<string, string>();

  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key.startsWith("--")) {
      continue;
    }

    const value = argv[index + 1];
    if (value && !value.startsWith("--")) {
      options.set(key, value);
      index += 1;
    } else {
      options.set(key, "true");
    }
  }

  return options;
}

async function runCli() {
  const options = parseArgs(process.argv.slice(2));
  const result = await runDashboardBridge({
    registryPath: options.get("--registry-path"),
    runtimePath: options.get("--runtime-path"),
    projectRoot: options.get("--project-root"),
    displayName: options.get("--display-name"),
    projectId: options.get("--project-id"),
    decision: (options.get("--decision") as DashboardBridgeDecision | undefined) ?? "none"
  });

  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  runCli().catch((error) => {
    process.stderr.write(`${String(error)}\n`);
    process.exit(1);
  });
}
