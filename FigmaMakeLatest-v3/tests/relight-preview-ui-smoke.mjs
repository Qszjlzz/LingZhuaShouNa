import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const { chromium } = await import(process.env.SMARTPAW_PLAYWRIGHT ?? 'playwright');
const project = fileURLToPath(new URL('../', import.meta.url));
const evidence = process.env.SMARTPAW_QA_OUTPUT ?? path.join(project, '../outputs/relight-preview-ui-20261023');
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
      const image = color => 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="900" height="600"><rect width="900" height="600" fill="' + color + '"/></svg>');
      const before = image('#bda280'), after = image('#66aa88');
      const items = [{ id: 'book', name: '课本', category: '书籍', confidence: 1, suggestedZone: '书架', isSelected: true }];
      const state = { selectedSpaceID: 'p3', scannedItems: items, spaces: [{ id: 'p3', name: '厨房', subtitle: '', detectedItems: items, activePlan: { id: 'old-plan', summary: '保留旧方案的常用位置', timeBudget: 10, style: '快速复原', steps: [] }, completedPlans: [] }], achievements: [], communityCases: [], comments: {}, liked: [], favorites: [], followedAuthors: [], schedules: [] };
      const fixture = window.__relightFixture = { calls: [], state, configured: true, delayNext: false, failNext: false, queued: [], before, after };
      const cache = new Map(JSON.parse(localStorage.getItem('qa.relight-preview-cache') || '[]'));
      window.webkit = { messageHandlers: { smartpaw: { postMessage(message) {
        fixture.calls.push(message);
        const send = (data, error) => window.__smartPawReceive?.({ requestId: message.requestId, status: error ? 'error' : 'success', error, data });
        queueMicrotask(() => {
          const key = JSON.stringify(message.payload);
          if (message.command === 'image.settings.get') return send({ configured: fixture.configured });
          if (message.command === 'space.photos') return send(message.payload.id === 'p3' ? { before } : {});
          if (message.command === 'chat.send') return send({ reply: '已记录这项调整，请生成效果图核对。' });
          if (message.command === 'image.preview.restore') return send(cache.has(key) ? { available: true, preview: cache.get(key) } : { available: false });
          if (message.command === 'image.preview.generate') {
            const complete = () => { cache.set(key, after); localStorage.setItem('qa.relight-preview-cache', JSON.stringify([...cache])); send({ preview: after }); };
            if (fixture.failNext) { fixture.failNext = false; return send(undefined, '测试生图失败'); }
            if (fixture.delayNext) { fixture.delayNext = false; fixture.queued.push(complete); return; }
            return complete();
          }
          if (message.command === 'image.preview.cancel') return send({ cancelled: true });
          return send(state);
        });
      } } } };
    });
    const page = await context.newPage();
    page.on('pageerror', error => errors.push({ width, error: error.message }));
    const base = 'http://127.0.0.1:' + server.address().port;
    await page.goto(base + '/?relight=tune', { waitUntil: 'domcontentloaded' });
    const input = page.getByPlaceholder('告诉我想怎么调整…');
    const say = async text => { await input.fill(text); await input.press('Enter'); await page.getByRole('button', { name: /生成当前方案效果图/ }).waitFor(); };
    await say('保留台灯位置');
    await say('书本留在右边');
    assert.equal(await page.getByRole('button', { name: /确认效果图，继续整理/ }).count(), 0);
    assert.equal(await page.evaluate(() => window.__relightFixture.calls.filter(c => c.command === 'image.preview.generate').length), 0);
    await page.getByRole('button', { name: /生成当前方案效果图/ }).click();
    await page.getByRole('button', { name: /确认效果图，继续整理/ }).waitFor();
    const payload = await page.evaluate(() => window.__relightFixture.calls.filter(c => c.command === 'image.preview.generate').at(-1).payload);
    assert.ok(payload.goal.startsWith('保留旧方案的常用位置'));
    for (const preference of ['保留台灯位置', '书本留在右边']) { assert.ok(payload.goal.includes(preference)); assert.ok(payload.changes.includes('用户调整：' + preference)); }
    assert.ok(await page.evaluate(() => window.__relightFixture.calls.filter(c => c.command === 'space.photos').every(c => c.payload.id === 'p3')));
    await page.getByRole('button', { name: '对比整理前照片', exact: true }).click();
    await page.getByAltText('整理前照片', { exact: true }).waitFor();
    await page.getByRole('button', { name: '查看当前效果图', exact: true }).click();
    checks.push({ width, check: 'Relight tune renders without error, retains before photo, sends all preferences and requires current preview', passed: true });
    await say('水杯放在左边');
    await page.evaluate(() => { window.__relightFixture.delayNext = true; });
    await page.getByRole('button', { name: /生成当前方案效果图/ }).click();
    await page.getByRole('button', { name: '取消生成效果图', exact: true }).waitFor();
    await say('手机保留在右边');
    await page.evaluate(() => window.__relightFixture.queued.splice(0).forEach(done => done()));
    assert.equal(await page.getByRole('button', { name: /确认效果图，继续整理/ }).count(), 0);
    await page.evaluate(() => { window.__relightFixture.failNext = true; });
    await page.getByRole('button', { name: /生成当前方案效果图/ }).click();
    await page.getByRole('alert').filter({ hasText: '测试生图失败' }).waitFor();
    await page.getByRole('button', { name: /重试生成效果图/ }).click();
    await page.getByRole('button', { name: /确认效果图，继续整理/ }).waitFor();
    await page.screenshot({ path: path.join(evidence, width + '-relight-tune-confirm.png') });
    await page.getByRole('button', { name: /确认效果图，继续整理/ }).click();
    await page.getByText('选择整理分区', { exact: true }).waitFor();
    checks.push({ width, check: 'Relight tune ignores cancelled stale result, shows retryable failure and advances only on explicit confirmation', passed: true });
    await page.goto(base + '/?relight=choice');
    await page.getByRole('button', { name: /探索全新整理风格/ }).click();
    const generate = () => page.getByRole('button', { name: '生成效果图', exact: true });
    await generate().waitFor();
    await page.getByRole('button', { name: '左上区域', exact: true }).click();
    await generate().click();
    await page.getByText('AI 左上区域整理效果预览', { exact: true }).waitFor();
    const region = await page.evaluate(() => window.__relightFixture.calls.filter(c => c.command === 'image.preview.generate').at(-1).payload);
    assert.deepEqual(region.focusRect, { x: 0, y: 0, width: 0.5, height: 0.5 });
    await page.getByRole('button', { name: '查看原图', exact: true }).click();
    await page.getByAltText('整理前照片', { exact: true }).waitFor();
    await page.getByRole('button', { name: '查看效果图', exact: true }).click();
    await page.getByRole('button', { name: '整体', exact: true }).click();
    await generate().waitFor();
    await page.getByRole('button', { name: '左上区域', exact: true }).click();
    await page.getByText('AI 左上区域整理效果预览', { exact: true }).waitFor();
    assert.equal(await page.evaluate(() => window.__relightFixture.calls.filter(c => c.command === 'image.preview.generate').length), 1);
    await page.screenshot({ path: path.join(evidence, width + '-relight-region-restored.png') });
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    checks.push({ width, check: 'Relight new plan supports manual regions, full request, original comparison and region cache restoration without extra generate', passed: true });
    await page.getByRole('button', { name: '整体', exact: true }).click();
    await generate().waitFor();
    await page.evaluate(() => { window.__relightFixture.state.selectedSpaceID = 'other'; });
    const countBefore = await page.evaluate(() => window.__relightFixture.calls.filter(c => c.command === 'image.preview.generate').length);
    await generate().click();
    await page.getByRole('alert').filter({ hasText: '空间已改变' }).waitFor();
    assert.equal(await page.evaluate(() => window.__relightFixture.calls.filter(c => c.command === 'image.preview.generate').length), countBefore);
    checks.push({ width, check: 'Relight rejects changed selected space before native generation', passed: true });
    await page.goto(base + '/?relight=tune');
    await input.waitFor();
    await say('仅测试未配置服务');
    await page.evaluate(() => { window.__relightFixture.configured = false; });
    await page.getByRole('button', { name: /生成当前方案效果图/ }).click();
    await page.getByRole('alert').filter({ hasText: '服务尚未配置' }).waitFor();
    assert.equal(await page.evaluate(() => window.__relightFixture.calls.filter(c => c.command === 'image.preview.generate').length), 0);
    await page.getByRole('button', { name: '先使用文字方案继续整理', exact: true }).click();
    await page.getByText('选择整理分区', { exact: true }).waitFor();
    checks.push({ width, check: 'Unconfigured service offers explicit text-plan continuation without claiming image confirmation or uploading', passed: true });
    await context.close();
  }
  assert.equal(errors.length, 0);
  await writeFile(path.join(evidence, 'results.json'), JSON.stringify({ environment: 'Desktop Chromium, synthetic SVG photos and native bridge fixture; no real network provider or iPhone', checks, errors }, null, 2));
  console.log(JSON.stringify({ checks, errors }, null, 2));
} catch (error) {
  for (const context of browser.contexts()) for (const page of context.pages()) { await page.screenshot({ path: path.join(evidence, 'failure.png') }); console.log((await page.locator('body').innerText()).slice(0, 5000)); }
  throw error;
} finally { await browser.close(); server.close(); }
