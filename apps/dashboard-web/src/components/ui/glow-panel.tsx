import React from "react";
import { motion } from "motion/react";

import { cn } from "../../lib/cn.ts";

type GlowPanelProps = {
  children: React.ReactNode;
  className?: string;
  tone?: "cyan" | "blue" | "amber" | "rose" | "emerald";
};

const toneClasses: Record<NonNullable<GlowPanelProps["tone"]>, string> = {
  cyan: "before:from-cyan-300/30 before:via-cyan-400/10 before:to-transparent",
  blue: "before:from-blue-300/30 before:via-sky-400/10 before:to-transparent",
  amber: "before:from-amber-300/30 before:via-orange-400/10 before:to-transparent",
  rose: "before:from-rose-300/30 before:via-fuchsia-400/10 before:to-transparent",
  emerald: "before:from-emerald-300/30 before:via-teal-400/10 before:to-transparent"
};

export function GlowPanel({ children, className, tone = "cyan" }: GlowPanelProps) {
  return (
    <motion.section
      layout
      whileHover={{ y: -4 }}
      transition={{ type: "spring", stiffness: 220, damping: 22 }}
      className={cn(
        "panel-border panel-surface relative overflow-hidden rounded-[28px] p-5 sm:p-6",
        "before:pointer-events-none before:absolute before:inset-x-0 before:top-0 before:h-24 before:bg-gradient-to-b",
        toneClasses[tone],
        className
      )}
    >
      <div className="absolute inset-x-8 top-0 h-px bg-gradient-to-r from-transparent via-white/50 to-transparent" />
      <div className="relative">{children}</div>
    </motion.section>
  );
}
