import test from 'node:test';
import assert from 'node:assert/strict';
import { validatedDisorderAssessment } from '../src/app/disorderAssessment.ts';

const tidy = { score: 8, level: 'tidy', evidence: ['物品按类别摆放，台面有充足可用空间'], clutterRegions: [], estimatedMinutes: 3, sourceSpaceID: 'desk' };
test('a visually tidy scene retains its low score and empty regions even with many recognized objects', () => {
  assert.equal(validatedDisorderAssessment({ ...tidy, recognizedItemCount: 60 }, 'desk').score, 8);
  assert.deepEqual(validatedDisorderAssessment(tidy, 'desk').clutterRegions, []);
});
test('real normalized clutter rectangles and reasoning are preserved', () => {
  const result = { ...tidy, score: 62, level: 'moderate', evidence: ['纸张相互堆叠，压住常用物品'], clutterRegions: [{ x: 0.2, y: 0.25, width: 0.3, height: 0.4, label: '纸张堆积' }], estimatedMinutes: 20 };
  assert.equal(validatedDisorderAssessment(result, 'desk'), result);
});
test('missing, nonfinite or malformed output never receives invented scores or regions', () => {
  for (const data of [null, {}, { ...tidy, score: NaN }, { ...tidy, score: 101 }, { ...tidy, level: 'unknown' }, { ...tidy, estimatedMinutes: -1 }, { ...tidy, evidence: [] }, { ...tidy, evidence: [''] }, { ...tidy, clutterRegions: null }, { ...tidy, clutterRegions: [{ x: .9, y: 0, width: .2, height: .1, label: 'overflow' }] }, { ...tidy, clutterRegions: [{ x: 0, y: 0, width: 0, height: .1, label: 'empty' }] }]) {
    assert.throws(() => validatedDisorderAssessment(data, 'desk'));
  }
});
test('an assessment from a different space cannot be applied to the current page', () => {
  assert.throws(() => validatedDisorderAssessment({ ...tidy, sourceSpaceID: 'other' }, 'desk'), /不属于当前空间/);
});
