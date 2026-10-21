import assert from "node:assert/strict";
import { createServer } from "node:http";
import { createRequire } from "node:module";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Optional integration check: requires Playwright and an installed Chromium/Chrome.
const { chromium } = createRequire(import.meta.url)("playwright");
const project = fileURLToPath(new URL("../", import.meta.url));
const root = path.join(project, "dist");
const evidence = process.env.SMARTPAW_EVIDENCE_DIR || path.join(project, "../outputs/guide-ui-smoke");
await mkdir(evidence, { recursive: true });
const server = createServer(async (request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
  const target = path.resolve(root, `.${pathname === "/" ? "/index.html" : pathname}`);
  if (!target.startsWith(`${root}${path.sep}`)) { response.writeHead(403).end(); return; }
  try {
    const bytes = await readFile(target);
    response.setHeader("Content-Type", target.endsWith(".js") ? "application/javascript" : target.endsWith(".css") ? "text/css" : "text/html");
    response.end(bytes);
  } catch { response.writeHead(404).end(); }
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const address = `http://127.0.0.1:${server.address().port}`;
let browser;
const errors = [];
const checks = [];
const item = (id, category, name) => ({ id, name, category, confidence: 1, suggestedZone: "固定收纳位", isSelected: true });
const items = [item("book-1", "书籍", "课本一"), item("book-2", "书籍", "课本二"), item("book-3", "书籍", "课本三"), item("device-1", "电子产品", "电脑"), item("pen-1", "文具", "铅笔")];
const plan = {
  id: "fixture-plan", style: "快速复原", timeBudget: 10, summary: "流程测试", toolList: [],
  steps: [
    { id: "books", title: "书本竖放归位", detail: "将课本放回书架。", zone: "书架", status: "active", itemIDs: ["book-1", "book-2", "book-3"] },
    { id: "devices", title: "设备集中归位", detail: "整理设备线缆。", zone: "充电区", status: "pending", itemIDs: ["device-1"] },
    { id: "pens", title: "文具集中入盒", detail: "将文具分类收好。", zone: "文具盒", status: "pending", itemIDs: ["pen-1"] },
  ],
};
function stateFor(activePlan, detectedItems) {
  return {
    selectedSpaceID: "fixture-space", scannedItems: detectedItems,
    spaces: [{ id: "fixture-space", name: "测试书桌", subtitle: "测试数据", detectedItems, activePlan, completedPlans: [] }],
    achievements: [], communityCases: [], comments: {}, liked: [], favorites: [], followedAuthors: [], schedules: [],
  };
}
async function setup(state, flow = "arguide", options = {}) {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
  await context.route("https://images.unsplash.com/**", (route) => route.fulfill({ path: path.join(project, "../Resources/ExternalScanTests/external-cluttered-study-pexels.jpg"), contentType: "image/jpeg" }));
  await context.addInitScript(({ initialState, options }) => {
    const fixture = window.__guideFixture = {
      state: JSON.parse(localStorage.getItem("test.guide.native-state") || "null") || initialState,
      calls: [], failNext: false, savedSteps: 0,
      cancelNextPicker: false, failNextProofCommit: false,
      proofStaged: false, proofCancels: 0, proofCommits: 0, archivedProofs: 0,
      previewDelay: options.previewDelay || 0,
    };
    window.webkit = { messageHandlers: { smartpaw: { postMessage(message) {
      fixture.calls.push(message);
      if (message.command === "camera.preview.start" && fixture.previewDelay) {
        setTimeout(() => window.__smartPawReceive?.({ requestId: message.requestId, status: "success", data: { ok: false, reason: "unavailable" } }), fixture.previewDelay);
        return;
      }
      queueMicrotask(() => {
        let error;
        let status = "success";
        let data;
        if (message.command === "plan.step.complete") {
          const plan = fixture.state.spaces[0].activePlan;
          const step = plan.steps.find((candidate) => candidate.status === "active");
          if (fixture.failNext) { fixture.failNext = false; error = "测试保存失败，请重试"; }
          else if (!step || step.id !== message.payload.id) error = "测试步骤状态无效";
          else {
            step.status = "done";
            const next = plan.steps.find((candidate) => candidate.status === "pending");
            if (next) next.status = "active";
            fixture.savedSteps += 1;
            localStorage.setItem("test.guide.native-state", JSON.stringify(fixture.state));
          }
        } else if (message.command === "camera.preview.start") {
          data = { ok: true };
        } else if (message.command === "camera.preview.stop" || message.command === "camera.preview.frame") {
          data = { ok: true };
        } else if (message.command === "camera.capture") {
          fixture.proofStaged = true;
          data = { preview: "https://images.unsplash.com/photo-1749705319317-f9a2bf24fe3d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080" };
        } else if (message.command === "capture.open") {
          if (fixture.cancelNextPicker) {
            fixture.cancelNextPicker = false;
            status = "cancelled";
          } else {
            fixture.proofStaged = true;
            data = { preview: "https://images.unsplash.com/photo-1749705319317-f9a2bf24fe3d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080" };
          }
        } else if (message.command === "capture.after.cancel") {
          fixture.proofCancels += 1;
          fixture.proofStaged = false;
          data = { cancelled: true };
        } else if (message.command === "capture.after.commit") {
          fixture.proofCommits += 1;
          if (fixture.failNextProofCommit) {
            fixture.failNextProofCommit = false;
            error = "测试完成照保存失败，请重试";
          } else {
            fixture.archivedProofs += 1;
            fixture.proofStaged = false;
            const space = fixture.state.spaces[0];
            space.completedPlans.push(space.activePlan);
            delete space.activePlan;
          }
        }
        data ??= structuredClone(fixture.state);
        window.__smartPawReceive?.({ requestId: message.requestId, status: error ? "error" : status, error, data });
      });
    } } } };
  }, { initialState: state, options });
  const page = await context.newPage();
  page.on("pageerror", (error) => errors.push(error.message));
  await page.goto(flow ? `${address}/?flow=${flow}` : address);
  return { context, page };
}
async function visibleText(page, text) {
  await page.getByText(text, { exact: false }).first().waitFor({ state: "visible" });
}
async function savedSteps(page) { return page.evaluate(() => window.__guideFixture.savedSteps); }
async function screenshot(page, filename) { await page.screenshot({ path: path.join(evidence, filename) }); }

try {
  browser = await chromium.launch({
    ...(process.env.SMARTPAW_CHROME_PATH ? { executablePath: process.env.SMARTPAW_CHROME_PATH } : {}),
    headless: true,
  });
  const { context, page } = await setup(stateFor(plan, items));
  await visibleText(page, "清理收纳区域");
  await visibleText(page, "Step 1/5");
  await screenshot(page, "01-prepare.png");
  await page.getByRole("button", { name: "下一步", exact: true }).click();
  await visibleText(page, "Step 2/5");
  const classification = page.getByRole("list", { name: "物品分类卡" });
  assert.equal(await classification.getByRole("listitem").count(), 3);
  assert.match(await classification.innerText(), /3 件/);
  assert.equal(await savedSteps(page), 0);
  await screenshot(page, "02-classify.png");
  await page.getByRole("button", { name: "复核", exact: true }).click();
  await visibleText(page, "物品复核");
  assert.equal(await page.getByRole("button", { name: "查看整理成果", exact: true }).count(), 0);
  await screenshot(page, "03-review-before-work.png");
  await page.getByRole("button", { name: "返回继续整理", exact: true }).click();
  assert.equal(await savedSteps(page), 0);
  await page.reload();
  await visibleText(page, "Step 2/5");
  checks.push("Fresh plan reaches cleaning/classification/review; reviewing and reload do not complete native steps.");
  await page.getByRole("button", { name: "跳过", exact: true }).click();
  await visibleText(page, "Step 3/5");
  assert.equal(await savedSteps(page), 0);
  await page.reload();
  await visibleText(page, "Step 3/5");
  await page.evaluate(() => { window.__guideFixture.failNext = true; });
  await page.getByRole("button", { name: "下一步", exact: true }).click();
  await visibleText(page, "测试保存失败");
  await visibleText(page, "Step 3/5");
  assert.equal(await savedSteps(page), 0);
  await screenshot(page, "04-save-failure.png");
  await page.getByRole("button", { name: "下一步", exact: true }).click();
  await visibleText(page, "Step 4/5");
  assert.equal(await savedSteps(page), 1);
  await page.getByRole("button", { name: "下一步", exact: true }).click();
  await visibleText(page, "Step 5/5");
  await page.getByRole("button", { name: "完成收纳", exact: true }).click();
  await visibleText(page, "整理步骤已完成");
  assert.equal(await savedSteps(page), 3);
  await page.getByRole("button", { name: "继续", exact: true }).click();
  await visibleText(page, "整理清单");
  await screenshot(page, "05-completed-checklist.png");
  await page.getByRole("button", { name: "查看整理成果", exact: true }).waitFor({ state: "visible" });
  const archives = await page.evaluate(() => window.__guideFixture.calls.filter((call) => /plan.finish|proof.confirm/.test(call.command)).length);
  assert.equal(archives, 0);
  await page.reload();
  await visibleText(page, "整理步骤已完成");
  checks.push("Skipping preflight changes no native completion; failed save stays retryable; each successful UUID advances once; completion restores after reload and is not archived without a photo.");
  await context.close();

  const categories = ["书籍", "电子产品", "文具", "衣物", "玩偶杂物", "待丢弃", "收纳工具", "厨房", "饮品", "健康", "装饰"];
  const longItems = categories.map((category, index) => item(`item-${index}`, category, `物品${index + 1}`));
  const longPlan = { ...plan, id: "long-plan", steps: categories.map((category, index) => ({
    id: `step-${index}`, title: `整理${category}`, detail: `将${category}归位。`, zone: "固定收纳位",
    status: index === 0 ? "active" : "pending", itemIDs: [`item-${index}`],
  })) };
  const long = await setup(stateFor(longPlan, longItems));
  await visibleText(long.page, "清理收纳区域");
  await long.page.getByRole("button", { name: "下一步", exact: true }).click();
  const longCards = long.page.getByRole("list", { name: "物品分类卡" });
  assert.equal(await longCards.getByRole("listitem").count(), 11);
  const widths = await longCards.getByRole("listitem").evaluateAll((cards) => cards.map((card) => card.getBoundingClientRect().width));
  assert.ok(widths.every((width) => width >= 100));
  assert.equal(await long.page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  await screenshot(long.page, "06-eleven-classification-groups.png");
  await long.context.close();

  longPlan.steps.forEach((step, index) => { step.status = index < 10 ? "done" : "active"; });
  const resumed = await setup(stateFor(longPlan, longItems));
  await visibleText(resumed.page, "Step 13/13");
  const active = resumed.page.getByRole("list", { name: "归位分组" }).locator('[data-guide-current="true"]');
  await active.waitFor({ state: "visible" });
  const activeBounds = await active.boundingBox();
  assert.ok(activeBounds.x >= 0 && activeBounds.x + activeBounds.width <= 390);
  await screenshot(resumed.page, "07-restored-last-group.png");
  await resumed.context.close();
  checks.push("Eleven groups retain readable cards without page overflow; resuming the final group scrolls its active card into view.");

  const rewardPlan = structuredClone(plan);
  rewardPlan.steps.forEach((step) => { step.status = "done"; });
  const rewardState = stateFor(rewardPlan, items);
  const reward = await setup(rewardState, "reward");
  await visibleText(reward.page, "拍摄完成后的照片");
  assert.equal(await reward.page.getByRole("button", { name: "稍后完成", exact: true }).count(), 0);
  await screenshot(reward.page, "08-reward-camera.png");
  await reward.page.evaluate(() => { window.__guideFixture.cancelNextPicker = true; });
  await reward.page.getByRole("button", { name: "从相册选择完成照", exact: true }).click();
  await reward.page.getByRole("button", { name: "拍摄完成照", exact: true }).waitFor({ state: "visible" });
  assert.equal(await reward.page.getByText("已取消", { exact: true }).count(), 0);
  assert.equal(await reward.page.evaluate(() => window.__guideFixture.archivedProofs), 0);

  await reward.page.getByRole("button", { name: "拍摄完成照", exact: true }).evaluate((button) => {
    button.click();
    button.click();
  });
  await reward.page.getByRole("button", { name: "查看成就", exact: true }).waitFor({ state: "visible" });
  assert.equal(await reward.page.evaluate(() => window.__guideFixture.proofStaged), true);
  assert.equal(await reward.page.evaluate(() => window.__guideFixture.archivedProofs), 0);
  assert.equal(await reward.page.evaluate(() => window.__guideFixture.calls.filter((call) => call.command === "camera.capture").length), 1);
  await screenshot(reward.page, "08-reward-photo-preview.png");
  await reward.page.getByRole("button", { name: "重新拍摄", exact: true }).click();
  await reward.page.getByRole("button", { name: "拍摄完成照", exact: true }).waitFor({ state: "visible" });
  assert.equal(await reward.page.evaluate(() => window.__guideFixture.proofStaged), false);
  assert.equal(await reward.page.evaluate(() => window.__guideFixture.proofCancels), 1);

  await reward.page.getByRole("button", { name: "从相册选择完成照", exact: true }).click();
  await reward.page.getByRole("button", { name: "查看成就", exact: true }).waitFor({ state: "visible" });
  assert.equal(await reward.page.evaluate(() => window.__guideFixture.archivedProofs), 0);
  await reward.page.evaluate(() => { window.__guideFixture.failNextProofCommit = true; });
  await reward.page.getByRole("button", { name: "查看成就", exact: true }).evaluate((button) => { button.click(); button.click(); });
  await visibleText(reward.page, "测试完成照保存失败，请重试");
  assert.equal(await reward.page.evaluate(() => window.__guideFixture.proofStaged), true);
  assert.equal(await reward.page.evaluate(() => window.__guideFixture.archivedProofs), 0);
  await screenshot(reward.page, "09-reward-commit-failure.png");
  await reward.page.getByRole("button", { name: "查看成就", exact: true }).click();
  await reward.page.getByRole("button", { name: "加入我的家", exact: true }).waitFor({ state: "visible" });
  await reward.page.waitForTimeout(500);
  assert.equal(await reward.page.evaluate(() => window.__guideFixture.proofStaged), false);
  assert.equal(await reward.page.evaluate(() => window.__guideFixture.archivedProofs), 1);
  assert.equal(await reward.page.evaluate(() => window.__guideFixture.proofCommits), 2);
  const completionCommands = await reward.page.evaluate(() => window.__guideFixture.calls.filter((call) => call.command === "camera.capture" || call.command === "capture.open").map((call) => call.payload.purpose));
  assert.deepEqual(completionCommands, ["after-preview", "after-preview", "after-preview"]);
  await screenshot(reward.page, "10-reward-archived.png");
  await reward.page.getByRole("button", { name: "加入我的家", exact: true }).click();
  await reward.page.getByRole("button", { name: "加入我的家", exact: true }).waitFor({ state: "hidden" });
  checks.push("Reward flow: picker cancel is silent; camera and library photos stay staged; retake cancels staging; failed archive can retry; 查看成就 archives once and opens the spatial-map achievement modal, which can be claimed.");
  await reward.context.close();

  const later = await setup(rewardState, "reward");
  await visibleText(later.page, "拍摄完成后的照片");
  await later.page.getByRole("button", { name: "从相册选择完成照", exact: true }).click();
  await visibleText(later.page, "对比整理前后");
  assert.equal(await later.page.evaluate(() => window.__guideFixture.proofStaged), true);
  await later.page.getByRole("button", { name: "稍后完成", exact: true }).click();
  await later.page.waitForFunction(() => window.__guideFixture.proofCancels >= 1);
  assert.equal(await later.page.evaluate(() => window.__guideFixture.archivedProofs), 0);
  assert.equal(await later.page.evaluate(() => window.__guideFixture.proofStaged), false);
  checks.push("Leaving an already staged reward preview with 稍后完成 cancels proof without archiving.");
  await later.context.close();

  const delayed = await setup(rewardState, "reward", { previewDelay: 350 });
  await visibleText(delayed.page, "拍摄完成后的照片");
  await delayed.page.mouse.move(5, 400);
  await delayed.page.mouse.down();
  await delayed.page.mouse.move(110, 400, { steps: 5 });
  await delayed.page.mouse.up();
  await delayed.page.waitForTimeout(1300);
  assert.equal(await delayed.page.evaluate(() => window.__guideFixture.calls.filter((call) => call.command === "camera.preview.start").length), 1);
  await delayed.context.close();
  checks.push("The completion-photo screen keeps the Figma camera layout, opens the library from its camera badge, and an edge-swipe exit cancels delayed camera retries.");

  for (const entry of ["project", "progress"]) {
    const route = await setup(rewardState, null);
    if (entry === "project") {
      await route.page.getByRole("button", { name: "项目", exact: true }).click();
      await route.page.getByRole("button", { name: "打开项目：流程测试", exact: true }).click();
      await route.page.getByRole("button", { name: "选择完成照", exact: true }).click();
    } else {
      await route.page.getByRole("button", { name: /测试书桌 · 待保存完成照/ }).click();
      await route.page.getByRole("button", { name: "保存完成照", exact: true }).click();
    }
    const review = route.page.getByRole("dialog", { name: "确认完成照", exact: true });
    await review.waitFor({ state: "visible" });
    assert.equal(await route.page.evaluate(() => window.__guideFixture.archivedProofs), 0);
    await review.getByRole("button", { name: "稍后完成", exact: true }).click();
    assert.equal(await route.page.evaluate(() => window.__guideFixture.proofStaged), false);
    if (entry === "project") await route.page.getByRole("button", { name: "选择完成照", exact: true }).click();
    else await route.page.getByRole("button", { name: "保存完成照", exact: true }).click();
    await review.waitFor({ state: "visible" });
    await route.page.evaluate(() => { window.__guideFixture.failNextProofCommit = true; });
    await review.getByRole("button", { name: "确认并保存", exact: true }).evaluate((button) => { button.click(); button.click(); });
    await visibleText(route.page, "测试完成照保存失败，请重试");
    assert.equal(await route.page.evaluate(() => window.__guideFixture.proofStaged), true);
    assert.equal(await route.page.evaluate(() => window.__guideFixture.proofCommits), 1);
    await screenshot(route.page, `11-${entry}-completion-preview.png`);
    await review.getByRole("button", { name: "确认并保存", exact: true }).click();
    await review.waitFor({ state: "hidden" });
    assert.equal(await route.page.evaluate(() => window.__guideFixture.archivedProofs), 1);
    assert.equal(await route.page.evaluate(() => window.__guideFixture.calls.filter((call) => call.command === "capture.open").every((call) => call.payload.purpose === "after-preview")), true);
    await route.context.close();
  }
  checks.push("Project and in-progress photo entry points stage, cancel, retry failed commits, and archive only after explicit confirmation; double commit clicks submit once.");

  assert.deepEqual(errors, []);
  const result = { status: "passed", viewport: "390x844", source: "production dist with simulated native bridge; not a Swift persistence or real-camera test", checks, pageErrors: errors };
  await writeFile(path.join(evidence, "result.json"), `${JSON.stringify(result, null, 2)}\n`);
  console.log(JSON.stringify(result, null, 2));
} finally {
  await browser?.close();
  await new Promise((resolve) => server.close(resolve));
}
