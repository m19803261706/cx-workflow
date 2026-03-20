import React from "react";
import { motion } from "motion/react";

import { cn } from "../../lib/cn.ts";

type MetricCardProps = {
  label: string;
  value: string;
  hint: string;
  icon: React.ReactNode;
  tone?: "cyan" | "blue" | "amber" | "emerald";
};

const toneClasses: Record<NonNullable<MetricCardProps["tone"]>, string> = {
  cyan: "from-cyan-400/18 via-cyan-400/6 to-transparent",
  blue: "from-blue-400/18 via-blue-400/6 to-transparent",
  amber: "from-amber-400/18 via-amber-400/6 to-transparent",
  emerald: "from-emerald-400/18 via-emerald-400/6 to-transparent"
};

export function MetricCard({ label, value, hint, icon, tone = "cyan" }: MetricCardProps) {
  return (
    <motion.div
      whileHover={{ scale: 1.01, y: -2 }}
      transition={{ type: "spring", stiffness: 220, damping: 18 }}
      className="panel-border panel-surface relative overflow-hidden rounded-[24px] p-5"
    >
      <div className={cn("absolute inset-x-0 top-0 h-28 bg-gradient-to-b", toneClasses[tone])} />
      <div className="relative flex items-start justify-between gap-4">
        <div className="space-y-2">
          <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">{label}</div>
          <div className="text-3xl font-semibold text-white">{value}</div>
          <div className="text-sm leading-6 text-slate-400">{hint}</div>
        </div>
        <div className="rounded-2xl border border-white/10 bg-white/5 p-3 text-cyan-100">{icon}</div>
      </div>
    </motion.div>
  );
}
