import test from "node:test";
import assert from "node:assert/strict";
import os from "node:os";
import path from "node:path";
import { mkdtemp, mkdir, readFile } from "node:fs/promises";

import { runDashboardBridge } from "./bridge.ts";

test("dashboard bridge bootstraps default prompt state without blocking project flow", async () => {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "cx-dashboard-bridge-"));
  const registryPath = path.join(tempRoot, "dashboard/registry.json");
  const runtimePath = path.join(tempRoot, "dashboard/runtime.json");
  const projectRoot = path.join(tempRoot, "projects/demo");

  await mkdir(projectRoot, { recursive: true });

  const result = await runDashboardBridge({
    registryPath,
    runtimePath,
    projectRoot,
    displayName: "示例项目"
  });

  assert.equal(result.promptState, "unknown");
  assert.equal(result.autoRegister, false);
  assert.equal(result.shouldPrompt, true);
  assert.equal(result.projectRegistered, false);

  const savedRegistry = JSON.parse(await readFile(registryPath, "utf8"));
  assert.equal(savedRegistry.prompt_state, "unknown");
  assert.equal(savedRegistry.auto_register, false);
});

test("dashboard bridge accepts dashboard mode and auto-registers the current project", async () => {
  const tempRoot = await mkdtemp(path.join(os.tmpdir(), "cx-dashboard-bridge-"));
  const registryPath = path.join(tempRoot, "dashboard/registry.json");
  const runtimePath = path.join(tempRoot, "dashboard/runtime.json");
  const projectRoot = path.join(tempRoot, "projects/demo");

  await mkdir(projectRoot, { recursive: true });

  const accepted = await runDashboardBridge({
    registryPath,
    runtimePath,
    projectRoot,
    displayName: "示例项目",
    decision: "accept"
  });

  assert.equal(accepted.promptState, "accepted");
  assert.equal(accepted.autoRegister, true);
  assert.equal(accepted.projectRegistered, true);
  assert.equal(accepted.registrationSource, "auto_register");

  const followUp = await runDashboardBridge({
    registryPath,
    runtimePath,
    projectRoot,
    displayName: "示例项目"
  });

  assert.equal(followUp.shouldPrompt, false);
  assert.equal(followUp.projectRegistered, true);
  assert.equal(followUp.projectId, accepted.projectId);
});
