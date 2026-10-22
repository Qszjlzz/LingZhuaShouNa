import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const { chromium } = await import(process.env.SMARTPAW_PLAYWRIGHT ?? 'playwright');
const project = fileURLToPath(new URL('../', import.meta.url));
const evidence = process.env.SMARTPAW_QA_OUTPUT ?? path.join(project, '../outputs/tune-preview-ui-20261023');
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
      const state = { selectedSpaceID: 'desk', scannedItems: items, spaces: [{ id: 'desk', name: '书桌', subtitle: '', detectedItems: items, completedPlans: [] }], achievements: [], communityCases: [], comments: {}, liked: [], favorites: [], followedAuthors: [], schedules: [] };
      const fixture = window.__tuneFixture = { calls: [], delayNext: false, failNext: false, queued: [], before, after };
      const cache = new Map();
      window.webkit = { messageHandlers: { smartpaw: { postMessage(message) {
        fixture.calls.push(message);
        const send = (data, error) => window.__smartPawReceive?.({ requestId: message.requestId, status: error ? 'error' : 'success', error, data });
        queueMicrotask(() => {
          const key = JSON.stringify(message.payload);
          if (message.command === 'image.settings.get') return send({ configured: true });
          if (message.command === 'space.photos') return send({ before });
          if (message.command === 'chat.send') return send({ reply: '已记录这项调整，请生成效果图核对。' });
          if (message.command === 'image.preview.restore') return send(cache.has(key) ? { available: true, preview: cache.get(key) } : { available: false });
          if (message.command === 'image.preview.generate') {
            const complete = () => { cache.set(key, after); send({ preview: after }); };
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
    await page.goto('http://127.0.0.1:' + server.address().port + '/?flow=tune', { waitUntil: 'domcontentloaded' });
    const input = page.getByPlaceholder('告诉我想怎么调整…');
    const say = async text => { await input.fill(text); await input.press('Enter'); await page.getByRole('button', { name: /生成当前方案效果图/ }).waitFor(); };
    await say('保留台灯位置');
    await say('书本留在右边');
    await say('不要增加收纳盒');
    assert.equal(await page.getByRole('button', { name: '确认效果图，继续整理', exact: true }).count(), 0);
    assert.equal(await page.evaluate(() => window.__tuneFixture.calls.filter(c => c.command === 'image.preview.generate').length), 0);
    await page.getByRole('button', { name: /生成当前方案效果图/ }).click();
    await page.getByRole('button', { name: /确认效果图，继续整理/ }).waitFor();
    const payload = await page.evaluate(() => window.__tuneFixture.calls.filter(c => c.command === 'image.preview.generate').at(-1).payload);
    for (const preference of ['保留台灯位置', '书本留在右边', '不要增加收纳盒']) { assert.ok(payload.goal.includes(preference)); assert.ok(payload.changes.includes('用户调整：' + preference)); }
    await page.getByRole('button', { name: '对比整理前照片', exact: true }).click();
    await page.getByAltText('整理前照片', { exact: true }).waitFor();
    await page.getByRole('button', { name: '查看当前效果图', exact: true }).click();
    await page.getByAltText('当前微调方案的真实效果图', { exact: true }).first().waitFor();
    checks.push({ width, check: 'All preferences enter the real preview payload; confirmation requires displayed current image; before/after toggle', passed: true });
    await say('水杯放在左边');
    assert.equal(await page.getByRole('button', { name: /确认效果图，继续整理/ }).count(), 0);
    await page.evaluate(() => { window.__tuneFixture.failNext = true; });
    await page.getByRole('button', { name: /生成当前方案效果图/ }).click();
    await page.getByRole('alert').filter({ hasText: '测试生图失败' }).waitFor();
    await page.getByRole('button', { name: /重试生成效果图/ }).click();
    await page.getByRole('button', { name: /确认效果图，继续整理/ }).waitFor();
    checks.push({ width, check: 'New preference invalidates old image; real generation error remains retryable', passed: true });
    await say('键盘居中');
    await page.evaluate(() => { window.__tuneFixture.delayNext = true; });
    await page.getByRole('button', { name: /生成当前方案效果图/ }).click();
    await page.getByRole('button', { name: '取消生成效果图', exact: true }).waitFor();
    await say('手机保留在右边');
    await page.evaluate(() => window.__tuneFixture.queued.splice(0).forEach(done => done()));
    assert.equal(await page.getByRole('button', { name: /确认效果图，继续整理/ }).count(), 0);
    await page.getByRole('button', { name: /生成当前方案效果图/ }).click();
    await page.getByRole('button', { name: /确认效果图，继续整理/ }).waitFor();
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await page.screenshot({ path: path.join(evidence, width + '-tune-real-preview.png') });
    await page.getByRole('button', { name: /确认效果图，继续整理/ }).click();
    await page.getByText('选择整理分区', { exact: true }).waitFor();
    checks.push({ width, check: 'Late result from prior preference is ignored; only explicit confirmation advances to zones; no horizontal document overflow', passed: true });
    await context.close();
  }
  assert.equal(errors.length, 0);
  await writeFile(path.join(evidence, 'results.json'), JSON.stringify({ environment: 'Desktop Chromium, synthetic SVG photos and native bridge fixture; no real network provider or iPhone', checks, errors }, null, 2));
  console.log(JSON.stringify({ checks, errors }, null, 2));
} catch (error) {
  for (const context of browser.contexts()) for (const page of context.pages()) { await page.screenshot({ path: path.join(evidence, 'failure.png') }); console.log((await page.locator('body').innerText()).slice(0, 5000)); }
  throw error;
} finally { await browser.close(); server.close(); }
