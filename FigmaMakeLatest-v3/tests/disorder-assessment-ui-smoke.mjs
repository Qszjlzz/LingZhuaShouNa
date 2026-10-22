import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const { chromium } = await import(process.env.SMARTPAW_PLAYWRIGHT ?? 'playwright');
const project = fileURLToPath(new URL('../', import.meta.url));
const evidence = process.env.SMARTPAW_QA_OUTPUT ?? path.join(project, '../docs/quality/disorder-assessment-ui-20261023');
await mkdir(evidence, { recursive: true });
const server = createServer(async (request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  const target = path.resolve(project, 'dist', '.' + (pathname === '/' ? '/index.html' : pathname));
  if (!target.startsWith(path.join(project, 'dist') + path.sep)) return response.writeHead(403).end();
  try { response.setHeader('Content-Type', target.endsWith('.js') ? 'application/javascript' : 'text/html'); response.end(await readFile(target)); }
  catch { response.writeHead(404).end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({ headless: true, executablePath: process.env.SMARTPAW_BROWSER_EXECUTABLE ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
const checks = [], errors = [];
try {
  for (const width of [390, 320]) {
    const context = await browser.newContext({ viewport: { width, height: 844 } });
    await context.addInitScript(() => {
      document.addEventListener('DOMContentLoaded', () => { const style = document.createElement('style'); style.textContent = 'html,body{margin:0;width:100%;height:100%;overflow:hidden}#root{position:absolute;inset:0;overflow:hidden}'; document.head.appendChild(style); });
      const photo = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="900" height="600"><rect width="900" height="600" fill="#bda280"/><rect x="270" y="180" width="360" height="180" fill="#9a7457"/></svg>');
      const items = Array.from({ length: 60 }, (_, index) => ({ id: 'book-' + index, name: '课本', category: '书籍', confidence: 1, suggestedZone: '书架', isSelected: true }));
      const state = { selectedSpaceID: 'p3', scannedItems: items, spaces: [{ id: 'p3', name: '厨房', subtitle: '', detectedItems: items, completedPlans: [] }], achievements: [], communityCases: [], comments: {}, liked: [], favorites: [], followedAuthors: [], schedules: [] };
      const fixture = window.__disorderFixture = { calls: [], state, mode: 'success', queued: [], photo };
      window.webkit = { messageHandlers: { smartpaw: { postMessage(message) {
        fixture.calls.push(message);
        const send = (data, error) => window.__smartPawReceive?.({ requestId: message.requestId, status: error ? 'error' : 'success', error, data });
        queueMicrotask(() => {
          if (message.command === 'camera.preview.start') return send({ ok: true });
          if (message.command === 'camera.capture') return send({ preview: photo });
          if (message.command === 'scan.results') return send({ ready: true, items });
          if (message.command === 'scan.await') return send({ items });
          if (message.command === 'space.photos') return send({ before: photo });
          if (message.command === 'space.disorder.cancel') return send({ cancelled: true });
          if (message.command === 'space.disorder.analyze') {
            const result = { score: 62, level: 'moderate', evidence: ['纸张相互堆叠，遮挡常用物品'], clutterRegions: [{ x: .3, y: .3, width: .4, height: .3, label: '纸张堆积' }], estimatedMinutes: 20, sourceSpaceID: 'p3' };
            if (fixture.mode === 'unconfigured') return send(undefined, '视觉评估服务尚未配置，请先完成设置');
            if (fixture.mode === 'fail') return send(undefined, '评估请求失败，请重试');
            if (fixture.mode === 'invalid') return send({ score: 50, sourceSpaceID: 'p3' });
            if (fixture.mode === 'wrong-space') return send({ ...result, sourceSpaceID: 'other' });
            if (fixture.mode === 'tidy') return send({ ...result, score: 8, level: 'tidy', evidence: ['60 件物品分类摆放，台面仍有充足可用空间'], clutterRegions: [], estimatedMinutes: 3 });
            if (fixture.mode === 'delay') { fixture.queued.push(() => send(result)); return; }
            return send(result);
          }
          return send(state);
        });
      } } } };
    });
    const page = await context.newPage();
    page.on('pageerror', error => errors.push({ width, error: error.message }));
    const base = 'http://127.0.0.1:' + server.address().port;
    const capture = async mode => {
      await page.goto(base + '/?relight=capture', { waitUntil: 'domcontentloaded' });
      await page.evaluate(value => { window.__disorderFixture.mode = value; }, mode);
      await page.locator('button[style*="width: 72px"]').click();
      await page.getByRole('button', { name: '提交', exact: true }).click();
      await page.getByTestId('disorder-analysis').waitFor();
      if (mode === 'delay') await page.waitForFunction(() => window.__disorderFixture.queued.length === 1);
    };
    await capture('delay');
    await page.getByText('正在分析照片中的空间状态…', { exact: true }).waitFor();
    await page.waitForTimeout(5700);
    assert.equal(await page.getByTestId('disorder-score').count(), 0);
    assert.equal(await page.getByTestId('disorder-region').count(), 0);
    assert.equal(await page.getByText('选择整理方式', { exact: true }).count(), 0);
    assert.deepEqual(await page.evaluate(() => window.__disorderFixture.calls.filter(call => call.command === 'space.disorder.analyze').map(call => call.payload)), [{ spaceID: 'p3' }]);
    await page.evaluate(() => window.__disorderFixture.queued.splice(0).forEach(done => done()));
    await page.getByTestId('disorder-score').waitFor();
    assert.match(await page.getByTestId('disorder-score').innerText(), /^62/);
    assert.equal(await page.getByTestId('disorder-region').count(), 1);
    await page.getByText('纸张相互堆叠，遮挡常用物品', { exact: true }).waitFor();
    await page.getByText('空间混乱度 · 主观视觉指数', { exact: true }).waitFor();
    await page.getByText('视觉评估完成', { exact: true }).waitFor();
    await page.getByRole('button', { name: '继续选择整理方式', exact: true }).click({ trial: true });
    await page.screenshot({ path: path.join(evidence, width + '-model-result.png') });
    await page.getByRole('button', { name: '继续选择整理方式', exact: true }).click();
    await page.getByText('选择整理方式', { exact: true }).waitFor();
    checks.push({ width, check: 'Actual capture route waits beyond the old fake timer and displays only returned score, evidence and rectangle; explicit continue', passed: true });

    await capture('tidy');
    await page.getByTestId('disorder-score').waitFor();
    assert.match(await page.getByTestId('disorder-score').innerText(), /^8/);
    await page.getByText('整齐有序', { exact: true }).waitFor();
    assert.equal(await page.getByTestId('disorder-region').count(), 0);
    assert.equal(await page.evaluate(() => window.__disorderFixture.state.scannedItems.length), 60);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await page.getByRole('button', { name: '继续选择整理方式', exact: true }).click({ trial: true });
    await page.screenshot({ path: path.join(evidence, width + '-tidy-many-items.png') });
    checks.push({ width, check: 'Sixty recognized items retain visually tidy 8/100 result with no invented clutter markers', passed: true });

    await capture('unconfigured');
    await page.getByRole('alert').filter({ hasText: '服务尚未配置' }).waitFor();
    assert.equal(await page.getByTestId('disorder-score').count(), 0);
    assert.equal(await page.getByTestId('disorder-region').count(), 0);
    await page.getByRole('button', { name: '重试照片评估', exact: true }).click({ trial: true });
    await page.screenshot({ path: path.join(evidence, width + '-unconfigured.png') });
    await page.evaluate(() => { window.__disorderFixture.mode = 'success'; });
    await page.getByRole('button', { name: '重试照片评估', exact: true }).click();
    await page.getByTestId('disorder-score').waitFor();
    checks.push({ width, check: 'Unconfigured service displays no numeric fallback and supports explicit retry to real response', passed: true });

    await capture('delay');
    await page.getByRole('button', { name: '取消评估，继续整理', exact: true }).click();
    await page.getByText('选择整理方式', { exact: true }).waitFor();
    assert.ok(await page.evaluate(() => window.__disorderFixture.calls.some(call => call.command === 'space.disorder.cancel')));
    await page.evaluate(() => window.__disorderFixture.queued.splice(0).forEach(done => done()));
    assert.equal(await page.getByTestId('disorder-score').count(), 0);
    await page.getByText('选择整理方式', { exact: true }).waitFor();
    checks.push({ width, check: 'Cancel issues native cancellation, leaves page immediately and ignores delayed completion', passed: true });

    await capture('delay');
    await page.evaluate(() => { window.__disorderFixture.state.selectedSpaceID = 'other'; window.__disorderFixture.queued.splice(0).forEach(done => done()); });
    await page.getByRole('alert').filter({ hasText: '空间已改变' }).waitFor();
    assert.equal(await page.getByTestId('disorder-score').count(), 0);
    assert.equal(await page.getByTestId('disorder-region').count(), 0);
    checks.push({ width, check: 'A changed selected space while awaiting assessment rejects delayed result', passed: true });

    for (const mode of ['fail', 'invalid', 'wrong-space']) {
      await capture(mode);
      await page.getByRole('alert').waitFor();
      assert.equal(await page.getByTestId('disorder-score').count(), 0);
      assert.equal(await page.getByTestId('disorder-region').count(), 0);
      await page.getByRole('button', { name: '跳过评估，继续整理', exact: true }).click();
      await page.getByText('选择整理方式', { exact: true }).waitFor();
    }
    checks.push({ width, check: 'Network failure, incomplete response and another-space result show unavailable and permit explicit skip without fake scoring', passed: true });
    await context.close();
  }
  assert.equal(errors.length, 0);
  await writeFile(path.join(evidence, 'results.json'), JSON.stringify({ environment: 'Desktop Chromium 390/320; synthetic SVG photo and native bridge fixture; production capture-to-relight route. No real model, provider network or iPhone.', checks, errors }, null, 2));
  console.log(JSON.stringify({ checks, errors }, null, 2));
} catch (error) {
  for (const context of browser.contexts()) for (const page of context.pages()) { await page.screenshot({ path: path.join(evidence, 'failure.png') }); console.log((await page.locator('body').innerText()).slice(0, 5000)); }
  throw error;
} finally { await browser.close(); server.close(); }
