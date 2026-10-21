import { useEffect, useState } from "react";
import { ArrowLeft, Check, Clock, Plus, Play, Pause, MoreHorizontal, X } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { nativeRequest, type NativeState } from "../nativeBridge";
import { plansFromState, type ProjectPlan } from "../projectPlans";
import closetCover from "../../../../Resources/Assets.xcassets/FigmaProfilePlanCloset.imageset/closet.png";
import livingCover from "../../../../Resources/Assets.xcassets/FigmaProfilePlanLiving.imageset/living.png";
import cabinetCover from "../../../../Resources/Assets.xcassets/FigmaProfilePlanCabinet.imageset/cabinet.png";

const tabs = ["全部", "活跃的", "预定的", "完成"] as const;

function planCover(plan: ProjectPlan, index: number): string {
  const content = `${plan.space} ${plan.title}`;
  if (/客厅|沙发|电视|living/i.test(content)) return livingCover;
  if (/厨房|餐具|碗柜|kitchen/i.test(content)) return cabinetCover;
  if (/书房|衣柜|卧室|wardrobe|closet/i.test(content)) return closetCover;
  return [closetCover, cabinetCover, livingCover][index % 3];
}

function durationText(minutes: number): string {
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  return [hours ? `${hours}小时` : "", remainder ? `${remainder}分钟` : ""].filter(Boolean).join("") || "0分钟";
}

