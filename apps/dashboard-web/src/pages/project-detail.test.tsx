import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { readFile } from "node:fs/promises";
import React from "react";
import { renderToStaticMarkup } from "react-dom/server";

import { ProjectDetailPage } from "./project-detail.tsx";
import type { ProjectDetail } from "../types.ts";

const fixturePath = path.resolve(process.cwd(), "../../tests/fixtures/dashboard-projects/project-detail.json");

test("ProjectDetailPage renders feature summary, handoff banner and read-only helper actions", async () => {
  const detail = JSON.parse(await readFile(fixturePath, "utf8")) as ProjectDetail;
  const html = renderToStaticMarkup(
    <ProjectDetailPage
      detail={detail}
      onBackHref="#/"
    />
  );

  assert.match(html, /CX 全局 Web 管理面板/);
  assert.match(html, /codex-exec-1/);
  assert.match(html, /\/worktrees\/cx-global-web-dashboard/);
  assert.match(html, /handoff pending/i);
  assert.match(html, /打开项目目录/);
  assert.match(html, /复制建议命令/);
  assert.match(html, /手动刷新/);
  assert.match(html, /任务 1/);
  assert.match(html, /任务 2/);
});
