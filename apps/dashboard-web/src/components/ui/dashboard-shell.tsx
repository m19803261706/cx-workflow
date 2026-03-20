import React from "react";
import { ChevronLeft, Radar } from "lucide-react";
import { motion } from "motion/react";

type DashboardShellProps = {
  eyebrow: string;
  title: string;
  description: string;
  children: React.ReactNode;
  backHref?: string;
  backLabel?: string;
  toolbar?: React.ReactNode;
};

export function DashboardShell({
  eyebrow,
  title,
  description,
  children,
  backHref,
  backLabel = "返回",
  toolbar
}: DashboardShellProps) {
  return (
    <div className="dashboard-shell-noise relative min-h-screen overflow-hidden bg-transparent text-slate-50">
      <div className="dashboard-grid absolute inset-0" />
      <motion.div
        aria-hidden="true"
        className="dashboard-orb absolute left-[-8rem] top-[-4rem] h-72 w-72 rounded-full bg-cyan-400/28"
        animate={{ x: [0, 12, -10, 0], y: [0, -12, 8, 0] }}
        transition={{ duration: 16, repeat: Number.POSITIVE_INFINITY, ease: "easeInOut" }}
      />
      <motion.div
        aria-hidden="true"
        className="dashboard-orb absolute right-[-4rem] top-20 h-64 w-64 rounded-full bg-blue-500/22"
        animate={{ x: [0, -16, 14, 0], y: [0, 18, -10, 0] }}
        transition={{ duration: 20, repeat: Number.POSITIVE_INFINITY, ease: "easeInOut" }}
      />

      <main className="relative mx-auto flex min-h-screen w-full max-w-7xl flex-col gap-8 px-6 py-8 lg:px-10">
        {backHref ? (
          <a
            href={backHref}
            className="inline-flex w-fit items-center gap-2 rounded-full border border-cyan-300/15 bg-slate-950/55 px-4 py-2 text-sm text-cyan-100 transition hover:border-cyan-300/35 hover:text-cyan-50"
          >
            <ChevronLeft className="h-4 w-4" />
            {backLabel}
          </a>
        ) : null}

        <section className="panel-border panel-surface scanline relative overflow-hidden rounded-[32px] px-6 py-6 sm:px-8 sm:py-8">
          <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-cyan-300/65 to-transparent" />
          <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
            <div className="max-w-4xl space-y-4">
              <div className="inline-flex w-fit items-center gap-2 rounded-full border border-cyan-300/15 bg-cyan-400/10 px-3 py-1 text-xs font-semibold tracking-[0.22em] text-cyan-100 uppercase">
                <Radar className="h-3.5 w-3.5" />
                {eyebrow}
              </div>
              <div className="space-y-3">
                <h1 className="text-glow text-4xl font-semibold tracking-tight text-white sm:text-5xl">
                  {title}
                </h1>
                <p className="max-w-3xl text-sm leading-7 text-slate-300 sm:text-base">
                  {description}
                </p>
              </div>
            </div>
            {toolbar ? <div className="flex flex-wrap items-center gap-3">{toolbar}</div> : null}
          </div>
        </section>

        <div className="relative flex flex-1 flex-col gap-6">{children}</div>
      </main>
    </div>
  );
}
