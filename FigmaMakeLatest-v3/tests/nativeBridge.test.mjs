import assert from "node:assert/strict";
import test from "node:test";

function bridgeWithFakeWindow() {
  const timers = [];
  const posted = [];
  globalThis.window = {
    setTimeout(callback, delay) { timers.push({ callback, delay }); return timers.length; },
    clearTimeout() {},
    webkit: { messageHandlers: { smartpaw: { postMessage(message) { posted.push(message); } } } },
  };
  return { timers, posted };
}

test("scan.await bridge deadline exceeds the native 300-second recognition deadline", async () => {
  const fake = bridgeWithFakeWindow();
  const { nativeRequest } = await import(`../src/app/nativeBridge.ts?test=${Date.now()}`);
  const request = nativeRequest("scan.await", { captureIDs: ["photo-1"] });
  assert.equal(fake.posted[0].command, "scan.await");
  assert.equal(fake.timers[0].delay, 330000);
  window.__smartPawReceive({ requestId: fake.posted[0].requestId, status: "error", error: "retry" });
  await assert.rejects(request, /retry/);
});

test("interactive photo picker keeps its bridge pending until the user responds", async () => {
  const fake = bridgeWithFakeWindow();
  const { nativeRequest } = await import(`../src/app/nativeBridge.ts?test=${Date.now()}`);
  const request = nativeRequest("capture.open", { source: "photo" });
  assert.equal(fake.timers.length, 0);
  window.__smartPawReceive({ requestId: fake.posted[0].requestId, status: "cancelled" });
  await assert.rejects(request, /已取消/);
});


test("visual disorder assessment allows the native 90-second request to finish", async () => {
  const fake = bridgeWithFakeWindow();
  const { nativeRequest } = await import('../src/app/nativeBridge.ts?test=disorder-' + Date.now());
  const request = nativeRequest("space.disorder.analyze", { spaceID: "space-1" });
  assert.equal(fake.timers[0].delay, 120000);
  window.__smartPawReceive({ requestId: fake.posted[0].requestId, status: "cancelled" });
  await assert.rejects(request, /已取消/);
});
