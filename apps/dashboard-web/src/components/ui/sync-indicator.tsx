import React, { useEffect, useRef } from "react";
import { motion, useAnimationControls } from "motion/react";

import { cn } from "../../lib/cn.ts";

type SyncIndicatorProps = {
  lastSyncedAt: number | null;
  error: string | null;
};

export function SyncIndicator({ lastSyncedAt, error }: SyncIndicatorProps) {
  const controls = useAnimationControls();
  const prevSyncRef = useRef(lastSyncedAt);

  useEffect(() => {
    if (lastSyncedAt !== null && lastSyncedAt !== prevSyncRef.current) {
      prevSyncRef.current = lastSyncedAt;
      void controls.start({
        scale: [1, 1.8, 1],
        opacity: [1, 0.8, 1],
        transition: { duration: 0.6 }
      });
    }
  }, [lastSyncedAt, controls]);

  return (
    <div className="relative flex items-center" title={error ?? "数据同步正常"}>
      <motion.div
        animate={controls}
        className={cn(
          "h-2.5 w-2.5 rounded-full",
          error ? "bg-amber-400" : "bg-slate-500/60"
        )}
      />
    </div>
  );
}
