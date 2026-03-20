import React from "react";

type HandoffBannerProps = {
  visible: boolean;
};

export function HandoffBanner({ visible }: HandoffBannerProps) {
  if (!visible) {
    return null;
  }

  return (
    <div
      style={{
        borderRadius: 18,
        border: "1px solid rgba(179, 91, 33, 0.24)",
        backgroundColor: "rgba(255, 236, 214, 0.92)",
        color: "#8a431f",
        padding: "14px 16px",
        fontWeight: 600
      }}
    >
      handoff pending
    </div>
  );
}
