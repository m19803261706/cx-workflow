import React from "react";
import { Blocks, Cpu, Route, Workflow, Wrench } from "lucide-react";

import {
  formatBindingStatus,
  formatOwnerRunner,
  formatTaskStatus,
  formatWorkflowPhase
} from "../labels.ts";
import { GlowPanel } from "./ui/glow-panel.tsx";
import { ProgressMeter } from "./ui/progress-meter.tsx";
import { StatusPill } from "./ui/status-pill.tsx";
import type { FeatureDetail } from "../types.ts";

type FeatureSummaryProps = {
  feature: FeatureDetail;
  lifecycleStage: string | null;
};

export function FeatureSummary({ feature, lifecycleStage }: FeatureSummaryProps) {
  return (
    <GlowPanel tone="blue" className="space-y-6">
      <div className="space-y-3">
        <div className="text-xs font-semibold uppercase tracking-[0.22em] text-cyan-200/80">
          工作流摘要
        </div>
        <div className="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between">
          <div className="space-y-2">
            <h2 className="text-3xl font-semibold text-white">{feature.title}</h2>
            <div className="terminal-code text-sm text-slate-400">{feature.slug}</div>
          </div>
          <div className="rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3 text-sm text-slate-300">
            下一步建议：{feature.nextRoute ?? "保持观察"}
          </div>
        </div>
      </div>

      <div className="grid gap-3 lg:grid-cols-2 xl:grid-cols-4">
        <StatusPill
          label="当前执行权"
          value={formatOwnerRunner(feature.ownerRunner)}
          hint={feature.ownerSessionId ?? "暂时没有会话持有执行权。"}
          icon={<Cpu className="h-4 w-4 text-cyan-200" />}
          tone="cyan"
        />
        <StatusPill
          label="工作流阶段"
          value={formatWorkflowPhase(feature.workflowPhase)}
          hint={feature.workflowPhase ?? "尚未进入标准 workflow phase。"}
          icon={<Route className="h-4 w-4 text-blue-200" />}
          tone="blue"
        />
        <StatusPill
          label="工作区绑定"
          value={formatBindingStatus(feature.bindingStatus)}
          hint={feature.worktreePath ?? "当前没有 worktree 绑定。"}
          icon={<Wrench className="h-4 w-4 text-amber-200" />}
          tone="amber"
        />
        <StatusPill
          label="任务矩阵"
          value={`${feature.tasks.length} 个任务`}
          hint={`已完成 ${feature.progress.completed} / 总计 ${feature.progress.total}`}
          icon={<Blocks className="h-4 w-4 text-emerald-200" />}
          tone="emerald"
        />
      </div>

      <ProgressMeter value={feature.progress.completed} total={feature.progress.total} />

      <div className="space-y-4">
        <div className="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">任务矩阵</div>
        {feature.tasks.map((task) => (
          <div
            key={task.id}
            className="grid gap-3 rounded-2xl border border-white/8 bg-white/[0.03] px-4 py-4 sm:grid-cols-[minmax(0,1fr)_auto]"
          >
            <div className="space-y-1">
              <div className="font-medium text-white">{task.title}</div>
              <div className="text-sm text-slate-400">
                Phase {task.phase ?? "—"}{task.parallelGroup ? ` · ${task.parallelGroup}` : ""}
              </div>
            </div>
            <div className="text-sm font-semibold text-cyan-100">{formatTaskStatus(task.status)}</div>
          </div>
        ))}
      </div>
    </GlowPanel>
  );
}
