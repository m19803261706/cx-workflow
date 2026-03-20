import React from "react";
import { Check } from "lucide-react";
import { motion } from "motion/react";

import { cn } from "../../lib/cn.ts";
import { formatWorkflowPhase } from "../../labels.ts";

const PHASES = ["prd", "design", "plan", "exec", "summary"] as const;

type WorkflowStepperProps = {
  workflowPhase: string | null;
  lifecycleStage: string | null;
  variant?: "full" | "mini";
};

function resolveStepStates(workflowPhase: string | null, lifecycleStage: string | null) {
  if (lifecycleStage === "completed") {
    return PHASES.map(() => "completed" as const);
  }

  const currentIndex = workflowPhase ? PHASES.indexOf(workflowPhase as (typeof PHASES)[number]) : -1;

  return PHASES.map((_, i) => {
    if (currentIndex < 0) return "upcoming" as const;
    if (i < currentIndex) return "completed" as const;
    if (i === currentIndex) return "current" as const;
    return "upcoming" as const;
  });
}

export function WorkflowStepper({ workflowPhase, lifecycleStage, variant = "full" }: WorkflowStepperProps) {
  const states = resolveStepStates(workflowPhase, lifecycleStage);
  const isMini = variant === "mini";

  return (
    <div className={cn("flex items-center", isMini ? "gap-1.5" : "gap-0")} role="list" aria-label="工作流阶段">
      {PHASES.map((phase, i) => {
        const state = states[i];
        return (
          <React.Fragment key={phase}>
            {i > 0 && (
              <div
                className={cn(
                  isMini ? "h-px w-3" : "h-px flex-1",
                  state === "upcoming" ? "bg-white/10" : "bg-cyan-400/50"
                )}
              />
            )}
            <div className="flex flex-col items-center gap-1.5" role="listitem">
              {state === "completed" ? (
                <div
                  className={cn(
                    "flex items-center justify-center rounded-full bg-cyan-400/20 border border-cyan-300/30",
                    isMini ? "h-3 w-3" : "h-8 w-8"
                  )}
                >
                  <Check className={cn("text-cyan-200", isMini ? "h-2 w-2" : "h-4 w-4")} />
                </div>
              ) : state === "current" ? (
                <div className="relative flex items-center justify-center">
                  {!isMini && (
                    <motion.div
                      className="absolute rounded-full bg-cyan-400/20"
                      style={{ width: 40, height: 40 }}
                      animate={{ scale: [1, 1.4, 1], opacity: [0.5, 0, 0.5] }}
                      transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
                    />
                  )}
                  <div
                    className={cn(
                      "relative rounded-full border-2 border-cyan-300 bg-cyan-400/30",
                      isMini ? "h-3.5 w-3.5" : "h-8 w-8"
                    )}
                  />
                </div>
              ) : (
                <div
                  className={cn(
                    "rounded-full border border-white/15 bg-white/5",
                    isMini ? "h-3 w-3" : "h-8 w-8"
                  )}
                />
              )}
              {!isMini && (
                <span
                  className={cn(
                    "text-xs whitespace-nowrap",
                    state === "current" ? "font-bold text-cyan-100" :
                    state === "completed" ? "font-medium text-cyan-200/70" :
                    "text-slate-500"
                  )}
                >
                  {formatWorkflowPhase(phase)}
                </span>
              )}
            </div>
          </React.Fragment>
        );
      })}
    </div>
  );
}
