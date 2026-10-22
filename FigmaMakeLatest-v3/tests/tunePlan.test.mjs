import test from 'node:test';
import assert from 'node:assert/strict';
import { refinedTunePlan } from '../src/app/tunePlan.ts';
import { imagePreviewRequest, imagePreviewPlanKey } from '../src/app/imagePreview.ts';

const original = { id: 'desk', name: '快速整理', vibe: '常用物品易取', changes: ['书本集中'], minutes: 10 };

test('all chat preferences reach the real preview request and executable-plan goal', () => {
  const result = refinedTunePlan(original, ['保留台灯位置', '书本留在右边', '不要增加收纳盒']);
  const request = imagePreviewRequest(result);
  for (const preference of ['保留台灯位置', '书本留在右边', '不要增加收纳盒']) {
    assert.ok(request.goal.includes(preference));
    assert.ok(request.changes.includes('用户调整：' + preference));
  }
  assert.deepEqual(original.changes, ['书本集中']);
  assert.equal(original.vibe, '常用物品易取');
});

test('new preference invalidates the old preview identity without duplicating the base plan', () => {
  const first = refinedTunePlan(original, ['保留台灯位置']);
  const next = refinedTunePlan(original, ['保留台灯位置', '书本留在右边']);
  assert.notEqual(imagePreviewPlanKey(first), imagePreviewPlanKey(next));
  assert.equal(next.name, '快速整理 · 定制');
  assert.deepEqual(next.changes.slice(0, 1), original.changes);
  assert.equal(refinedTunePlan(original, ['  ']), original);
});
