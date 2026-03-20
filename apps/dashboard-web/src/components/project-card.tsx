import React from "react";

import type { ProjectSummary } from "../types.ts";

type ProjectCardProps = {
  project: Pick<
    ProjectSummary,
    | "id"
    | "displayName"
    | "currentFeatureSlug"
    | "currentFeatureTitle"
    | "lifecycleStage"
    | "ownerRunner"
    | "worktreePath"
    | "progressCompleted"
    | "progressTotal"
    | "syncStatus"
    | "handoffPending"
  >;
};

const surfaceStyle: React.CSSProperties = {
  borderRadius: 20,
  border: "1px solid rgba(155, 97, 44, 0.2)",
  background: "linear-gradient(180deg, rgba(255,245,232,0.96) 0%, rgba(255,250,244,0.98) 100%)",
  padding: 20,
  boxShadow: "0 18px 40px rgba(78, 44, 20, 0.08)",
  display: "grid",
  gap: 12
};

const metaRowStyle: React.CSSProperties = {
  display: "flex",
  flexWrap: "wrap",
  gap: 8
};

const pillStyle: React.CSSProperties = {
  display: "inline-flex",
  alignItems: "center",
  padding: "4px 10px",
  borderRadius: 999,
  fontSize: 12,
  fontWeight: 600,
  backgroundColor: "rgba(131, 63, 29, 0.08)",
  color: "#7c3f1d"
};

export function ProjectCard({ project }: ProjectCardProps) {
  const progressLabel = `${project.progressCompleted} / ${project.progressTotal}`;

  return (
    <article style={surfaceStyle}>
      <div style={{ display: "grid", gap: 6 }}>
        <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
          <div>
            <div style={{ fontSize: 12, color: "#8a6a52", letterSpacing: "0.08em" }}>
              {project.id}
            </div>
            <h3 style={{ margin: "4px 0 0", fontSize: 24, color: "#2f2016" }}>{project.displayName}</h3>
          </div>
          <span style={{ ...pillStyle, backgroundColor: "rgba(44, 112, 68, 0.12)", color: "#245b36" }}>
            {project.syncStatus}
          </span>
        </div>
        <div style={{ color: "#5b4332", fontSize: 15 }}>
          {project.currentFeatureTitle ?? "暂无当前功能"}
        </div>
      </div>

      <div style={metaRowStyle}>
        <span style={pillStyle}>{project.ownerRunner}</span>
        <span style={pillStyle}>{project.lifecycleStage ?? "unknown"}</span>
        <span style={pillStyle}>{progressLabel}</span>
        {project.handoffPending ? (
          <span style={{ ...pillStyle, backgroundColor: "rgba(179, 91, 33, 0.16)" }}>
            handoff pending
          </span>
        ) : null}
      </div>

      <div style={{ display: "grid", gap: 4 }}>
        <div style={{ fontSize: 13, color: "#7d5b44" }}>current feature</div>
        <div style={{ fontSize: 16, color: "#2f2016" }}>{project.currentFeatureSlug ?? "—"}</div>
      </div>

      <div style={{ display: "grid", gap: 4 }}>
        <div style={{ fontSize: 13, color: "#7d5b44" }}>worktree</div>
        <div style={{ fontSize: 14, color: "#5b4332", wordBreak: "break-all" }}>
          {project.worktreePath ?? "未绑定"}
        </div>
      </div>
    </article>
  );
}
