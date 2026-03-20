import React from "react";
import { BookCopy, FolderOpen, RefreshCw, TerminalSquare, Waypoints } from "lucide-react";

import { FeatureSummary } from "../components/feature-summary.tsx";
import { HandoffBanner } from "../components/handoff-banner.tsx";
import { WorkflowStepper } from "../components/ui/workflow-stepper.tsx";
import { formatOwnerRunner } from "../labels.ts";
import { DashboardShell } from "../components/ui/dashboard-shell.tsx";
import { GlowPanel } from "../components/ui/glow-panel.tsx";
import { SectionHeading } from "../components/ui/section-heading.tsx";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../components/ui/tabs.tsx";
import type { ProjectDetail } from "../types.ts";

type ProjectDetailPageProps = {
  detail: ProjectDetail;
  onBackHref: string;
};

export function ProjectDetailPage({ detail, onBackHref }: ProjectDetailPageProps) {
  const docsEntries = Object.entries(detail.feature?.docs ?? {});

  return (
    <DashboardShell
      eyebrow="全局项目指挥台"
      title={detail.project.displayName}
      description={detail.project.rootPath}
      backHref={onBackHref}
      backLabel="返回项目列表"
      toolbar={
        <div className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-300">
          执行引擎 · {formatOwnerRunner(detail.project.ownerRunner)}
        </div>
      }
    >
      <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_360px]">
        <GlowPanel tone="cyan" className="space-y-4">
          <SectionHeading
            eyebrow="只读观察模式"
            title="当前项目只读观察面板"
            description="这里专注于状态查看与路径跳转，不直接改写 workflow。命令调度仍建议在 CC 或 Codex 会话中完成。"
          />
          <div className="flex flex-wrap gap-3">
            <button
              type="button"
              className="inline-flex items-center gap-2 rounded-full border border-cyan-300/15 bg-cyan-400/10 px-4 py-2 text-sm font-semibold text-cyan-50"
            >
              <FolderOpen className="h-4 w-4" />
              打开项目目录
            </button>
            <button
              type="button"
              className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-200"
            >
              <TerminalSquare className="h-4 w-4" />
              复制建议命令
            </button>
            <button
              type="button"
              className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-200"
            >
              <RefreshCw className="h-4 w-4" />
              手动刷新
            </button>
          </div>
        </GlowPanel>

        <HandoffBanner visible={detail.project.handoffPending || detail.feature?.handoffPending === true} />
      </div>

      {detail.feature && (
        <div className="panel-border panel-surface rounded-[28px] px-6 py-5">
          <WorkflowStepper
            workflowPhase={detail.feature.workflowPhase}
            lifecycleStage={detail.project.lifecycleStage ?? null}
            variant="full"
          />
        </div>
      )}

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1.25fr)_minmax(320px,0.9fr)]">
        <FeatureSummary detail={detail} />

        <GlowPanel tone="amber" className="space-y-4">
          <SectionHeading
            eyebrow="执行会话"
            title="运行中的执行会话"
            description="查看当前会话、分支、worktree 以及文档锚点，快速判断项目由哪一端持有执行权。"
          />

          <Tabs defaultValue="sessions">
            <TabsList>
              <TabsTrigger value="sessions">会话总线</TabsTrigger>
              <TabsTrigger value="docs">工作流文档</TabsTrigger>
            </TabsList>

            <TabsContent value="sessions" className="space-y-3">
              {detail.activeSessions.map((session) => (
                <div key={session.sessionId} className="rounded-2xl border border-white/8 bg-white/[0.03] p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div className="space-y-1">
                      <div className="text-base font-semibold text-white">{session.sessionId}</div>
                      <div className="text-sm text-slate-400">
                        {formatOwnerRunner(session.runner === "cx" ? "none" : session.runner)} · {session.branch}
                      </div>
                    </div>
                    <div className="rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs font-semibold text-slate-300">
                      {session.claimedTasks.length ? `任务 ${session.claimedTasks.join(", ")}` : "未占用任务"}
                    </div>
                  </div>
                  <div className="mt-3 flex items-start gap-2 text-sm text-slate-300">
                    <Waypoints className="mt-0.5 h-4 w-4 shrink-0 text-amber-200" />
                    <span className="break-all">{session.worktreePath}</span>
                  </div>
                </div>
              ))}
              {!detail.activeSessions.length ? (
                <div className="rounded-2xl border border-dashed border-white/12 bg-white/[0.02] px-4 py-5 text-sm text-slate-400">
                  当前没有活跃会话。
                </div>
              ) : null}
            </TabsContent>

            <TabsContent value="docs" className="space-y-3">
              <div className="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">工作流文档</div>
              {docsEntries.length ? (
                docsEntries.map(([key, value]) => (
                  <div key={key} className="rounded-2xl border border-white/8 bg-white/[0.03] p-4">
                    <div className="flex items-start gap-3">
                      <BookCopy className="mt-0.5 h-4 w-4 shrink-0 text-cyan-200" />
                      <div className="space-y-1">
                        <div className="text-sm font-semibold uppercase tracking-[0.18em] text-slate-400">
                          {key}
                        </div>
                        <div className="terminal-code text-sm break-all text-slate-200">{value}</div>
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="rounded-2xl border border-dashed border-white/12 bg-white/[0.02] px-4 py-5 text-sm text-slate-400">
                  当前 feature 还没有公开的文档锚点。
                </div>
              )}
            </TabsContent>
          </Tabs>
        </GlowPanel>
      </div>
    </DashboardShell>
  );
}
