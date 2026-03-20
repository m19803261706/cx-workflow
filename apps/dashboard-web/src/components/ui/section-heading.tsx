import React from "react";

type SectionHeadingProps = {
  eyebrow: string;
  title: string;
  description: string;
};

export function SectionHeading({ eyebrow, title, description }: SectionHeadingProps) {
  return (
    <header className="space-y-2">
      <div className="text-xs font-semibold uppercase tracking-[0.22em] text-cyan-200/80">{eyebrow}</div>
      <h2 className="text-2xl font-semibold text-white">{title}</h2>
      <p className="max-w-3xl text-sm leading-6 text-slate-400">{description}</p>
    </header>
  );
}
