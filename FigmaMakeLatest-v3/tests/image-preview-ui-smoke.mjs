import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const { chromium } = await import(process.env.SMARTPAW_PLAYWRIGHT ?? 'playwright');
const project = fileURLToPath(new URL('../', import.meta.url));
const evidence = process.env.SMARTPAW_QA_OUTPUT ?? path.join(project, '../outputs/image-preview-ui-20261023');
await mkdir(evidence, { recursive: true });
const server = createServer(async (request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  const target = path.resolve(project, 'dist', `.${pathname === '/' ? '/index.html' : pathname}`);
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
      const before = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="900" height="600"><rect width="900" height="600" fill="#bda280"/><rect x="20" y="20" width="390" height="260" fill="#7799bb"/></svg>');
      const after = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="900" height="600"><rect width="900" height="600" fill="#bda280"/><rect x="20" y="20" width="390" height="260" fill="#66aa88"/></svg>');
      const items = [{ id: 'book', name: '课本', category: '书籍', confidence: 1, suggestedZone: '书架', isSelected: true }];
      const state = { isPresentationMode: false, selectedSpaceID: 'desk', scannedItems: items, spaces: [{ id: 'desk', name: '书桌', subtitle: '', detectedItems: items, completedPlans: [] }], achievements: [], communityCases: [], comments: {}, liked: [], favorites: [], followedAuthors: [], schedules: [] };
      const fixture = window.__previewFixture = { calls: [], delayNext: false, failNext: false, queued: [], before, after };
      const cache = new Map(JSON.parse(localStorage.getItem('qa.preview-cache') || '[]'));
      window.webkit = { messageHandlers: { smartpaw: { postMessage(message) {
        fixture.calls.push(message);
        const send = (data, error) => window.__smartPawReceive?.({ requestId: message.requestId, status: error ? 'error' : 'success', error, data });
        queueMicrotask(() => {
          const key = JSON.stringify(message.payload);
          if (message.command === 'image.settings.get') return send({ configured: true });
          if (message.command === 'space.photos') return send({ before });
          if (message.command === 'image.preview.restore') return send(cache.has(key) ? { available: true, preview: cache.get(key) } : { available: false });
          if (message.command === 'image.preview.generate') {
            const complete = () => { cache.set(key, after); localStorage.setItem('qa.preview-cache', JSON.stringify([...cache])); send({ preview: after }); };
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
    await page.goto(`http://127.0.0.1:${server.address().port}/?flow=plandeck`);
    const generate = () => page.getByRole('button', { name: '生成效果图', exact: true });
    await generate().waitFor();
    await page.getByAltText('整理前照片').waitFor();
    await page.getByRole('button', { name: '选择物品入库', exact: true }).click();
    await page.getByLabel('入库课本（1）', { exact: true }).check();
    await page.getByRole('button', { name: '保存到本机物品库（1）', exact: true }).click();
    const library = await page.evaluate(() => JSON.parse(localStorage.getItem('smartpaw-item-library-v1.personal')));
    assert.equal(library.items.length, 1);
    assert.equal(library.items[0].sourceID, 'book');
    assert.equal(library.items[0].sourceSpaceID, 'desk');
    assert.equal(library.items[0].sourceSpaceName, '书桌');
    assert.equal(await page.evaluate(() => window.__previewFixture.calls.some(c => c.command.startsWith('item.') || c.command === 'items.save' || c.command.includes('upload'))), false);
    checks.push({ width, check: 'Production postcapture plan imports a selected subset to the correct local mode with original source identity; no scan mutation or upload', passed: true });
    await page.getByRole('button', { name: '左上区域', exact: true }).click();
    assert.equal(await page.evaluate(() => window.__previewFixture.calls.filter(c => c.command === 'image.preview.generate').length), 0);
    await generate().click();
    await page.getByText('AI 左上区域整理效果预览', { exact: true }).waitFor();
    const generated = await page.evaluate(() => window.__previewFixture.calls.filter(c => c.command === 'image.preview.generate').at(-1).payload);
    assert.match(generated.planID, /photo-region:top-left/);
    assert.match(generated.focusZone, /x=0 至 0.5、y=0 至 0.5/);
    await page.getByRole('button', { name: '查看原图', exact: true }).click();
    await page.getByAltText('整理前照片').waitFor();
    await page.getByRole('button', { name: '查看效果图', exact: true }).click();
    await page.getByAltText('AI 左上区域整理效果预览').waitFor();
    checks.push({ width, check: 'Explicit source region, full request, user-triggered generation and before/after toggle', passed: true });
    await page.getByRole('button', { name: '整体', exact: true }).click();
    await generate().waitFor();
    await page.evaluate(() => { window.__previewFixture.delayNext = true; });
    await generate().click();
    await page.getByRole('button', { name: '取消生成效果图', exact: true }).waitFor();
    await page.getByRole('button', { name: '右上区域', exact: true }).click();
    await page.evaluate(() => { window.__previewFixture.queued.splice(0).forEach(done => done()); });
    await generate().waitFor();
    assert.equal(await page.getByAltText('AI 整体整理效果预览').count(), 0);
    await page.evaluate(() => { window.__previewFixture.failNext = true; });
    await generate().click();
    await page.getByRole('alert').filter({ hasText: '测试生图失败' }).waitFor();
    await page.getByRole('button', { name: '重试', exact: true }).click();
    await page.getByText('AI 右上区域整理效果预览', { exact: true }).waitFor();
    checks.push({ width, check: 'Changing region cancels and ignores stale result; failure remains retryable', passed: true });
    await page.getByRole('button', { name: '左上区域', exact: true }).click();
    await page.getByText('AI 左上区域整理效果预览', { exact: true }).waitFor();
    const paidCalls = await page.evaluate(() => window.__previewFixture.calls.filter(c => c.command === 'image.preview.generate').length);
    assert.equal(paidCalls, 4);
    await page.screenshot({ path: path.join(evidence, `${width}-left-region-restored.png`) });
    await page.reload();
    await page.getByRole('button', { name: '左上区域', exact: true }).click();
    await page.getByText('AI 左上区域整理效果预览', { exact: true }).waitFor();
    assert.equal(await page.evaluate(() => window.__previewFixture.calls.filter(c => c.command === 'image.preview.generate').length), 0);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    checks.push({ width, check: 'Region-specific cache restores after switching and reload without new generate; no horizontal document overflow', passed: true });
    await context.close();
  }
  assert.equal(errors.length, 0);
  await writeFile(path.join(evidence, 'results.json'), JSON.stringify({ environment: 'Desktop Chromium, synthetic SVG photos and native bridge fixture; no real network provider or iPhone', checks, errors }, null, 2));
  console.log(JSON.stringify({ checks, errors }, null, 2));
} catch (error) {
  for (const context of browser.contexts()) for (const page of context.pages()) { await page.screenshot({ path: path.join(evidence, 'failure.png') }); console.log((await page.locator('body').innerText()).slice(0, 5000)); }
  throw error;
} finally { await browser.close(); server.close(); }
