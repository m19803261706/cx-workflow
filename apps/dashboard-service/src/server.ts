import Fastify from "fastify";

import { registerProjectRoutes } from "./routes/projects.ts";
import { registerRuntimeRoutes } from "./routes/runtime.ts";
import { buildDashboardHealth, inferRuntimePathFromRegistryPath, loadDashboardRuntime } from "./runtime.ts";

export type DashboardServerOptions = {
  registryPath: string;
  runtimePath?: string;
};

export function buildServer(options: DashboardServerOptions) {
  const server = Fastify({
    logger: false
  });

  server.addHook("onSend", async (_request, reply, payload) => {
    reply.header("Access-Control-Allow-Origin", "*");
    reply.header("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
    reply.header("Access-Control-Allow-Headers", "Content-Type");
    return payload;
  });

  server.get("/api/dashboard/health", async () => {
    const runtime = await loadDashboardRuntime(
      options.runtimePath ?? inferRuntimePathFromRegistryPath(options.registryPath),
      options.registryPath
    );
    return buildDashboardHealth(runtime);
  });

  void registerRuntimeRoutes(
    server,
    options.registryPath,
    options.runtimePath ?? inferRuntimePathFromRegistryPath(options.registryPath)
  );
  void registerProjectRoutes(server, options.registryPath);
  return server;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const registryPath = process.env.CX_DASHBOARD_REGISTRY_PATH;
  const port = Number(process.env.CX_DASHBOARD_PORT ?? "43120");

  if (!registryPath) {
    throw new Error("CX_DASHBOARD_REGISTRY_PATH is required");
  }

  const server = buildServer({ registryPath });
  server
    .listen({
      port,
      host: "127.0.0.1"
    })
    .catch((error) => {
      server.log.error(error);
      process.exit(1);
    });
}