export function MyPlansScreen({ onBack, nativeState, onNativeChange, isTabRoot = false, onAddPlan }: {
  onBack: () => void; nativeState?: NativeState | null; onNativeChange?: () => void;
  isTabRoot?: boolean; onAddPlan?: () => void;
}) {
  const [tab, setTab] = useState<(typeof tabs)[number]>("全部");
  const [selected, setSelected] = useState<string | null>(null);
  const [localState, setLocalState] = useState(nativeState);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => { setLocalState(nativeState); }, [nativeState]);
  const plans = plansFromState(localState);
  const current = plans.find((plan) => plan.key === selected);
  const filtered = plans.filter((plan) => tab === "全部"
    || (tab === "活跃的" && (plan.status === "active" || plan.status === "paused" || plan.status === "awaitingPhoto"))
    || (tab === "预定的" && plan.status === "scheduled")
    || (tab === "完成" && plan.status === "done"));
  const activeCount = plans.filter((plan) => plan.status === "active" || plan.status === "paused" || plan.status === "awaitingPhoto").length;
  const plannedMinutes = plans.reduce((total, plan) => total + (plan.status === "done" ? 0 : plan.value?.timeBudget ?? 0), 0);
  const update = (state: NativeState) => { setLocalState(state); onNativeChange?.(); };

  const openPlan = async (plan: ProjectPlan) => {
    if (busy) return;
    if (!plan.spaceID || !plan.value) { setSelected(plan.key); return; }
    setBusy(true); setError("");
    try {
      const state = await nativeRequest<NativeState>("space.select", { id: plan.spaceID });
      update(state); setSelected(plan.key);
    } catch (cause) { setError(cause instanceof Error ? cause.message : "无法打开方案，请重试。"); }
    finally { setBusy(false); }
  };
  const togglePaused = async (plan: ProjectPlan) => {
    if (busy || !plan.spaceID || !plan.value) return;
    setBusy(true); setError("");
    try {
      const state = await nativeRequest<NativeState>("plan.pause.set", {
        spaceID: plan.spaceID, planID: plan.id, isPaused: plan.status !== "paused",
      });
      update(state);
    } catch (cause) { setError(cause instanceof Error ? cause.message : "方案状态保存失败，请重试。"); }
    finally { setBusy(false); }
  };
  const completeStep = async (stepID: string) => {
    if (busy || !current?.value) return;
    setBusy(true); setError("");
    try {
      if (current.spaceID) await nativeRequest("space.select", { id: current.spaceID });
      const state = await nativeRequest<NativeState>("plan.step.complete", { id: stepID });
      update(state);
    } catch (cause) { setError(cause instanceof Error ? cause.message : "步骤保存失败，请重试。"); }
    finally { setBusy(false); }
  };
  const saveCompletionPhoto = async () => {
    if (busy || !current?.spaceID) return;
    setBusy(true); setError("");
    try {
      await nativeRequest("space.select", { id: current.spaceID });
      const result = await nativeRequest<{ state?: NativeState }>("capture.open", { purpose: "after", source: "library" });
      if (result.state) update(result.state); else onNativeChange?.();
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : "完成照保存失败，请重试。";
      if (message !== "已取消") setError(message);
    } finally { setBusy(false); }
  };

  const toggleSchedule = async () => {
    if (busy || !current || !current.key.startsWith("schedule:")) return;
    setBusy(true); setError("");
    try {
      const state = await nativeRequest<NativeState>("schedule.toggle", { id: current.id });
      update(state);
    } catch (cause) { setError(cause instanceof Error ? cause.message : "计划保存失败，请重试。"); }
    finally { setBusy(false); }
  };

  return <div className="h-full w-full overflow-y-auto pb-32" style={{ backgroundColor: LINEN, color: COFFEE }}>
    <header className="px-6 pt-14 pb-2 flex items-center justify-between">
      {isTabRoot
        ? <div className="h-11 w-11" />
        : <button type="button" onClick={onBack} aria-label="返回我的" className="h-11 w-11 rounded-full flex items-center justify-center" style={{ backgroundColor: WHITE }}><ArrowLeft size={20} /></button>}
      <h1 style={{ fontSize: 17, fontWeight: 600 }}>项目</h1>
      <button type="button" onClick={onAddPlan} aria-label="创建整理计划" className="h-11 w-11 rounded-full flex items-center justify-center" style={{ backgroundColor: ORANGE, color: WHITE, boxShadow: "0 6px 16px rgba(250,136,58,0.3)" }}><Plus size={20} /></button>
    </header>
    <div className="mx-6 mt-4 min-h-[104px] p-5 flex items-center gap-4 rounded-3xl" style={{ background: `linear-gradient(135deg, ${COFFEE} 0%, #5d4334 100%)`, color: WHITE }}>
      <div className="flex-1"><p style={{ opacity: 0.7, fontSize: 11 }}>本周</p><p className="mt-1" style={{ fontSize: 22, fontWeight: 600 }}>{activeCount} 个活动计划</p><p className="mt-1" style={{ opacity: 0.7, fontSize: 12 }}>预计用时 {durationText(plannedMinutes)}</p></div>
    </div>
    <div className="px-6 mt-5 flex gap-2 overflow-x-auto">{tabs.map((value) => <button type="button" key={value} onClick={() => setTab(value)} aria-pressed={tab === value} className="px-4 py-2 rounded-full flex-shrink-0" style={{ backgroundColor: tab === value ? ORANGE : WHITE, color: tab === value ? WHITE : COFFEE, fontSize: 12 }}>{value}</button>)}</div>
    {error && !current && <p role="alert" className="px-6 mt-4" style={{ color: "#9A4230", fontSize: 12 }}>{error}</p>}
    <section className="px-6 mt-5 space-y-3">{filtered.map((plan, index) => {
      const statusLabel = plan.status === "done" ? "已完成" : plan.status === "scheduled" ? "已安排" : plan.status === "paused" ? "已暂停" : plan.status === "awaitingPhoto" ? "待保存完成照" : "进行中";
      const statusColor = plan.status === "done" ? "#7BB28F" : plan.status === "paused" ? BLUE : plan.status === "scheduled" ? "#A88370" : ORANGE;
      const hasProgress = plan.status !== "done" && plan.status !== "scheduled";
      return <article key={plan.key} className="relative w-full text-left" style={{ backgroundColor: WHITE, borderRadius: 22, overflow: "hidden", boxShadow: "0 4px 18px rgba(123,92,72,0.06)" }}>
        <div className="flex">
        <button type="button" disabled={busy} onClick={() => void openPlan(plan)} aria-label={`打开项目：${plan.title}`} className="flex min-w-0 flex-1 text-left disabled:opacity-50">
          <img src={planCover(plan, index)} alt="" className="w-24 h-24 flex-shrink-0 object-cover" />
          <span className="min-w-0 flex-1 px-3 pt-3 pb-2">
            <span className="flex items-center gap-2"><span className="px-2 py-0.5 rounded-full" style={{ color: WHITE, backgroundColor: statusColor, fontSize: 9 }}>{statusLabel}</span><span className="truncate" style={{ opacity: 0.6, fontSize: 11 }}>{plan.space}</span></span>
            <span className="block mt-1 truncate" style={{ fontSize: 13, fontWeight: 600 }}>{plan.title}</span>
            <span className="mt-1 flex items-center gap-1 truncate" style={{ opacity: 0.6, fontSize: 10 }}><Clock size={11} />{plan.key.startsWith("schedule:") ? plan.dueText : `${plan.status === "done" ? "已完成" : plan.status === "paused" ? "已暂停" : "立即继续"} · ${plan.value?.timeBudget ?? 0} 分钟`}</span>
          </span>
        </button>
        <button type="button" disabled={busy} onClick={() => void openPlan(plan)} aria-label={`${plan.title}的更多操作`} className="px-3 disabled:opacity-40" style={{ color: COFFEE, opacity: 0.5 }}><MoreHorizontal size={18} /></button>
        </div>
        {hasProgress && <div className="px-3 pb-3 flex items-center gap-2"><span className="h-2 flex-1 rounded-full overflow-hidden" style={{ backgroundColor: SOFT }}><span className="block h-full rounded-full" style={{ width: `${plan.progress}%`, background: `linear-gradient(90deg, ${ORANGE} 0%, #FFAA66 100%)` }} /></span><span style={{ opacity: 0.6, fontSize: 11 }}>{plan.progress}%</span><button type="button" disabled={busy} onClick={() => plan.status === "awaitingPhoto" ? void openPlan(plan) : void togglePaused(plan)} aria-label={`${plan.status === "active" ? "暂停" : "继续"}项目：${plan.title}`} className="h-8 px-3 rounded-full flex items-center gap-1 disabled:opacity-40" style={{ color: WHITE, backgroundColor: ORANGE, fontSize: 11, fontWeight: 600 }}>{plan.status === "active" ? <Pause size={12} /> : <Play size={12} fill={WHITE} />}{plan.status === "active" ? "暂停" : "继续"}</button></div>}
      </article>;
    })}{filtered.length === 0 && <p className="text-center py-10" style={{ opacity: 0.6, fontSize: 13 }}>暂无项目，点击右上角开始整理。</p>}</section>

    {current && <div className="fixed inset-0 z-[60] flex items-end" style={{ backgroundColor: "rgba(30,20,15,0.35)" }}><div className="w-full max-h-[85%] overflow-y-auto p-6 pb-10 rounded-t-3xl" style={{ backgroundColor: WHITE }}>
      <div className="flex items-center justify-between gap-3"><div><p style={{ opacity: 0.6, fontSize: 12 }}>{current.space}</p><h2 className="mt-1" style={{ fontSize: 18, fontWeight: 600 }}>{current.status === "scheduled" ? "计划详情" : "整理项目"}</h2></div><button type="button" disabled={busy} onClick={() => setSelected(null)} aria-label="关闭项目详情" className="h-11 w-11 rounded-full flex items-center justify-center disabled:opacity-40" style={{ backgroundColor: LINEN }}><X size={19} /></button></div>
      <p className="mt-4" style={{ fontSize: 14, lineHeight: 1.7 }}>{current.title}</p>
      {current.status === "paused" && <div className="mt-4"><p style={{ opacity: 0.7, fontSize: 12 }}>项目已暂停，进度已保存。</p><button type="button" disabled={busy} onClick={() => void togglePaused(current)} className="mt-3 px-4 py-2 rounded-full disabled:opacity-40" style={{ backgroundColor: ORANGE, color: WHITE, fontSize: 12 }}>继续项目</button></div>}
      {current.value && <><p className="mt-2" style={{ opacity: 0.6, fontSize: 12 }}>预计 {current.value.timeBudget} 分钟{current.value.toolList.length ? ` · ${current.value.toolList.join("、")}` : ""}</p>
      <div className="mt-5 space-y-3">{current.value.steps.map((step, index) => <article key={step.id} className="p-4 rounded-2xl" style={{ backgroundColor: LINEN }}><h3 className="flex items-start gap-2" style={{ fontWeight: 600, fontSize: 14 }}><span className="flex-1">{index + 1}. {step.title}</span>{step.status === "done" && <Check size={17} color="#6A997C" />}</h3><p className="mt-2" style={{ opacity: 0.7, fontSize: 13, lineHeight: 1.7 }}>{step.detail}</p>{current.status !== "done" && current.status !== "paused" && step.status === "active" && <button type="button" disabled={busy} onClick={() => void completeStep(step.id)} className="mt-3 px-4 py-2 rounded-full disabled:opacity-40" style={{ backgroundColor: ORANGE, color: WHITE, fontSize: 12 }}>{busy ? "保存中…" : "标记此步完成"}</button>}</article>)}</div></>}
      {current.status === "scheduled" && <><p className="mt-2" style={{ opacity: 0.6, fontSize: 12 }}>{current.dueText}</p>{current.note && <p className="mt-3" style={{ opacity: 0.7, fontSize: 13, lineHeight: 1.7 }}>{current.note}</p>}<button type="button" disabled={busy} onClick={() => void toggleSchedule()} className="w-full mt-5 py-3 rounded-full disabled:opacity-40" style={{ backgroundColor: ORANGE, color: WHITE, fontSize: 13, fontWeight: 600 }}>{busy ? "保存中…" : "标记计划完成"}</button></>}
      {current.status === "awaitingPhoto" && <div className="mt-5"><p style={{ opacity: 0.7, fontSize: 12, lineHeight: 1.7 }}>步骤已完成。选择一张真实的整理后照片，保存这次成果。</p><button type="button" disabled={busy} onClick={() => void saveCompletionPhoto()} className="w-full mt-3 py-3 rounded-full disabled:opacity-40" style={{ backgroundColor: ORANGE, color: WHITE, fontSize: 13, fontWeight: 600 }}>{busy ? "正在保存…" : "选择完成照并保存"}</button></div>}
      {current.status === "done" && <p className="mt-5 text-center" style={{ color: "#6A997C", fontSize: 13 }}>本次计划已完成并归档。</p>}
      {error && <p role="alert" className="mt-4" style={{ color: "#9A4230", fontSize: 12 }}>{error}</p>}
    </div></div>}
  </div>;
}
