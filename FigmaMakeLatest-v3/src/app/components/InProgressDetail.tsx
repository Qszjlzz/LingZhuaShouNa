import { useEffect, useRef, useState } from "react";
import { ArrowLeft, Play, Pause, CheckCircle2, Circle, Clock, Flame } from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { nativeRequest, type NativeSpace, type NativeState } from "../nativeBridge";
import defaultCover from "../../../../Resources/Assets.xcassets/FigmaProfilePlanCloset.imageset/closet.png";
import { CompletionPhotoReview, useCompletionPhoto } from "./CompletionPhotoReview";

export type ProgressSpace = {
  id: string;
  title: string;
  progress: number;
  cover: string;
  estimate: string;
  streak: number;
  zones: { id: string; name: string; done: boolean; current?: boolean; tasks: number }[];
  recentActivity: { time: string; text: string }[];
};

function Ring({ value, size = 160 }: { value: number; size?: number }) {
  const r = (size - 20) / 2;
  const c = 2 * Math.PI * r;
  const offset = c - (value / 100) * c;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <circle cx={size / 2} cy={size / 2} r={r} stroke={SOFT} strokeWidth="14" fill="none" />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={r}
        stroke={ORANGE}
        strokeWidth="14"
        strokeLinecap="round"
        fill="none"
        strokeDasharray={c}
        strokeDashoffset={offset}
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
      />
      <text
        x={size / 2}
        y={size / 2 + 4}
        textAnchor="middle"
        fill={COFFEE}
        style={{ fontSize: 32, fontWeight: 600 }}
      >
        {value}%
      </text>
      <text
        x={size / 2}
        y={size / 2 + 24}
        textAnchor="middle"
        fill={COFFEE}
        opacity="0.55"
        style={{ fontSize: 11 }}
      >
        Complete
      </text>
    </svg>
  );
}

