import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { readFile } from "node:fs/promises";
import React from "react";
import { renderToStaticMarkup } from "react-dom/server";

import { FeatureSummary } from "./feature-summary.tsx";
import type { ProjectDetail } from "../types.ts";

const fixturePath = path.resolve(process.cwd(), "../../tests/fixtures/dashboard-projects/project-detail.json");

test("FeatureSummary renders workflow summary, task matrix and owner status in Chinese", async () => {
  const detail = JSON.parse(await readFile(fixturePath, "utf8")) as ProjectDetail;
  const html = renderToStaticMarkup(<FeatureSummary detail={detail} />);

  assert.match(html, /工作流摘要/);
  assert.match(html, /当前执行权/);
  assert.match(html, /任务矩阵/);
  assert.match(html, /工作区绑定/);
  assert.match(html, /任务 1/);
  assert.match(html, /任务 2/);
});
