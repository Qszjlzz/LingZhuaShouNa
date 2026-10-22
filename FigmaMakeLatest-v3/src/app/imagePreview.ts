export type PreviewScope = {
  id: string;
  label: string;
  rect?: { x: number; y: number; width: number; height: number };
};

// These are explicit photo regions chosen by the user, not inferred item classes
// or the destination zones in an organizing plan. Keep the full source frame.
export const PREVIEW_SCOPES: PreviewScope[] = [
  { id: "whole", label: "整体" },
  { id: "top-left", label: "左上区域", rect: { x: 0, y: 0, width: 0.5, height: 0.5 } },
  { id: "top-right", label: "右上区域", rect: { x: 0.5, y: 0, width: 0.5, height: 0.5 } },
  { id: "bottom-left", label: "左下区域", rect: { x: 0, y: 0.5, width: 0.5, height: 0.5 } },
  { id: "bottom-right", label: "右下区域", rect: { x: 0.5, y: 0.5, width: 0.5, height: 0.5 } },
];

type PreviewPlan = { id: string; name: string; vibe: string; changes: string[] };

export function imagePreviewRequest(plan: PreviewPlan, scope: PreviewScope = PREVIEW_SCOPES[0]) {
  const rect = scope.rect;
  return {
    planID: rect ? `${plan.id}:photo-region:${scope.id}` : plan.id,
    planName: plan.name,
    goal: plan.vibe,
    changes: plan.changes,
    focusRect: rect,
    focusZone: rect
      ? `${scope.label}：以完整输入照片为坐标系，左上角为 (0,0)，向右为 x，向下为 y；只调整 x=${rect.x} 至 ${rect.x + rect.width}、y=${rect.y} 至 ${rect.y + rect.height} 的矩形范围。保持整个原画幅，矩形外的物品及位置保持原样`
      : "",
  };
}

export function imagePreviewPlanKey(plan: PreviewPlan, scope: PreviewScope = PREVIEW_SCOPES[0]): string {
  return JSON.stringify(imagePreviewRequest(plan, scope));
}
