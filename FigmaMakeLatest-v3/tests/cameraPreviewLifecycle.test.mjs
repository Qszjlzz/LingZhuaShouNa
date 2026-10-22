import assert from "node:assert/strict";
import test from "node:test";
import { startCameraPreviewWithRetry } from "../src/app/cameraPreviewLifecycle.ts";

test("leaving the capture screen during retry prevents another native camera start", async () => {
  let active = true;
  let starts = 0;
  let stops = 0;
  const result = await startCameraPreviewWithRetry({
    isActive: () => active,
    start: async () => { starts += 1; active = false; return { ok: false, reason: "unavailable" }; },
    stop: () => { stops += 1; },
    sleep: async () => {},
  });
  assert.equal(result, null);
  assert.equal(starts, 1);
  assert.equal(stops, 0);
});

test("a late successful start is stopped after its capture screen unmounts", async () => {
  let active = true;
  let stops = 0;
  const result = await startCameraPreviewWithRetry({
    isActive: () => active,
    start: async () => { active = false; return { ok: true }; },
    stop: () => { stops += 1; },
    sleep: async () => {},
  });
  assert.equal(result, null);
  assert.equal(stops, 1);
});

test("an unavailable camera retries while active and stops immediately on permission denial", async () => {
  let starts = 0;
  const result = await startCameraPreviewWithRetry({
    isActive: () => true,
    start: async () => { starts += 1; return starts === 1 ? { ok: false, reason: "unavailable" } : { ok: false, reason: "denied" }; },
    stop: () => assert.fail("denied preview should not start/stop the camera"),
    sleep: async () => {},
  });
  assert.deepEqual(result, { ok: false, reason: "denied" });
  assert.equal(starts, 2);
});
