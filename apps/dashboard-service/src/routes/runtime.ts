import type { FastifyInstance } from "fastify";

import { loadRegistry } from "../registry.ts";
import { loadDashboardRuntime } from "../runtime.ts";

export async function registerRuntimeRoutes(
  server: FastifyInstance,
  registryPath: string,
  runtimePath: string
) {
  server.get("/api/dashboard/runtime/prompt-state", async () => {
    const [registry, runtime] = await Promise.all([
      loadRegistry(registryPath),
      loadDashboardRuntime(runtimePath, registryPath)
    ]);

    return {
      promptState: registry.prompt_state,
      autoRegister: registry.auto_register,
      shouldPrompt: registry.prompt_state === "unknown",
      serviceStatus: runtime.service_status,
      serviceRunning: runtime.service_status === "running",
      frontendUrl: runtime.frontend_url,
      apiBaseUrl: runtime.api_base_url,
      registryPath: runtime.registry_path
    };
  });
}
