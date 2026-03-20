import React from "react";
import { AnimatePresence, motion } from "motion/react";

import { DashboardShell } from "./components/ui/dashboard-shell.tsx";
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

  const routeKey = selectedProjectId ? `project-${selectedProjectId}` : "projects";

  let content: React.ReactNode;

  if (selectedProjectId) {
    if (projectDetail) {
      content = <ProjectDetailPage detail={projectDetail} onBackHref="#/" />;
    } else {
      content = (
        <DashboardShell
          eyebrow="全局项目指挥台"
          title="项目详情载入中"
          description={projectDetailError ?? "正在向本地 dashboard service 获取项目状态，请稍候。"}
          backHref="#/"
          backLabel="返回项目列表"
        >
          <div className="panel-border panel-surface rounded-[28px] px-6 py-8 text-sm text-slate-300">
            {projectDetailError ?? "正在同步项目详情..."}
          </div>
        </DashboardShell>
      );
    }
  } else {
    content = <ProjectsPage />;
  }

  return (
    <AnimatePresence initial={false} mode="wait">
      <motion.div
        key={routeKey}
        initial={{ opacity: 0, y: 18, filter: "blur(10px)" }}
        animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
        exit={{ opacity: 0, y: -12, filter: "blur(10px)" }}
        transition={{ duration: 0.28, ease: "easeOut" }}
      >
        {content}
      </motion.div>
    </AnimatePresence>
  );
}
