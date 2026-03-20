import React from "react";

import { ProjectDetailPage } from "./pages/project-detail.tsx";
import { ProjectsPage } from "./pages/projects.tsx";
import type { ProjectDetail } from "./types.ts";

function getProjectIdFromHash(hash: string) {
  const match = hash.match(/^#\/projects\/([^/]+)$/);
  return match?.[1] ?? null;
}

export default function App() {
  const [projectDetail, setProjectDetail] = React.useState<ProjectDetail | null>(null);
  const [projectDetailError, setProjectDetailError] = React.useState<string | null>(null);
  const [selectedProjectId, setSelectedProjectId] = React.useState(() =>
    getProjectIdFromHash(window.location.hash)
  );

  React.useEffect(() => {
    const handleHashChange = () => {
      setSelectedProjectId(getProjectIdFromHash(window.location.hash));
    };

    window.addEventListener("hashchange", handleHashChange);
    return () => {
      window.removeEventListener("hashchange", handleHashChange);
    };
  }, []);

  React.useEffect(() => {
    if (!selectedProjectId) {
      setProjectDetail(null);
      setProjectDetailError(null);
      return;
    }

    const controller = new AbortController();
    const apiBaseUrl =
      import.meta.env.VITE_CX_DASHBOARD_API_BASE_URL ?? "http://127.0.0.1:43120/api/dashboard";

    async function loadDetail() {
      try {
        const response = await fetch(`${apiBaseUrl}/projects/${selectedProjectId}`, {
          signal: controller.signal
        });

        if (!response.ok) {
          throw new Error("项目详情暂时不可用");
        }

        const detail = (await response.json()) as ProjectDetail;
        setProjectDetail(detail);
        setProjectDetailError(null);
      } catch (error) {
        if (controller.signal.aborted) {
          return;
        }

        setProjectDetail(null);
        setProjectDetailError(error instanceof Error ? error.message : "未知错误");
      }
    }

    void loadDetail();
    return () => {
      controller.abort();
    };
  }, [selectedProjectId]);

  if (selectedProjectId) {
    if (projectDetail) {
      return <ProjectDetailPage detail={projectDetail} onBackHref="#/" />;
    }

    return (
      <div style={{ padding: 32, fontFamily: "\"PingFang SC\", sans-serif" }}>
        <a href="#/" style={{ color: "#8c5e34", textDecoration: "none" }}>
          ← 返回项目列表
        </a>
        <div style={{ marginTop: 16, color: "#7c3f1d" }}>
          {projectDetailError ?? "正在加载项目详情..."}
        </div>
      </div>
    );
  }

  return <ProjectsPage />;
}