export function InProgressDetail({
  onBack,
  space: nativeSpace,
  onNativeChange,
}: {
  onBack: () => void;
  space: NativeSpace;
  onNativeChange?: (state: NativeState) => void;
}) {
  const [localSpace, setLocalSpace] = useState(nativeSpace);
  const [cover, setCover] = useState(defaultCover);
  const [executing, setExecuting] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const submitting = useRef(false);
  const activeStepRef = useRef<HTMLDivElement>(null);
  useEffect(() => { setLocalSpace(nativeSpace); }, [nativeSpace]);
  useEffect(() => {
    let cancelled = false;
    setCover(defaultCover);
    void nativeRequest<{ before?: string; after?: string }>("space.photos", { id: nativeSpace.id })
      .then((photos) => { if (!cancelled) setCover(photos.before || photos.after || defaultCover); })
      .catch(() => undefined);
    return () => { cancelled = true; };
  }, [nativeSpace.id]);
  useEffect(() => {
    if (executing) activeStepRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
  }, [executing]);
  const plan = localSpace.activePlan;
  const steps = plan?.steps ?? [];
  const done = steps.filter((step) => step.status === "done");
  const currentStep = steps.find((step) => step.status === "active");
  const allDone = steps.length > 0 && done.length === steps.length;
  const zoneNames = [...new Set(steps.map((step) => step.zone || "整理区域"))];
  const space: ProgressSpace = {
    id: localSpace.id, title: localSpace.name, cover,
    progress: steps.length ? Math.round(done.length / steps.length * 100) : 0,
    estimate: `预计 ${plan?.timeBudget ?? 0} 分钟`,
    streak: localSpace.completedPlans.length,
    zones: zoneNames.map((name) => {
      const zoneSteps = steps.filter((step) => (step.zone || "整理区域") === name);
      return { id: name, name, tasks: zoneSteps.length, done: zoneSteps.every((step) => step.status === "done"), current: zoneSteps.some((step) => step.status === "active") };
    }),
    recentActivity: done.slice(-3).reverse().map((step) => ({ time: "已完成", text: step.title })),
  };
  const update = (state: NativeState) => {
    const updated = state.spaces.find((space) => space.id === localSpace.id);
    if (updated) setLocalSpace(updated);
    onNativeChange?.(state);
  };
  const completionPhoto = useCompletionPhoto((state) => { update(state); onBack(); });
  const perform = async (action: () => Promise<void>) => {
    if (submitting.current) return;
    submitting.current = true; setBusy(true); setError("");
    try { await action(); }
    catch (cause) {
      const message = cause instanceof Error ? cause.message : "操作保存失败，请重试。";
      if (message !== "已取消") setError(message);
    } finally { submitting.current = false; setBusy(false); }
  };
  const togglePause = () => perform(async () => {
    if (!plan || allDone) return;
    update(await nativeRequest<NativeState>("plan.pause.set", { spaceID: localSpace.id, planID: plan.id, isPaused: !plan.isPaused }));
    setExecuting(false);
  });
  const continuePlan = () => perform(async () => {
    if (!plan) return;
    const state = await nativeRequest<NativeState>("space.select", { id: localSpace.id });
    const selectedPlan = state.spaces.find((space) => space.id === localSpace.id)?.activePlan;
    if (selectedPlan?.id !== plan.id) throw new Error("方案已更新，请返回空间页重新打开。");
    if (allDone) {
      await completionPhoto.choose(localSpace.id);
    } else if (plan.isPaused) {
      update(await nativeRequest<NativeState>("plan.pause.set", { spaceID: localSpace.id, planID: plan.id, isPaused: false }));
      setExecuting(true);
    } else if (executing && currentStep) {
      update(await nativeRequest<NativeState>("plan.step.complete", { id: currentStep.id }));
    } else { update(state); setExecuting(true); }
  });
  const completedZones = space.zones.filter((z) => z.done).length;

  return (
    <div className="fixed inset-0 z-[60] overflow-hidden" style={{ backgroundColor: LINEN }}>
      <div className="h-full w-full overflow-y-auto pb-32">
        {/* Hero */}
        <div className="relative w-full" style={{ height: 220 }}>
          <ImageWithFallback
            src={space.cover}
            alt={space.title}
            className="h-full w-full object-cover"
          />
          <div
            className="absolute inset-0"
            style={{
              background:
                "linear-gradient(180deg, rgba(123,92,72,0.4) 0%, rgba(0,0,0,0) 40%, rgba(246,241,235,0.95) 100%)",
            }}
          />
          <div className="absolute top-0 left-0 right-0 px-6 pt-14 flex items-center justify-between">
            <button
              onClick={onBack}
              className="h-11 w-11 rounded-full flex items-center justify-center"
              style={{ backgroundColor: "rgba(255,255,255,0.9)" }}
            >
              <ArrowLeft size={20} color={COFFEE} />
            </button>
            <div
              className="px-3 py-1.5 flex items-center gap-1.5"
              style={{ backgroundColor: "rgba(255,255,255,0.9)", borderRadius: 999 }}
            >
              <Flame size={12} color={ORANGE} />
              <span style={{ color: COFFEE, fontSize: 11, fontWeight: 600 }}>
                已完成 {space.streak} 次整理
              </span>
            </div>
          </div>
          <div className="absolute bottom-3 left-6 right-6">
            <span
              className="inline-block px-3 py-1 mb-2"
              style={{ backgroundColor: BLUE, color: WHITE, borderRadius: 999, fontSize: 10 }}
            >
              {plan?.isPaused ? "已暂停" : allDone ? "待保存完成照" : "进行中"}
            </span>
            <p style={{ color: COFFEE, fontSize: 24, fontWeight: 600 }}>{space.title}</p>
          </div>
        </div>

        {/* Ring + stats */}
        <div
          className="mx-6 -mt-2 p-5 flex items-center gap-4"
          style={{
            backgroundColor: WHITE,
            borderRadius: 24,
            boxShadow: "0 6px 24px rgba(123,92,72,0.08)",
          }}
        >
          <Ring value={space.progress} size={140} />
          <div className="flex-1 space-y-2">
            <Row icon={<Clock size={14} />} label="预计用时" value={space.estimate} />
            <Row
              icon={<CheckCircle2 size={14} />}
              label="区域"
              value={`${completedZones} / ${space.zones.length}`}
            />
            <Row
              icon={<Flame size={14} />}
              label="整理记录"
              value={`${space.streak} 次`}
              highlight
            />
          </div>
        </div>

        {/* Progress bar */}
        <div className="px-6 mt-6">
          <div className="flex items-center justify-between mb-2">
            <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>整体</p>
            <span style={{ color: ORANGE, fontSize: 12, fontWeight: 600 }}>
              {space.progress}%
            </span>
          </div>
          <div
            className="h-3 w-full rounded-full overflow-hidden"
            style={{ backgroundColor: WHITE }}
          >
            <div
              className="h-full rounded-full"
              style={{
                width: `${space.progress}%`,
                background: `linear-gradient(90deg, ${ORANGE} 0%, #FFAA66 100%)`,
              }}
            />
          </div>
        </div>

        {executing && currentStep && <div ref={activeStepRef} className="mx-6 mt-6 p-5" style={{ backgroundColor: WHITE, borderRadius: 22 }}>
          <p style={{ color: ORANGE, fontSize: 11, fontWeight: 600 }}>当前步骤</p>
          <h2 className="mt-2" style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>{currentStep.title}</h2>
          <p className="mt-2" style={{ color: COFFEE, opacity: 0.7, fontSize: 13, lineHeight: 1.7 }}>{currentStep.detail}</p>
        </div>}
        {error && <p role="alert" className="mx-6 mt-4" style={{ color: "#9A4230", fontSize: 12 }}>{error}</p>}
        {!plan && <p className="mx-6 mt-4" style={{ color: COFFEE, opacity: 0.6, fontSize: 13 }}>这个空间暂无进行中的整理计划。</p>}

        {/* Zones step list */}
        <div className="px-6 mt-7 mb-3">
          <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>区域</p>
          <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginTop: 2 }}>
            Step-by-step breakdown
          </p>
        </div>
        <div className="px-6">
          {space.zones.map((z, i) => {
            const last = i === space.zones.length - 1;
            return (
              <div key={z.id} className="flex gap-3">
                <div className="flex flex-col items-center">
                  <div
                    className="h-9 w-9 rounded-full flex items-center justify-center"
                    style={{
                      backgroundColor: z.done ? ORANGE : z.current ? WHITE : SOFT,
                      border: z.current ? `2px solid ${ORANGE}` : "none",
                      boxShadow: z.current ? "0 0 0 4px rgba(250,136,58,0.18)" : "none",
                    }}
                  >
                    {z.done ? (
                      <CheckCircle2 size={18} color={WHITE} />
                    ) : (
                      <Circle size={18} color={z.current ? ORANGE : COFFEE} opacity={z.current ? 1 : 0.4} />
                    )}
                  </div>
                  {!last && (
                    <div
                      className="w-[2px] flex-1 my-1"
                      style={{ backgroundColor: z.done ? ORANGE : SOFT, minHeight: 30 }}
                    />
                  )}
                </div>
                <div
                  className="flex-1 mb-3 p-3 flex items-center justify-between"
                  style={{
                    backgroundColor: z.current ? WHITE : "transparent",
                    borderRadius: 16,
                    boxShadow: z.current ? "0 4px 14px rgba(123,92,72,0.06)" : "none",
                  }}
                >
                  <div>
                    <p
                      style={{
                        color: COFFEE,
                        fontSize: 13,
                        fontWeight: z.current ? 600 : 500,
                        opacity: z.done ? 0.55 : 1,
                        textDecoration: z.done ? "line-through" : "none",
                      }}
                    >
                      {z.name}
                    </p>
                    <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginTop: 2 }}>
                      {z.tasks} tasks
                    </p>
                  </div>
                  {z.current && (
                    <span
                      className="px-2.5 py-1"
                      style={{
                        backgroundColor: ORANGE,
                        color: WHITE,
                        borderRadius: 999,
                        fontSize: 10,
                        fontWeight: 600,
                      }}
                    >
                      ACTIVE
                    </span>
                  )}
                </div>
              </div>
            );
          })}
        </div>

        {/* Recent activity */}
        <div className="px-6 mt-5 mb-3">
          <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>最近动态</p>
        </div>
        <div className="px-6 space-y-2">
          {space.recentActivity.map((a, i) => (
            <div
              key={i}
              className="flex gap-3 p-3"
              style={{ backgroundColor: WHITE, borderRadius: 14 }}
            >
              <div
                className="h-2 w-2 rounded-full mt-1.5 flex-shrink-0"
                style={{ backgroundColor: i === 0 ? ORANGE : BLUE }}
              />
              <div className="flex-1">
                <p style={{ color: COFFEE, fontSize: 12 }}>{a.text}</p>
                <p style={{ color: COFFEE, opacity: 0.5, fontSize: 10, marginTop: 2 }}>{a.time}</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Resume CTA */}
      <div className="absolute left-0 right-0 bottom-0 px-6 pb-6 pt-3" style={{ background: `linear-gradient(0deg, ${LINEN} 70%, transparent)` }}>
        <div className="flex gap-2">
          <button
            type="button"
            disabled={busy || !plan || allDone}
            onClick={() => void togglePause()}
            className="h-14 px-5 rounded-full flex items-center justify-center gap-2"
            style={{ backgroundColor: WHITE, color: COFFEE, fontSize: 13, fontWeight: 600 }}
          >
            {plan?.isPaused ? <Play size={16} /> : <Pause size={16} />} {plan?.isPaused ? "继续" : "暂停"}
          </button>
          <button
            type="button"
            disabled={busy || completionPhoto.busy || !plan}
            onClick={() => void continuePlan()}
            className="flex-1 h-14 rounded-full flex items-center justify-center gap-2"
            style={{
              backgroundColor: ORANGE,
              color: WHITE,
              fontSize: 14,
              fontWeight: 600,
              boxShadow: "0 8px 24px rgba(250,136,58,0.35)",
            }}
          >
            <Play size={16} fill={WHITE} /> {busy || completionPhoto.busy ? "处理中…" : allDone ? "保存完成照" : executing && !plan?.isPaused ? "完成当前步骤" : "继续整理"}
          </button>
        </div>
      </div>
      {completionPhoto.error && !completionPhoto.preview && <p role="alert" className="absolute bottom-28 left-6 right-6 text-center" style={{ color: "#9A4230", fontSize: 12 }}>{completionPhoto.error}</p>}
      <CompletionPhotoReview preview={completionPhoto.preview} busy={completionPhoto.busy} error={completionPhoto.error} onLater={() => void completionPhoto.discard()} onReselect={() => void completionPhoto.reselect()} onCommit={() => void completionPhoto.commit()} />
    </div>
  );
}

function Row({
  icon,
  label,
  value,
  highlight,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  highlight?: boolean;
}) {
  return (
    <div className="flex items-center gap-2">
      <div style={{ color: highlight ? ORANGE : COFFEE, opacity: highlight ? 1 : 0.6 }}>{icon}</div>
      <span style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>{label}</span>
      <span
        className="ml-auto"
        style={{ color: highlight ? ORANGE : COFFEE, fontSize: 12, fontWeight: 600 }}
      >
        {value}
      </span>
    </div>
  );
}
