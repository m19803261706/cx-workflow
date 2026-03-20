import React, { useEffect, useState } from "react";

import { ProjectCard } from "../components/project-card.tsx";
import type { DashboardHealth, ProjectSummary } from "../types.ts";

const pageStyle: React.CSSProperties = {
  minHeight: "100vh",
  background:
    "radial-gradient(circle at top left, rgba(255,219,176,0.85), transparent 32%), linear-gradient(180deg, #fff8ef 0%, #f7efe3 100%)",
  padding: "40px 32px 64px",
  fontFamily: "\"PingFang SC\", \"Hiragino Sans GB\", \"Microsoft YaHei\", sans-serif",
  color: "#2f2016"
};

const sectionCardStyle: React.CSSProperties = {
  borderRadius: 24,
  backgroundColor: "rgba(255, 251, 246, 0.86)",
  border: "1px solid rgba(146, 102, 64, 0.16)",
  boxShadow: "0 24px 48px rgba(78, 44, 20, 0.08)",
  padding: 24
};

function resolveApiBaseUrl() {
  return import.meta.env.VITE_CX_DASHBOARD_API_BASE_URL ?? "http://127.0.0.1:43120/api/dashboard";
}

export function ProjectsPage() {
  const [health, setHealth] = useState<DashboardHealth | null>(null);
  const [projects, setProjects] = useState<ProjectSummary[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    const apiBaseUrl = resolveApiBaseUrl();

    async function load() {
      try {
        const [healthResponse, projectsResponse] = await Promise.all([
          fetch(`${apiBaseUrl}/health`),
          fetch(`${apiBaseUrl}/projects`)
        ]);

        if (!healthResponse.ok || !projectsResponse.ok) {
          throw new Error("本地 dashboard service 暂时不可用");
        }

        const nextHealth = (await healthResponse.json()) as DashboardHealth;
        const nextProjects = (await projectsResponse.json()) as { projects: ProjectSummary[] };

        if (!active) {
          return;
        }

        setHealth(nextHealth);
        setProjects(nextProjects.projects);
        setError(null);
      } catch (loadError) {
        if (!active) {
          return;
        }

        setError(loadError instanceof Error ? loadError.message : "未知错误");
      }
    }

    void load();
    return () => {
      active = false;
    };
  }, []);

  return (
    <div style={pageStyle}>
      <header style={{ marginBottom: 24, display: "grid", gap: 10 }}>
        <div style={{ fontSize: 14, letterSpacing: "0.12em", color: "#8c5e34" }}>CX DASHBOARD</div>
        <h1 style={{ margin: 0, fontSize: 44, lineHeight: 1.1 }}>全局观察台</h1>
        <div style={{ fontSize: 16, color: "#6b4d38", maxWidth: 760 }}>
          统一查看所有接入项目的 current feature、owner、phase、handoff 与进度状态。
        </div>
      </header>

      <section style={{ ...sectionCardStyle, marginBottom: 24 }}>
        <div style={{ display: "flex", justifyContent: "space-between", gap: 16, flexWrap: "wrap" }}>
          <div>
            <div style={{ fontSize: 14, color: "#8c5e34" }}>service status</div>
            <div style={{ fontSize: 28, fontWeight: 700 }}>{health?.serviceStatus ?? "loading"}</div>
          </div>
          <div>
            <div style={{ fontSize: 14, color: "#8c5e34" }}>projects</div>
            <div style={{ fontSize: 28, fontWeight: 700 }}>{projects.length}</div>
          </div>
          <div>
            <div style={{ fontSize: 14, color: "#8c5e34" }}>api</div>
            <div style={{ fontSize: 15, color: "#5b4332" }}>{health?.apiBaseUrl ?? "等待连接"}</div>
          </div>
        </div>
        {error ? (
          <div style={{ marginTop: 16, color: "#a23d25" }}>{error}</div>
        ) : null}
      </section>

      <section style={{ display: "grid", gap: 16 }}>
        {projects.map((project) => (
          <a key={project.id} href={`#/projects/${project.id}`} style={{ textDecoration: "none" }}>
            <ProjectCard project={project} />
          </a>
        ))}
        {!projects.length && !error ? (
          <div style={{ ...sectionCardStyle, textAlign: "center", color: "#7d5b44" }}>
            当前还没有接入项目。
          </div>
        ) : null}
      </section>
    </div>
  );
}
