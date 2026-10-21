import type { NativeState, NativePlan } from "./nativeBridge";

export type ProjectPlan = {
  key: string;
  id: string;
  spaceID?: string;
  space: string;
  title: string;
  value?: NativePlan;
  note?: string;
  dueText?: string;
  status: "active" | "paused" | "scheduled" | "awaitingPhoto" | "done";
  progress: number;
};

export function plansFromState(state?: NativeState | null): ProjectPlan[] {
  const spaces = state?.spaces ?? [];
  const active = spaces.flatMap((space): ProjectPlan[] => space.activePlan ? [{
    key: `${space.id}:${space.activePlan.id}`,
    id: space.activePlan.id,
    spaceID: space.id,
    space: space.name,
    title: space.activePlan.summary || `${space.name}整理`,
    value: space.activePlan,
    status: space.activePlan.steps.length > 0 && space.activePlan.steps.every((step) => step.status === "done") ? "awaitingPhoto" : space.activePlan.isPaused ? "paused" : "active",
    progress: space.activePlan.steps.length ? Math.round(space.activePlan.steps.filter((step) => step.status === "done").length / space.activePlan.steps.length * 100) : 0,
  }] : []);
  const scheduled: ProjectPlan[] = (state?.schedules ?? []).flatMap((item: any) => {
    if (typeof item?.id !== "string") return [];
    const dueDate = typeof item.dueDate === "string" ? new Date(item.dueDate) : null;
    const dueText = dueDate && Number.isFinite(dueDate.getTime())
      ? new Intl.DateTimeFormat("zh-CN", { month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit", hour12: false }).format(dueDate)
      : "待整理";
    const space = String(item.spaceName || "本地空间");
    const matchingSpace = spaces.find((entry) => entry.name === space);
    return [{
      key: `schedule:${item.id}`,
      id: item.id,
      spaceID: matchingSpace?.id,
      space,
      title: String(item.title || "整理计划"),
      note: String(item.note || ""),
      dueText,
      status: item.isDone === true ? "done" : "scheduled",
      progress: item.isDone === true ? 100 : 0,
    }];
  });
  const completed = spaces.flatMap((space): ProjectPlan[] => (space.completedPlans ?? []).map((plan) => ({
    key: `${space.id}:${plan.id}`,
    id: plan.id,
    spaceID: space.id,
    space: space.name,
    title: plan.summary || `${space.name}整理`,
    value: plan,
    status: "done",
    progress: 100,
  })));
  return [...active, ...scheduled, ...completed];
}
