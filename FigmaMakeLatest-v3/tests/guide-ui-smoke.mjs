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
async function setup(state) {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
  await context.route("https://images.unsplash.com/**", (route) => route.fulfill({ path: path.join(project, "../Resources/ExternalScanTests/external-cluttered-study-pexels.jpg"), contentType: "image/jpeg" }));
  await context.addInitScript(({ initialState }) => {
    const fixture = window.__guideFixture = {
      state: JSON.parse(localStorage.getItem("test.guide.native-state") || "null") || initialState,
      calls: [], failNext: false, savedSteps: 0,
    };
    window.webkit = { messageHandlers: { smartpaw: { postMessage(message) {
      fixture.calls.push(message);
      queueMicrotask(() => {
        let error;
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
        }
        window.__smartPawReceive?.({ requestId: message.requestId, status: error ? "error" : "success", error, data: structuredClone(fixture.state) });
      });
    } } } };
  }, { initialState: state });
  const page = await context.newPage();
  page.on("pageerror", (error) => errors.push(error.message));
  await page.goto(`${address}/?flow=arguide`);
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
  assert.deepEqual(errors, []);
  const result = { status: "passed", viewport: "390x844", source: "production dist with simulated native bridge; not a Swift persistence or real-camera test", checks, pageErrors: errors };
  await writeFile(path.join(evidence, "result.json"), `${JSON.stringify(result, null, 2)}\n`);
  console.log(JSON.stringify(result, null, 2));
} finally {
  await browser?.close();
  await new Promise((resolve) => server.close(resolve));
}
