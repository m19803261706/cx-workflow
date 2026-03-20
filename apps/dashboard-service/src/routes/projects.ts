import type { FastifyInstance } from "fastify";

import { collectProjects, getProjectDetail, registerProject, scanProjects } from "../projects.ts";

type RegisterBody = {
  rootPath: string;
  displayName?: string;
  projectId?: string;
};

type ScanBody = {
  roots?: string[];
};

export async function registerProjectRoutes(server: FastifyInstance, registryPath: string) {
  server.get("/api/dashboard/projects", async () => {
    const result = await collectProjects({ registryPath });
    return {
      projects: result.projects
    };
  });

  server.get("/api/dashboard/projects/:projectId", async (request, reply) => {
    const { projectId } = request.params as { projectId: string };
    const detail = await getProjectDetail(registryPath, projectId);
    if (!detail) {
      reply.code(404);
      return {
        message: `project ${projectId} not found`
      };
    }

    return detail;
  });

  server.post("/api/dashboard/projects/register", async (request, reply) => {
    const body = request.body as RegisterBody;
    const project = await registerProject({
      registryPath,
      rootPath: body.rootPath,
      displayName: body.displayName,
      projectId: body.projectId
    });

    if (!project) {
      reply.code(404);
      return {
        message: "project could not be registered"
      };
    }

    reply.code(201);
    return {
      project
    };
  });

  server.post("/api/dashboard/projects/scan", async (request) => {
    const body = (request.body as ScanBody | undefined) ?? {};
    const projects = await scanProjects({
      registryPath,
      roots: body.roots
    });

    return {
      projects
    };
  });
}
