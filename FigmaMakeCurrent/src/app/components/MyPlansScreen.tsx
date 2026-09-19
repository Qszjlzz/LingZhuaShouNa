import { useState } from "react";
import { ArrowLeft, Play, Pause, MoreHorizontal, Plus, Calendar, Clock } from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { CalendarScreen } from "./CalendarScreen";
import type { NativeState } from "../nativeBridge";

type Plan = {
  id: string;
  title: string;
  space: string;
  progress: number;
  status: "active" | "scheduled" | "paused" | "done";
  cover: string;
  nextAt: string;
  duration: string;
};

const plans: Plan[] = [
  {
    id: "p1",
    title: "小公寓衣柜",
    space: "卧室",
    progress: 35,
    status: "active",
    cover:
      "https://images.unsplash.com/photo-1775029918191-32e44ee20d06?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    nextAt: "立即继续",
    duration: "1小时12分钟",
  },
  {
    id: "p2",
    title: "5分钟厨房整理",
    space: "厨房",
    progress: 60,
    status: "paused",
    cover:
      "https://images.unsplash.com/photo-1772475385491-f3cf64d4131a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    nextAt: "昨天已暂停",
    duration: "30分钟",
  },
  {
    id: "p3",
    title: "周末办公室整理",
    space: "家庭办公室",
    progress: 0,
    status: "scheduled",
    cover:
      "https://images.unsplash.com/photo-1764588037085-a78240016f8b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    nextAt: "周六 上午10:00",
    duration: "45分钟",
  },
  {
    id: "p4",
    title: "储藏室深度清洁",
    space: "厨房",
    progress: 100,
    status: "done",
    cover:
      "https://images.unsplash.com/photo-1772475385426-ebd50c772229?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    nextAt: "4月28日",
    duration: "1小时30分钟",
  },
];

const tabs = ["全部", "进行中", "已计划", "已完成"] as const;

export function MyPlansScreen({ onBack, nativeState }: { onBack: () => void; nativeState?: NativeState | null }) {
  const [tab, setTab] = useState<(typeof tabs)[number]>("全部");
  const [openCalendar, setOpenCalendar] = useState(false);

  if (openCalendar) return <CalendarScreen onBack={() => setOpenCalendar(false)} />;

  const livePlans: Plan[] = nativeState?.spaces.flatMap((space, spaceIndex) => {
    const cover = plans[spaceIndex % plans.length].cover;
    const active = space.activePlan ? [{
      id: space.activePlan.id, title: space.activePlan.summary, space: space.name,
      progress: Math.round(space.activePlan.steps.filter((step) => step.status === "done").length / Math.max(space.activePlan.steps.length, 1) * 100),
      status: "active" as const, cover, nextAt: "立即继续", duration: `${space.activePlan.timeBudget}分钟`,
    }] : [];
    const completed = space.completedPlans.map((plan) => ({ id: plan.id, title: plan.summary, space: space.name,
      progress: 100, status: "done" as const, cover, nextAt: "已完成", duration: `${plan.timeBudget}分钟` }));
    return [...active, ...completed];
  }) ?? [];
  const filtered = livePlans.filter((p) => {
    if (tab === "全部") return true;
    if (tab === "进行中") return p.status === "active" || p.status === "paused";
    if (tab === "已计划") return p.status === "scheduled";
    return p.status === "done";
  });

  return (
    <div className="h-full w-full overflow-y-auto" style={{ backgroundColor: LINEN }}>
      <div className="px-6 pt-14 pb-2 flex items-center justify-between">
        <button
          onClick={onBack}
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ArrowLeft size={20} color={COFFEE} />
        </button>
        <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>我的方案</p>
        <button
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: ORANGE, boxShadow: "0 6px 16px rgba(250,136,58,0.3)" }}
        >
          <Plus size={20} color={WHITE} />
        </button>
      </div>

      {/* Summary */}
      <div className="px-6 mt-4">
        <div
          className="p-5 flex items-center gap-4"
          style={{
            background: `linear-gradient(135deg, ${COFFEE} 0%, #5d4334 100%)`,
            borderRadius: 24,
          }}
        >
          <div className="flex-1">
            <p style={{ color: WHITE, opacity: 0.7, fontSize: 11 }}>本周</p>
            <p style={{ color: WHITE, fontSize: 22, fontWeight: 600 }}>{livePlans.filter((plan) => plan.status === "active").length}个进行中方案</p>
            <p style={{ color: WHITE, opacity: 0.7, fontSize: 12, marginTop: 2 }}>
              共 {livePlans.reduce((sum, plan) => sum + Number.parseInt(plan.duration), 0)} 分钟
            </p>
          </div>
          <button
            onClick={() => setOpenCalendar(true)}
            className="h-16 w-16 rounded-2xl flex flex-col items-center justify-center"
            style={{ backgroundColor: "rgba(255,255,255,0.15)" }}
          >
            <Calendar size={20} color={WHITE} />
            <span style={{ color: WHITE, fontSize: 10, marginTop: 2 }}>查看</span>
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="px-6 mt-5 flex gap-2 overflow-x-auto">
        {tabs.map((t) => {
          const active = tab === t;
          return (
            <button
              key={t}
              onClick={() => setTab(t)}
              className="px-4 py-2 flex-shrink-0"
              style={{
                backgroundColor: active ? ORANGE : WHITE,
                color: active ? WHITE : COFFEE,
                borderRadius: 999,
                fontSize: 12,
                fontWeight: active ? 600 : 500,
              }}
            >
              {t}
            </button>
          );
        })}
      </div>

      {/* List */}
      <div className="px-6 mt-5 space-y-3 pb-10">
        {filtered.map((p) => (
          <PlanCard key={p.id} plan={p} />
        ))}
        {filtered.length === 0 && (
          <p
            className="text-center py-10"
            style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}
          >
            暂无方案
          </p>
        )}
      </div>
    </div>
  );
}

