import React from "react";

import { cn } from "../../lib/cn.ts";

type StatusPillProps = {
  label: string;
  value: string;
  hint?: string;
  icon?: React.ReactNode;
  tone?: "cyan" | "blue" | "amber" | "rose" | "emerald";
  className?: string;
};

const toneClasses: Record<NonNullable<StatusPillProps["tone"]>, string> = {
  cyan: "border-cyan-300/15 bg-cyan-400/8 text-cyan-50",
  blue: "border-blue-300/15 bg-blue-400/8 text-blue-50",
  amber: "border-amber-300/15 bg-amber-400/10 text-amber-50",
  rose: "border-rose-300/15 bg-rose-400/8 text-rose-50",
  emerald: "border-emerald-300/15 bg-emerald-400/8 text-emerald-50"
};

export function StatusPill({
  label,
  value,
  hint,
  icon,
  tone = "cyan",
  className
}: StatusPillProps) {
  return (
    <div
      className={cn(
        "rounded-2xl border px-4 py-3 shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]",
        toneClasses[tone],
        className
      )}
    >
      <div className="mb-2 text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">
        {label}
      </div>
      <div className="flex items-center gap-2 text-sm font-semibold text-white">
        {icon}
        <span>{value}</span>
      </div>
      {hint ? <div className="mt-2 break-all text-xs leading-5 text-slate-400">{hint}</div> : null}
    </div>
  );
}
