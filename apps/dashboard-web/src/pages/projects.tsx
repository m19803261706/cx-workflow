import React, { useEffect, useState } from "react";
import {
  Activity,
  Boxes,
  Cable,
  FolderKanban,
  Sparkles,
  SquareTerminal
} from "lucide-react";

import { ProjectCard } from "../components/project-card.tsx";
import { DashboardShell } from "../components/ui/dashboard-shell.tsx";
import { GlowPanel } from "../components/ui/glow-panel.tsx";
import { MetricCard } from "../components/ui/metric-card.tsx";
import { SectionHeading } from "../components/ui/section-heading.tsx";
import { formatServiceStatus } from "../labels.ts";
import type { DashboardHealth, ProjectSummary } from "../types.ts";

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

  const activeProjects = projects.filter((project) => project.currentFeatureSlug).length;
  const handoffProjects = projects.filter((project) => project.handoffPending).length;

  return (
    <DashboardShell
      eyebrow="CX 全局管理面板"
      title="全局工作流指挥台"
      description="面向程序员的多项目调度观察台。统一查看 feature 生命周期、执行引擎、worktree 绑定、交接阻塞与任务吞吐。"
      toolbar={
        <>
          <div className="rounded-full border border-cyan-300/15 bg-cyan-400/10 px-4 py-2 text-sm text-cyan-100">
            服务状态 · {health ? formatServiceStatus(health.serviceStatus) : "连接中"}
          </div>
          <div className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300">
            API · {health?.apiBaseUrl ?? "等待连接"}
          </div>
        </>
      }
    >
      <div className="grid gap-6 xl:grid-cols-[minmax(0,1.35fr)_minmax(320px,0.9fr)]">
        <GlowPanel tone="blue" className="space-y-5">
          <div className="inline-flex w-fit items-center gap-2 rounded-full border border-blue-300/15 bg-blue-400/10 px-3 py-1 text-xs font-semibold uppercase tracking-[0.22em] text-blue-100">
            <Sparkles className="h-3.5 w-3.5" />
            程序员观察台
          </div>
          <div className="space-y-3">
            <h2 className="text-3xl font-semibold text-white sm:text-4xl">多项目 CX 执行网络</h2>
            <p className="max-w-3xl text-sm leading-7 text-slate-300">
              这里不是传统管理后台，而是一块面向开发者的工作流观测屏。你可以同时跟踪多个项目里
              CC 与 Codex 的推进情况，快速发现待交接、待同步和执行阻塞。
            </p>
          </div>
          <div className="terminal-code flex items-center gap-3 rounded-2xl border border-cyan-300/12 bg-slate-950/70 px-4 py-3 text-xs text-cyan-100">
            <SquareTerminal className="h-4 w-4 shrink-0" />
            <span>$ cx-status --global --topology live</span>
          </div>
        </GlowPanel>

        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-2">
          <MetricCard
            label="接入项目"
            value={`${projects.length}`}
            hint="已注册到全局面板并允许被聚合读取的项目数量。"
            icon={<FolderKanban className="h-5 w-5" />}
            tone="cyan"
          />
          <MetricCard
            label="活跃功能"
            value={`${activeProjects}`}
            hint="当前仍处在 PRD / Design / Plan / Exec 轨道中的功能数量。"
            icon={<Boxes className="h-5 w-5" />}
            tone="blue"
          />
          <MetricCard
            label="交接警报"
            value={`${handoffProjects}`}
            hint="存在 handoff pending，需要先确认由哪一端接管执行。"
            icon={<Cable className="h-5 w-5" />}
            tone="amber"
          />
          <MetricCard
            label="服务脉冲"
            value={health ? formatServiceStatus(health.serviceStatus) : "连接中"}
            hint="本地 dashboard service 的聚合状态与当前 API 可用性。"
            icon={<Activity className="h-5 w-5" />}
            tone="emerald"
          />
        </div>
      </div>

      <section className="space-y-4">
        <SectionHeading
          eyebrow="项目拓扑"
          title="接入项目"
          description="每张卡片都对应一个已接入项目，展示当前执行引擎、生命周期、worktree 绑定和交接信号。"
        />

        {error ? (
          <GlowPanel tone="rose">
            <div className="space-y-2">
              <div className="text-sm font-semibold uppercase tracking-[0.2em] text-rose-200/80">
                服务告警
              </div>
              <div className="text-base text-rose-50">{error}</div>
            </div>
          </GlowPanel>
        ) : null}

        <div className="grid gap-4 xl:grid-cols-2">
          {projects.map((project) => (
            <a key={project.id} href={`#/projects/${project.id}`} className="block text-inherit no-underline">
              <ProjectCard project={project} />
            </a>
          ))}
        </div>

        {!projects.length && !error ? (
          <GlowPanel tone="amber">
            <div className="space-y-2 text-center">
              <div className="text-lg font-semibold text-white">当前还没有接入项目</div>
              <div className="text-sm leading-7 text-slate-300">
                你可以先在某个项目里运行 `cx-init` 或 `cx-prd`，也可以通过 bridge 脚本手动注册项目。
              </div>
            </div>
          </GlowPanel>
        ) : null}
      </section>
    </DashboardShell>
  );
}
