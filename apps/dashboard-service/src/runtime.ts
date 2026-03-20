import net from "node:net";
import os from "node:os";
import path from "node:path";
import { access, mkdir, readFile, writeFile } from "node:fs/promises";

export type DashboardRuntimeManifest = {
  version: "1.0";
  service_status: "stopped" | "running" | "degraded";
  service_host: string;
  backend_port: number | null;
  frontend_port: number | null;
  api_base_url: string | null;
  frontend_url: string | null;
  registry_path: string;
  pid: number | null;
  last_started_at: string | null;
  last_checked_at: string;
  last_error: string | null;
};

type EnsureDashboardRuntimeOptions = {
  registryPath: string;
  runtimePath?: string;
  serviceHost?: string;
  backendBasePort?: number;
  frontendBasePort?: number;
  now?: string;
};

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

export function inferRuntimePathFromRegistryPath(registryPath: string) {
  return path.join(path.dirname(registryPath), "runtime.json");
}

export function resolveDashboardPaths(homeDirectory = os.homedir()) {
  const baseDir = path.join(homeDirectory, ".cx", "dashboard");
  return {
    baseDir,
    registryPath: path.join(baseDir, "registry.json"),
    runtimePath: path.join(baseDir, "runtime.json")
  };
}

export function createDefaultRuntime(registryPath: string, now = nowIso()): DashboardRuntimeManifest {
  return {
    version: "1.0",
    service_status: "stopped",
    service_host: "127.0.0.1",
    backend_port: null,
    frontend_port: null,
    api_base_url: null,
    frontend_url: null,
    registry_path: registryPath,
    pid: null,
    last_started_at: null,
    last_checked_at: now,
    last_error: null
  };
}

export async function loadDashboardRuntime(runtimePath: string, registryPath: string) {
  if (!(await fileExists(runtimePath))) {
    return createDefaultRuntime(registryPath);
  }

  return JSON.parse(await readFile(runtimePath, "utf8")) as DashboardRuntimeManifest;
}

export async function saveDashboardRuntime(runtimePath: string, runtime: DashboardRuntimeManifest) {
  await mkdir(path.dirname(runtimePath), { recursive: true });
  await writeFile(runtimePath, `${JSON.stringify(runtime, null, 2)}\n`);
}

export async function findAvailablePort(startPort: number, host: string) {
  let port = startPort;

  for (;;) {
    const available = await new Promise<boolean>((resolve) => {
      const server = net.createServer();
      server.unref();
      server.once("error", () => resolve(false));
      server.listen(port, host, () => {
        server.close(() => resolve(true));
      });
    });

    if (available) {
      return port;
    }

    port += 1;
  }
}

export async function ensureDashboardRuntime(options: EnsureDashboardRuntimeOptions) {
  const timestamp = options.now ?? nowIso();
  const registryPath = path.resolve(options.registryPath);
  const runtimePath = path.resolve(options.runtimePath ?? inferRuntimePathFromRegistryPath(registryPath));
  const serviceHost = options.serviceHost ?? "127.0.0.1";
  const backendBasePort = options.backendBasePort ?? 43120;
  const frontendBasePort = options.frontendBasePort ?? 43130;
  const backendPort = await findAvailablePort(backendBasePort, serviceHost);
  const frontendPort = await findAvailablePort(frontendBasePort, serviceHost);

  const runtime: DashboardRuntimeManifest = {
    version: "1.0",
    service_status: "running",
    service_host: serviceHost,
    backend_port: backendPort,
    frontend_port: frontendPort,
    api_base_url: `http://${serviceHost}:${backendPort}/api/dashboard`,
    frontend_url: `http://${serviceHost}:${frontendPort}`,
    registry_path: registryPath,
    pid: process.pid,
    last_started_at: timestamp,
    last_checked_at: timestamp,
    last_error: null
  };

  await saveDashboardRuntime(runtimePath, runtime);
  return runtime;
}

export function buildDashboardHealth(runtime: DashboardRuntimeManifest) {
  return {
    serviceStatus: runtime.service_status,
    serviceHost: runtime.service_host,
    backendPort: runtime.backend_port,
    frontendPort: runtime.frontend_port,
    apiBaseUrl: runtime.api_base_url,
    frontendUrl: runtime.frontend_url,
    registryPath: runtime.registry_path,
    pid: runtime.pid,
    lastStartedAt: runtime.last_started_at,
    lastCheckedAt: runtime.last_checked_at,
    lastError: runtime.last_error
  };
}

function parseArgs(argv: string[]) {
  const [command = "read", ...rest] = argv;
  const options = new Map<string, string>();

  for (let index = 0; index < rest.length; index += 1) {
    const key = rest[index];
    if (!key.startsWith("--")) {
      continue;
    }

    const value = rest[index + 1];
    if (value && !value.startsWith("--")) {
      options.set(key, value);
      index += 1;
    } else {
      options.set(key, "true");
    }
  }

  return { command, options };
}

async function runCli() {
  const { command, options } = parseArgs(process.argv.slice(2));
  const registryPath =
    options.get("--registry-path") ?? resolveDashboardPaths().registryPath;
  const runtimePath =
    options.get("--runtime-path") ?? inferRuntimePathFromRegistryPath(registryPath);

  if (command === "ensure") {
    const runtime = await ensureDashboardRuntime({
      registryPath,
      runtimePath,
      serviceHost: options.get("--service-host") ?? "127.0.0.1",
      backendBasePort: Number(options.get("--backend-base-port") ?? "43120"),
      frontendBasePort: Number(options.get("--frontend-base-port") ?? "43130")
    });
    process.stdout.write(`${JSON.stringify(runtime, null, 2)}\n`);
    return;
  }

  const runtime = await loadDashboardRuntime(runtimePath, registryPath);
  process.stdout.write(`${JSON.stringify(runtime, null, 2)}\n`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  runCli().catch((error) => {
    process.stderr.write(`${String(error)}\n`);
    process.exit(1);
  });
}
