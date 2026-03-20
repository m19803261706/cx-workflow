import test from "node:test";
import assert from "node:assert/strict";
import React from "react";
import { renderToStaticMarkup } from "react-dom/server";

import { ProjectCard } from "./project-card.tsx";

test("ProjectCard renders display name, current feature, owner, lifecycle, worktree and progress summary", () => {
  const html = renderToStaticMarkup(
    <ProjectCard
      project={{
        id: "taichu",
        displayName: "太初八卦",
        currentFeatureSlug: "cx-global-web-dashboard",
        currentFeatureTitle: "CX 全局 Web 管理面板",
        lifecycleStage: "executing",
        ownerRunner: "codex",
        worktreePath: "/worktrees/cx-global-web-dashboard",
        progressCompleted: 2,
        progressTotal: 7,
        syncStatus: "healthy",
        handoffPending: true
      }}
    />
  );

  assert.match(html, /太初八卦/);
  assert.match(html, /CX 全局 Web 管理面板/);
  assert.match(html, /codex/i);
  assert.match(html, /executing/i);
  assert.match(html, /2 \/ 7/);
  assert.match(html, /\/worktrees\/cx-global-web-dashboard/);
  assert.match(html, /handoff pending/i);
});