function PlanCard({ plan }: { plan: Plan }) {
  const status = {
    active: { label: "进行中", color: ORANGE },
    paused: { label: "已暂停", color: BLUE },
    scheduled: { label: "已计划", color: "#A88370" },
    done: { label: "已完成", color: "#7BB28F" },
  }[plan.status];

  return (
    <div
      style={{
        backgroundColor: WHITE,
        borderRadius: 22,
        overflow: "hidden",
        boxShadow: "0 4px 18px rgba(123,92,72,0.06)",
      }}
    >
      <div className="flex">
        <div className="w-24 h-24 flex-shrink-0">
          <ImageWithFallback src={plan.cover} alt={plan.title} className="h-full w-full object-cover" />
        </div>
        <div className="flex-1 p-3 min-w-0">
          <div className="flex items-center gap-2 mb-1">
            <span
              className="px-2 py-0.5"
              style={{
                backgroundColor: status.color,
                color: WHITE,
                borderRadius: 999,
                fontSize: 9,
                fontWeight: 600,
              }}
            >
              {status.label}
            </span>
            <span style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>{plan.space}</span>
          </div>
          <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{plan.title}</p>
          <div className="flex items-center gap-1 mt-1">
            <Clock size={11} color={COFFEE} opacity={0.55} />
            <span style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>
              {plan.nextAt} · {plan.duration}
            </span>
          </div>
        </div>
        <button
          className="px-3"
          style={{ color: COFFEE, opacity: 0.5 }}
        >
          <MoreHorizontal size={18} />
        </button>
      </div>
      {plan.status !== "done" && plan.status !== "scheduled" && (
        <div className="px-3 pb-3">
          <div className="flex items-center gap-2">
            <div
              className="flex-1 h-2 rounded-full overflow-hidden"
              style={{ backgroundColor: LINEN }}
            >
              <div
                className="h-full rounded-full"
                style={{
                  width: `${plan.progress}%`,
                  background: `linear-gradient(90deg, ${ORANGE} 0%, #FFAA66 100%)`,
                }}
              />
            </div>
            <span style={{ color: COFFEE, opacity: 0.6, fontSize: 11 }}>{plan.progress}%</span>
            <button
              className="h-8 px-3 rounded-full flex items-center gap-1"
              style={{
                backgroundColor: ORANGE,
                color: WHITE,
                fontSize: 11,
                fontWeight: 600,
              }}
            >
              {plan.status === "active" ? <Pause size={12} /> : <Play size={12} fill={WHITE} />}
              {plan.status === "active" ? "暂停" : "继续"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
