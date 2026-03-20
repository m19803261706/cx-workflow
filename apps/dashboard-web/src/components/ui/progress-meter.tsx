import React from "react";
import * as Progress from "@radix-ui/react-progress";

type ProgressMeterProps = {
  value: number;
  total: number;
};

export function ProgressMeter({ value, total }: ProgressMeterProps) {
  const safeTotal = total <= 0 ? 1 : total;
  const percentage = Math.max(0, Math.min(100, Math.round((value / safeTotal) * 100)));

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between text-xs font-medium uppercase tracking-[0.18em] text-slate-400">
        <span>任务吞吐</span>
        <span>{percentage}%</span>
      </div>
      <Progress.Root
        className="relative h-2 overflow-hidden rounded-full bg-white/8 shadow-[inset_0_1px_2px_rgba(0,0,0,0.3)]"
        value={percentage}
      >
        <Progress.Indicator
          className="h-full rounded-full bg-gradient-to-r from-cyan-300 via-sky-400 to-blue-500 transition-transform duration-500"
          style={{ transform: `translateX(-${100 - percentage}%)` }}
        />
      </Progress.Root>
    </div>
  );
}
