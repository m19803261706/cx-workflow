import React from "react";

import type { ProjectDetail } from "../types.ts";

type FeatureSummaryProps = {
  detail: ProjectDetail;
};

const cardStyle: React.CSSProperties = {
  borderRadius: 22,
  backgroundColor: "rgba(255, 251, 246, 0.92)",
  border: "1px solid rgba(146, 102, 64, 0.16)",
  boxShadow: "0 16px 36px rgba(78, 44, 20, 0.08)",
  padding: 22,
  display: "grid",
  gap: 16
};

export function FeatureSummary({ detail }: FeatureSummaryProps) {
  if (!detail.feature) {
    return (
      <section style={cardStyle}>
        <h2 style={{ margin: 0, fontSize: 24 }}>当前没有活跃 feature</h2>
      </section>
    );
  }

  const { feature } = detail;

  return (
    <section style={cardStyle}>
      <div style={{ display: "grid", gap: 6 }}>
        <div style={{ fontSize: 14, color: "#8c5e34", letterSpacing: "0.08em" }}>
          feature summary
        </div>
        <h2 style={{ margin: 0, fontSize: 28 }}>{feature.title}</h2>
        <div style={{ color: "#6b4d38" }}>{feature.slug}</div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))", gap: 14 }}>
        <div>
          <div style={{ fontSize: 13, color: "#8c5e34" }}>owner</div>
          <div>{feature.ownerRunner}</div>
          <div style={{ fontSize: 13, color: "#6b4d38" }}>{feature.ownerSessionId ?? "—"}</div>
        </div>
        <div>
          <div style={{ fontSize: 13, color: "#8c5e34" }}>phase</div>
          <div>{feature.workflowPhase ?? "—"}</div>
        </div>
        <div>
          <div style={{ fontSize: 13, color: "#8c5e34" }}>progress</div>
          <div>
            {feature.progress.completed} / {feature.progress.total}
          </div>
        </div>
        <div>
          <div style={{ fontSize: 13, color: "#8c5e34" }}>worktree</div>
          <div style={{ wordBreak: "break-all" }}>{feature.worktreePath ?? "未绑定"}</div>
          <div style={{ fontSize: 13, color: "#6b4d38" }}>{feature.bindingStatus ?? "—"}</div>
        </div>
      </div>

      <div style={{ display: "grid", gap: 8 }}>
        <div style={{ fontSize: 14, color: "#8c5e34" }}>tasks</div>
        {feature.tasks.map((task) => (
          <div
            key={task.id}
            style={{
              display: "flex",
              justifyContent: "space-between",
              gap: 12,
              borderTop: "1px solid rgba(146, 102, 64, 0.12)",
              paddingTop: 10
            }}
          >
            <div>
              <div>{task.title}</div>
              <div style={{ fontSize: 13, color: "#6b4d38" }}>
                phase {task.phase ?? "—"}{task.parallelGroup ? ` · ${task.parallelGroup}` : ""}
              </div>
            </div>
            <div style={{ fontWeight: 600 }}>{task.status}</div>
          </div>
        ))}
      </div>
    </section>
  );
}
