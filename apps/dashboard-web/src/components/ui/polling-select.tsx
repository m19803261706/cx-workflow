import React from "react";
import { Timer } from "lucide-react";

type PollingSelectProps = {
  value: number;
  onChange: (ms: number) => void;
};

const OPTIONS = [
  { label: "5 秒", value: 5000 },
  { label: "10 秒", value: 10000 },
  { label: "30 秒", value: 30000 },
  { label: "暂停", value: 0 }
];

export function PollingSelect({ value, onChange }: PollingSelectProps) {
  return (
    <div className="flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-2 text-sm text-slate-300">
      <Timer className="h-3.5 w-3.5 shrink-0" />
      <select
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        className="bg-transparent text-sm text-slate-300 outline-none cursor-pointer"
        aria-label="轮询频率"
      >
        {OPTIONS.map((opt) => (
          <option key={opt.value} value={opt.value} className="bg-slate-900 text-slate-200">
            {opt.label}
          </option>
        ))}
      </select>
    </div>
  );
}
