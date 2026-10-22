import test from "node:test";
import assert from "node:assert/strict";
import { inferSpaceKind, normalizeSpaceLayout, parseSpaceLayouts, pointerDelta, spaceFootprint } from "../src/app/spaceLayout.ts";

const fallback = { skin: "bed", shape: "original", width: 138, height: 138, x: 40, y: 60, rot: 0, scale: 1, vivid: "#DDF3F3" };

test("legacy v1 positions and proportional scaling survive migration", () => {
  const layouts = parseSpaceLayouts('{"abc":{"x":21,"y":30,"rot":0,"scale":1.2,"vivid":"#ABCDEF"}}');
  const result = normalizeSpaceLayout(layouts.abc, fallback);
  assert.equal(result.x, 21);
  assert.equal(result.scale, 1.2);
  assert.equal(result.skin, "bed");
  assert.equal(result.shape, "original");
  assert.equal(result.width, 138);
});

test("saved template and dimensions survive rename and a JSON round trip", () => {
  const value = { ...fallback, skin: "drawer", shape: "rounded", width: 183, height: 76, rot: 270 };
  const saved = parseSpaceLayouts(JSON.stringify({ room: value }));
  const result = normalizeSpaceLayout(saved.room, { ...fallback, skin: inferSpaceKind("卧室") });
  assert.deepEqual(result, value);
});

test("legacy automatically stored colours migrate while chosen colours remain", () => {
  assert.equal(normalizeSpaceLayout({ x: 40, y: 60, vivid: "#A6B2D6" }, fallback).vivid, fallback.vivid);
  assert.equal(normalizeSpaceLayout({ x: 40, y: 60, vivid: "#ECC079" }, fallback).vivid, "#ECC079");
  assert.equal(normalizeSpaceLayout({ ...fallback, vivid: "#A6B2D6" }, fallback).vivid, "#A6B2D6");
});

test("invalid shape, template, nonfinite coordinates and unsafe colours fall back", () => {
  const result = normalizeSpaceLayout({ skin: "unknown", shape: "path", width: Infinity, height: NaN, x: NaN, y: -Infinity, rot: Infinity, scale: NaN, vivid: "url(https://example.com)" }, fallback);
  assert.deepEqual(result, fallback);
});

test("rotated pieces use their visible bounding box to stay in the map", () => {
  const result = normalizeSpaceLayout({ ...fallback, width: 220, height: 74, rot: 90, x: 999, y: 999 }, fallback);
  assert.deepEqual(spaceFootprint(result), { width: 74, height: 220 });
  assert.equal(result.x, 278);
  assert.equal(result.y, 182);
});

test("oversized layouts fit without negative or overflowing positions", () => {
  const result = normalizeSpaceLayout({ width: 9999, height: 9999, scale: 999, rot: -90, x: -50, y: 999 }, fallback);
  const size = spaceFootprint(result);
  assert.equal(result.rot, 270);
  assert.ok(size.width <= 346 && size.height <= 396);
  assert.ok(result.x >= 6 && result.y >= 6);
  assert.ok(result.x + size.width <= 352 && result.y + size.height <= 402);
});

test("pointer movement stays in logical coordinates inside a scaled phone frame", () => {
  assert.deepEqual(pointerDelta(160, 130, 100, 100, 358, 408, 716, 816), { x: 30, y: 15 });
  assert.deepEqual(pointerDelta(130, 115, 100, 100, 358, 408, 179, 204), { x: 60, y: 30 });
});

test("malformed storage and prototype entries cannot become layouts", () => {
  for (const value of [null, "null", "[]", "broken", "42"]) assert.deepEqual(parseSpaceLayouts(value), {});
  const layouts = parseSpaceLayouts('{"__proto__":{"x":99},"constructor":{},"valid":{"x":10},"bad":[] }');
  assert.deepEqual(Object.keys(layouts), ["valid"]);
});

test("templates cover furniture and small organizing areas without creating spaces", () => {
  assert.equal(inferSpaceKind("办公桌"), "desk");
  assert.equal(inferSpaceKind("床头抽屉"), "drawer");
  assert.equal(inferSpaceKind("衣柜"), "shelf");
  assert.equal(inferSpaceKind("洗手台"), "counter");
  assert.equal(inferSpaceKind("玄关角落"), "area");
});
