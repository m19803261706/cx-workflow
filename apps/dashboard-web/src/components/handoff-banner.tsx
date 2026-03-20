import React from "react";
import { ArrowRightLeft } from "lucide-react";

type HandoffBannerProps = {
  visible: boolean;
};

export function HandoffBanner({ visible }: HandoffBannerProps) {
  if (!visible) {
    return null;
  }

  return (
    <div className="panel-border relative overflow-hidden rounded-[26px] border-amber-300/15 bg-gradient-to-br from-amber-400/12 via-amber-400/6 to-transparent px-5 py-4 text-amber-50">
      <div className="absolute inset-x-10 top-0 h-px bg-gradient-to-r from-transparent via-amber-200/80 to-transparent" />
      <div className="relative flex items-start gap-3">
        <div className="rounded-2xl border border-amber-200/20 bg-amber-100/10 p-3">
          <ArrowRightLeft className="h-4 w-4" />
        </div>
        <div className="space-y-1">
          <div className="text-xs font-semibold uppercase tracking-[0.22em] text-amber-100/80">交接提醒</div>
          <div className="text-base font-semibold">当前存在待处理交接</div>
          <div className="text-sm leading-6 text-amber-50/80">
            请先确认由哪一端继续推进，避免 CC 与 Codex 同时占用同一条 feature 的执行权。
          </div>
        </div>
      </div>
    </div>
  );
}
