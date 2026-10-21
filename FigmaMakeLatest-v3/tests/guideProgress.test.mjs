import assert from "node:assert/strict";
import test from "node:test";
import { completeGuideNativeStep, groupsForNativePlan, guidePhaseKey, guideStartIndex } from "../src/app/guideProgress.ts";

const makePlan = () => ({
  id: "plan-1", style: "快速复原", timeBudget: 10, summary: "桌面整理", toolList: [],
  steps: [
    { id: "step-books", title: "书本归位", detail: "书本竖放", zone: "书架", status: "active", itemIDs: ["book-1", "book-2", "book-3"] },
    { id: "step-device", title: "设备归位", detail: "线缆入盒", zone: "充电区", status: "pending", itemIDs: ["device-1"] },
  ],
});
const makeState = (plan = makePlan()) => ({
  selectedSpaceID: "space-1", spaces: [{ id: "space-1", activePlan: plan }],
});
const bookItems = [1, 2, 3].map((n) => ({ id: `book-${n}`, name: `课本${n}`, category: "书籍" }));

test("new plans start at cleaning; each preflight phase can resume without completing work", () => {
  const plan = makePlan();
  assert.equal(guideStartIndex(plan), 0);
  assert.equal(guideStartIndex(plan, "classify"), 1);
  assert.equal(guideStartIndex(plan, "execute"), 2);
  assert.equal(plan.steps[0].status, "active");
});

test("native completion takes precedence over an old preflight phase", () => {
  const plan = makePlan();
  plan.steps[0].status = "done";
  plan.steps[1].status = "active";
  assert.equal(guideStartIndex(plan, "classify"), 3);
});

test("all-done plans restore the final displayed step", () => {
  const plan = makePlan();
  plan.steps.forEach((step) => { step.status = "done"; });
  assert.equal(guideStartIndex(plan), 3);
});

test("preflight storage is scoped to the exact plan ID", () => {
  assert.notEqual(guidePhaseKey("plan-1"), guidePhaseKey("plan-2"));
});

test("three manually added books remain three items in one classification group", () => {
  const groups = groupsForNativePlan(makePlan(), bookItems);
  assert.equal(groups[0].label, "书籍");
  assert.equal(groups[0].itemCount, 3);
  assert.deepEqual(groups[0].items, ["课本1", "课本2", "课本3"]);
});

test("a missing item association never borrows an unrelated item by array index", () => {
  const plan = makePlan();
  const groups = groupsForNativePlan(plan, [{ id: "unrelated", name: "台灯", category: "电子产品" }]);
  assert.deepEqual(groups[0].items, []);
  assert.equal(groups[0].label, "书本归位");
  assert.equal(groups[0].itemCount, 3);
  delete plan.steps[0].itemIDs;
  assert.equal(groupsForNativePlan(plan, bookItems)[0].itemCount, undefined);
});

test("duplicate item IDs are counted once, while same-category steps retain unique keys", () => {
  const plan = makePlan();
  plan.steps[0].itemIDs = ["book-1", "book-1"];
  plan.steps[1].itemIDs = ["book-2"];
  const groups = groupsForNativePlan(plan, bookItems);
  assert.equal(groups[0].itemCount, 1);
  assert.equal(groups[0].label, groups[1].label);
  assert.notEqual(groups[0].id, groups[1].id);
});

test("completing a step returns the saved native plan and advances exactly that UUID", async () => {
  const state = makeState();
  const updated = structuredClone(state);
  updated.spaces[0].activePlan.steps[0].status = "done";
  updated.spaces[0].activePlan.steps[1].status = "active";
  const calls = [];
  const result = await completeGuideNativeStep("plan-1", "step-books", async (command, payload) => {
    calls.push({ command, payload });
    return command === "state.get" ? state : updated;
  });
  assert.deepEqual(calls, [{ command: "state.get", payload: undefined }, { command: "plan.step.complete", payload: { id: "step-books" } }]);
  assert.equal(result.steps[0].status, "done");
  assert.equal(result.steps[1].status, "active");
  assert.equal(state.spaces[0].activePlan.steps[0].status, "active");
});

for (const [description, state, expectedPlan, expectedStep] of [
  ["a replaced plan", makeState(), "other-plan", "step-books"],
  ["a stale or future step", makeState(), "plan-1", "step-device"],
  ["a paused plan", makeState({ ...makePlan(), isPaused: true }), "plan-1", "step-books"],
  ["an invalid selected space", { ...makeState(), selectedSpaceID: "missing" }, "plan-1", "step-books"],
]) {
  test(`${description} is rejected before any completion request`, async () => {
    const calls = [];
    await assert.rejects(completeGuideNativeStep(expectedPlan, expectedStep, async (command) => {
      calls.push(command);
      return state;
    }));
    assert.deepEqual(calls, ["state.get"]);
  });
}

test("native save failures propagate so the current step can be retried", async () => {
  const state = makeState();
  await assert.rejects(completeGuideNativeStep("plan-1", "step-books", async (command) => {
    if (command === "state.get") return state;
    throw new Error("保存失败");
  }), /保存失败/);
  assert.equal(state.spaces[0].activePlan.steps[0].status, "active");
});

test("a success response without the saved done status cannot advance the UI", async () => {
  await assert.rejects(completeGuideNativeStep("plan-1", "step-books", async () => makeState()), /未读取到最新方案/);
});

test("switching spaces during a save cannot redirect the guide to another plan", async () => {
  const state = makeState();
  const updated = structuredClone(state);
  updated.spaces[0].activePlan.steps[0].status = "done";
  updated.selectedSpaceID = "other-space";
  await assert.rejects(completeGuideNativeStep("plan-1", "step-books", async (command) => command === "state.get" ? state : updated), /未读取到最新方案/);
});
