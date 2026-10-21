import type { NativeItem, NativePlan, NativeState } from "./nativeBridge";

export type GuidePhase = "prepare" | "classify" | "execute";
export type GuideGroup = { id: string; label: string; items: string[]; itemCount?: number };

// Only the instructional phase is stored here. Completed work belongs to the native plan.
export function guideStartIndex(plan: NativePlan, phase?: GuidePhase | null): number {
  const openIndex = plan.steps.findIndex((step) => step.status === "active");
  if (plan.steps.some((step) => step.status === "done")) {
    return 2 + (openIndex >= 0 ? openIndex : Math.max(plan.steps.length - 1, 0));
  }
  return phase === "classify" ? 1 : phase === "execute" ? 2 + Math.max(openIndex, 0) : 0;
}

export function guidePhaseKey(planID: string): string {
  return `smartpaw.guide.phase.v1:${planID}`;
}

export function groupsForNativePlan(plan: NativePlan, items: NativeItem[]): GuideGroup[] {
  const itemsByID = new Map(items.map((item) => [item.id, item]));
  return plan.steps.map((step) => {
    const ids = [...new Set(step.itemIDs ?? [])];
    const matched = ids.map((id) => itemsByID.get(id)).filter((item): item is NativeItem => !!item);
    const categories = [...new Set(matched.map((item) => item.category).filter(Boolean))];
    return {
      id: step.id,
      label: categories.length ? categories.join(" / ") : step.title,
      items: matched.map((item) => item.name),
      itemCount: ids.length ? ids.length : undefined,
    };
  });
}

export async function completeGuideNativeStep(
  planID: string,
  stepID: string,
  request: (command: string, payload?: Record<string, unknown>) => Promise<NativeState>,
): Promise<NativePlan> {
  const state = await request("state.get");
  const selected = state.spaces.find((space) => space.id === state.selectedSpaceID);
  const plan = selected?.activePlan;
  if (plan?.id !== planID || plan.steps.find((step) => step.status === "active")?.id !== stepID) {
    throw new Error("方案进度已改变，请返回空间页继续整理");
  }
  if (plan.isPaused) throw new Error("方案已暂停，请先在项目页继续方案");
  const updated = await request("plan.step.complete", { id: stepID });
  const latest = updated.spaces.find((space) => space.id === selected.id)?.activePlan;
  if (updated.selectedSpaceID !== selected.id || latest?.id !== planID
    || latest.steps.find((step) => step.id === stepID)?.status !== "done") {
    throw new Error("未读取到最新方案，请返回空间页检查进度");
  }
  return latest;
}
