import test from "node:test";
import assert from "node:assert/strict";
import os from "node:os";
import path from "node:path";
import net from "node:net";
import { mkdtemp, readFile } from "node:fs/promises";

import { ensureDashboardRuntime, inferRuntimePathFromRegistryPath, loadDashboardRuntime } from "./runtime.ts";
import { buildServer } from "./server.ts";

function occupyPort(port: number, host: string) {
  return new Promise<net.Server>((resolve, reject) => {
    const server = net.createServer();
    server.once("error", reject);
    server.listen(port, host, () => resolve(server));
  });
}

test("ensureDashboardRuntime chooses the next available backend and frontend ports and persists runtime manifest", async () => {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "cx-dashboard-runtime-"));
  const registryPath = path.join(tempRoot, "dashboard/registry.json");
  const runtimePath = inferRuntimePathFromRegistryPath(registryPath);
  const host = "127.0.0.1";
  const occupiedBackend = await occupyPort(43120, host);
  const occupiedFrontend = await occupyPort(43130, host);

  try {
    const runtime = await ensureDashboardRuntime({
      registryPath,
      runtimePath,
      serviceHost: host,
      backendBasePort: 43120,
      frontendBasePort: 43130,
      now: "2026-03-20T08:30:00Z"
    });

    assert.equal(runtime.service_status, "running");
    assert.equal(runtime.backend_port, 43121);
    assert.equal(runtime.frontend_port, 43131);
    assert.equal(runtime.api_base_url, "http://127.0.0.1:43121/api/dashboard");
    assert.equal(runtime.frontend_url, "http://127.0.0.1:43131");
    assert.equal(runtime.last_started_at, "2026-03-20T08:30:00Z");

    const savedRuntime = JSON.parse(await readFile(runtimePath, "utf8"));
    assert.equal(savedRuntime.backend_port, 43121);
    assert.equal(savedRuntime.frontend_port, 43131);
    assert.equal(savedRuntime.registry_path, registryPath);
  } finally {
    occupiedBackend.close();
    occupiedFrontend.close();
  }
});

test("loadDashboardRuntime returns a stopped default manifest when runtime file does not exist", async () => {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "cx-dashboard-runtime-default-"));
  const registryPath = path.join(tempRoot, "dashboard/registry.json");
  const runtime = await loadDashboardRuntime(inferRuntimePathFromRegistryPath(registryPath), registryPath);

  assert.equal(runtime.service_status, "stopped");
  assert.equal(runtime.backend_port, null);
  assert.equal(runtime.frontend_port, null);
  assert.equal(runtime.registry_path, registryPath);
});

test("GET /api/dashboard/health maps runtime manifest fields into dashboard health payload", async () => {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "cx-dashboard-health-"));
  const registryPath = path.join(tempRoot, "dashboard/registry.json");
  const runtimePath = inferRuntimePathFromRegistryPath(registryPath);

  await ensureDashboardRuntime({
    registryPath,
    runtimePath,
    now: "2026-03-20T08:45:00Z"
  });

  const server = buildServer({ registryPath, runtimePath });
  const response = await server.inject({
    method: "GET",
    url: "/api/dashboard/health"
  });

  assert.equal(response.statusCode, 200);
  const payload = response.json();
  assert.equal(payload.serviceStatus, "running");
  assert.equal(payload.backendPort, 43120);
  assert.equal(payload.frontendPort, 43130);
  assert.equal(payload.registryPath, registryPath);
  assert.equal(payload.lastStartedAt, "2026-03-20T08:45:00Z");

  await server.close();
});
