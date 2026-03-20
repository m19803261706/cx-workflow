import React from "react";

import { FeatureSummary } from "../components/feature-summary.tsx";
import { HandoffBanner } from "../components/handoff-banner.tsx";
import type { ProjectDetail } from "../types.ts";

type ProjectDetailPageProps = {
  detail: ProjectDetail;
  onBackHref: string;
};

const pageStyle: React.CSSProperties = {
  minHeight: "100vh",
  background:
    "radial-gradient(circle at top right, rgba(244,199,149,0.78), transparent 28%), linear-gradient(180deg, #fff8ef 0%, #f6ecdd 100%)",
  padding: "40px 32px 64px",
  fontFamily: "\"PingFang SC\", \"Hiragino Sans GB\", \"Microsoft YaHei\", sans-serif",
  color: "#2f2016",
  display: "grid",
  gap: 20
};

const helperBarStyle: React.CSSProperties = {
  display: "flex",
  flexWrap: "wrap",
  gap: 12
};

const helperButtonStyle: React.CSSProperties = {
  borderRadius: 999,
  border: "1px solid rgba(131, 63, 29, 0.18)",
  backgroundColor: "rgba(255, 251, 246, 0.92)",
  color: "#7c3f1d",
  padding: "10px 14px",
  fontWeight: 600
};

export function ProjectDetailPage({ detail, onBackHref }: ProjectDetailPageProps) {
  return (
    <div style={pageStyle}>
      <header style={{ display: "grid", gap: 10 }}>
        <a href={onBackHref} style={{ color: "#8c5e34", textDecoration: "none" }}>
          ← 返回项目列表
        </a>
        <div style={{ fontSize: 14, letterSpacing: "0.1em", color: "#8c5e34" }}>PROJECT DETAIL</div>
        <h1 style={{ margin: 0, fontSize: 40 }}>{detail.project.displayName}</h1>
        <div style={{ color: "#6b4d38" }}>{detail.project.rootPath}</div>
      </header>

      <HandoffBanner visible={detail.project.handoffPending || detail.feature?.handoffPending === true} />

      <div style={helperBarStyle}>
        <button type="button" style={helperButtonStyle}>
          打开项目目录
        </button>
        <button type="button" style={helperButtonStyle}>
          复制建议命令
        </button>
        <button type="button" style={helperButtonStyle}>
          手动刷新
        </button>
      </div>

      <FeatureSummary detail={detail} />

      <section
        style={{
          borderRadius: 22,
          backgroundColor: "rgba(255, 251, 246, 0.92)",
          border: "1px solid rgba(146, 102, 64, 0.16)",
          boxShadow: "0 16px 36px rgba(78, 44, 20, 0.08)",
          padding: 22,
          display: "grid",
          gap: 14
        }}
      >
        <h2 style={{ margin: 0, fontSize: 24 }}>active sessions</h2>
        {detail.activeSessions.map((session) => (
          <div key={session.sessionId} style={{ display: "grid", gap: 4 }}>
            <div style={{ fontWeight: 700 }}>{session.sessionId}</div>
            <div style={{ color: "#6b4d38" }}>
              {session.runner} · {session.branch}
            </div>
            <div style={{ color: "#6b4d38", wordBreak: "break-all" }}>{session.worktreePath}</div>
          </div>
        ))}
      </section>
    </div>
  );
}
