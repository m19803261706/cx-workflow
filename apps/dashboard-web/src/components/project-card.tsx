import React from "react";
import {
  Activity,
  Bot,
  Cpu,
  FolderGit2,
  GitBranch,
  ShieldAlert,
  Workflow
} from "lucide-react";
import { motion } from "motion/react";

import { formatLifecycleStage, formatOwnerRunner, formatSyncStatus } from "../labels.ts";
import { StatusPill } from "./ui/status-pill.tsx";
import type { ProjectSummary } from "../types.ts";

type ProjectCardProps = {
  project: Pick<
    ProjectSummary,
    | "id"
    | "displayName"
    | "currentFeatureSlug"
    | "currentFeatureTitle"
    | "lifecycleStage"
    | "ownerRunner"
    | "worktreePath"
    | "progressCompleted"
    | "progressTotal"
    | "syncStatus"
    | "handoffPending"
    | "rootPath"
  >;
};

export function ProjectCard({ project }: ProjectCardProps) {
  const progressLabel = `${project.progressCompleted} / ${project.progressTotal}`;

  return (
    <motion.article
      whileHover={{ y: -4 }}
      transition={{ type: "spring", stiffness: 220, damping: 18 }}
      className="panel-border panel-surface group relative overflow-hidden rounded-[28px] p-5"
    >
      <div className="absolute inset-x-10 top-0 h-px bg-gradient-to-r from-transparent via-cyan-300/80 to-transparent" />
      <div className="absolute inset-0 opacity-0 transition duration-300 group-hover:opacity-100">
        <div className="absolute inset-x-0 top-0 h-28 bg-gradient-to-b from-cyan-300/12 via-cyan-300/4 to-transparent" />
      </div>

      <div className="relative space-y-5">
        <div className="flex items-start justify-between gap-4">
          <div className="space-y-2">
            <div className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">
              项目标识 · {project.id}
            </div>
            <h3 className="text-2xl font-semibold text-white">{project.displayName}</h3>
            <div className="text-sm leading-6 text-slate-300">
              {project.currentFeatureTitle ?? "当前没有活跃功能"}
            </div>
          </div>
          <div className="rounded-full border border-emerald-300/15 bg-emerald-400/10 px-3 py-1 text-xs font-semibold text-emerald-100">
            {formatSyncStatus(project.syncStatus)}
          </div>
        </div>

        <div className="terminal-code flex items-center gap-3 overflow-hidden rounded-2xl border border-cyan-300/12 bg-slate-950/70 px-4 py-3 text-xs text-cyan-100">
          <Bot className="h-4 w-4 shrink-0" />
          <span className="truncate">$ cx-status --project {project.id}</span>
        </div>

        <div className="grid gap-3 xl:grid-cols-2">
          <StatusPill
            label="执行引擎"
            value={formatOwnerRunner(project.ownerRunner)}
            icon={<Cpu className="h-4 w-4 text-cyan-200" />}
            tone="cyan"
          />
          <StatusPill
            label="生命周期"
            value={formatLifecycleStage(project.lifecycleStage)}
            icon={<Workflow className="h-4 w-4 text-blue-200" />}
            tone="blue"
          />
          <StatusPill
            label="任务吞吐"
            value={progressLabel}
            icon={<Activity className="h-4 w-4 text-emerald-200" />}
            tone="emerald"
          />
          <StatusPill
            label="工作区沙箱"
            value={project.worktreePath ? "已绑定" : "未绑定"}
            hint={project.worktreePath ?? "当前还没有绑定 worktree。"}
            icon={<GitBranch className="h-4 w-4 text-amber-200" />}
            tone="amber"
          />
        </div>

        <div className="grid gap-3 border-t border-white/8 pt-4">
          <div className="flex items-start gap-3 rounded-2xl border border-white/8 bg-white/[0.03] px-4 py-3">
            <FolderGit2 className="mt-0.5 h-4 w-4 shrink-0 text-slate-300" />
            <div className="space-y-1">
              <div className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">项目路径</div>
              <div className="text-sm break-all text-slate-300">{project.rootPath}</div>
            </div>
          </div>

          <div className="flex items-start gap-3 rounded-2xl border border-white/8 bg-white/[0.03] px-4 py-3">
            <ShieldAlert
              className={`mt-0.5 h-4 w-4 shrink-0 ${project.handoffPending ? "text-amber-200" : "text-slate-500"}`}
            />
            <div className="space-y-1">
              <div className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">接管信号</div>
              <div className="text-sm text-slate-300">
                {project.handoffPending
                  ? "当前存在待交接状态，建议先确认由哪一端继续接管。"
                  : "当前没有交接阻塞，可以继续按既定流程推进。"}
              </div>
            </div>
          </div>
        </div>
      </div>
    </motion.article>
  );
}
