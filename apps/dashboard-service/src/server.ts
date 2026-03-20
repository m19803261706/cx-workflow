import Fastify from "fastify";

import { registerProjectRoutes } from "./routes/projects.ts";

export type DashboardServerOptions = {
  registryPath: string;
};

export function buildServer(options: DashboardServerOptions) {
  const server = Fastify({
    logger: false
  });

  server.get("/api/dashboard/health", async () => ({
    status: "ok"
  }));

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
