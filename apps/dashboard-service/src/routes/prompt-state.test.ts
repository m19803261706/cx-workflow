import test from "node:test";
import assert from "node:assert/strict";
import os from "node:os";
import path from "node:path";
import { mkdtemp, mkdir, writeFile } from "node:fs/promises";

import { buildServer } from "../server.ts";

async function writeJson(filePath: string, value: unknown) {
  await mkdir(path.dirname(filePath), { recursive: true });
  await writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

test("GET /api/dashboard/runtime/prompt-state returns prompt state and auto-register settings", async () => {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "cx-dashboard-prompt-state-"));
  const registryPath = path.join(tempRoot, "dashboard/registry.json");
  const runtimePath = path.join(tempRoot, "dashboard/runtime.json");

  await writeJson(registryPath, {
    version: "1.0",
    prompt_state: "accepted",
    auto_register: true,
    projects: {},
    scan_roots: [],
    ignored_roots: [],
    updated_at: "2026-03-20T09:30:00Z"
  });

  await writeJson(runtimePath, {
    version: "1.0",
    service_status: "running",
    service_host: "127.0.0.1",
    backend_port: 43120,
    frontend_port: 43130,
    api_base_url: "http://127.0.0.1:43120/api/dashboard",
    frontend_url: "http://127.0.0.1:43130",
    registry_path: registryPath,
    pid: 12345,
    last_started_at: "2026-03-20T09:30:00Z",
    last_checked_at: "2026-03-20T09:30:00Z",
    last_error: null
  });

  const server = buildServer({ registryPath, runtimePath });
  const response = await server.inject({
    method: "GET",
    url: "/api/dashboard/runtime/prompt-state"
  });

  assert.equal(response.statusCode, 200);
  const payload = response.json();
  assert.equal(payload.promptState, "accepted");
  assert.equal(payload.autoRegister, true);
  assert.equal(payload.serviceRunning, true);
  assert.equal(payload.frontendUrl, "http://127.0.0.1:43130");

  await server.close();
});
