import test from "node:test";
import assert from "node:assert/strict";
import { PREVIEW_SCOPES, imagePreviewRequest, imagePreviewPlanKey } from "../src/app/imagePreview.ts";

const plan = { id: "plan-one", name: "快速整理", vibe: "保留所有物品", changes: ["同类集中"] };

test("whole and physical photo regions have independent preview identities", () => {
  assert.equal(new Set(PREVIEW_SCOPES.map((scope) => imagePreviewPlanKey(plan, scope))).size, 5);
  assert.equal(imagePreviewRequest(plan).planID, plan.id);
  assert.equal(imagePreviewRequest(plan).focusZone, "");
  assert.notEqual(imagePreviewPlanKey(plan), imagePreviewPlanKey({ ...plan, changes: ["设备归位"] }));
});

test("four explicit source regions cover the photo exactly once", () => {
  for (const x of [0.25, 0.75]) for (const y of [0.25, 0.75]) {
    const covering = PREVIEW_SCOPES.filter(({ rect }) => rect && x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y + rect.height);
    assert.equal(covering.length, 1);
  }
  const request = imagePreviewRequest(plan, PREVIEW_SCOPES[2]);
  assert.match(request.focusZone, /x=0.5 至 1、y=0 至 0.5/);
  assert.match(request.focusZone, /保持整个原画幅/);
  assert.match(request.focusZone, /矩形外的物品及位置保持原样/);
  assert.deepEqual(request.changes, plan.changes);
});
