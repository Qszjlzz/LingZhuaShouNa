import { useState } from "react";
import {
  ArrowLeft,
  Bookmark,
  Clock,
  Layers,
  Sparkles,
  CheckCircle2,
  Play,
  ListChecks,
} from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { nativeRequest } from "../nativeBridge";

const COVER =
  "https://images.unsplash.com/photo-1775029918191-32e44ee20d06?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080";

// 案例轻量类型：数据来自原生 communityCases
export type TryPlanCase = {
  id: string;
  title: string;
  author: string;
  style: string;
  durationText: string;
  difficultyText: string;
  items: { id: string; name: string; category: string; suggestedZone: string }[];
};

// 通用整理方法（方法论描述，不绑定任何虚构场景）
const steps = [
  "清空目标区域 — 把物品集中到一处",
  "按类别分类，而不是按位置",
  "做取舍：把不需要的物品单独放一堆",
  "给每类物品指定固定归位区域",
  "完成后拍前后对比，沉淀为自己的案例",
];

const durations = [
  { id: "fast", label: "快速模式", minutes: 5, sub: "5分钟", desc: "只做最快见效的部分" },
  { id: "standard", label: "标准方案", minutes: 10, sub: "10分钟", desc: "完成主要区域归位" },
  { id: "deep", label: "深度整理", minutes: 60, sub: "60分钟", desc: "全区域完整复盘" },
];

export function TryPlanScreen({
  onBack,
  caseItem,
  spaces,
  onNativeChange,
}: {
  onBack: () => void;
  caseItem?: TryPlanCase | null;
  spaces?: string[];
  onNativeChange?: () => void;
}) {
  const [duration, setDuration] = useState("standard");
  const [saved, setSaved] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [starting, setStarting] = useState(false);
  const [startResult, setStartResult] = useState<string | null>(null);

  const author = caseItem?.author || "社区作者";
  const items = caseItem?.items ?? [];
  const spaceOptions = (spaces && spaces.length ? spaces : ["默认空间"]).slice(0, 6);
  const [linkedSpace, setLinkedSpace] = useState(spaceOptions[0]);

  // 区域分解：案例物品按建议归位区域分组
  const zoneNames = Array.from(new Set(items.map((item) => item.suggestedZone || "待规划区域")));
  const zones = zoneNames.map((name, index) => ({
    id: `z${index}`,
    name,
    tasks: items.filter((item) => (item.suggestedZone || "待规划区域") === name).length,
    time: caseItem?.durationText || "10分钟",
  }));

  const chosen = durations.find((d) => d.id === duration) ?? durations[1];

  return (
    <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: LINEN }}>
      <div className="h-full w-full overflow-y-auto pb-32">
        {/* Hero */}
        <div className="relative w-full" style={{ height: 220 }}>
          <ImageWithFallback src={COVER} alt="方案" className="h-full w-full object-cover" />
          <div
            className="absolute inset-0"
            style={{
              background:
                "linear-gradient(180deg, rgba(123,92,72,0.45) 0%, rgba(0,0,0,0) 40%, rgba(246,241,235,0.95) 100%)",
            }}
          />

          <div className="absolute top-0 left-0 right-0 px-5 pt-14 flex items-center justify-between">
            <button
              onClick={onBack}
              className="h-10 w-10 rounded-full flex items-center justify-center"
              style={{ backgroundColor: "rgba(255,255,255,0.92)" }}
            >
              <ArrowLeft size={20} color={COFFEE} />
            </button>
            <button
              onClick={() => {
                if (!caseItem) return;
                setSaved((s) => !s);
                void nativeRequest("community.favorite", { id: caseItem.id })
                  .then(() => onNativeChange?.())
                  .catch(() => undefined);
              }}
              className="h-10 w-10 rounded-full flex items-center justify-center"
              style={{ backgroundColor: "rgba(255,255,255,0.92)" }}
            >
              <Bookmark
                size={18}
                color={saved ? ORANGE : COFFEE}
                fill={saved ? ORANGE : "none"}
              />
            </button>
          </div>

          <div className="absolute bottom-3 left-5 right-5">
            <span
              className="inline-block px-3 py-1 mb-2"
              style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, fontSize: 10, fontWeight: 600 }}
            >
              共享方案 · {caseItem?.style || "快速复原"}
            </span>
            <p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>
              {caseItem?.title || "社区方案"}
            </p>
            <div className="flex items-center gap-2 mt-1.5">
              <div
                className="h-6 w-6 rounded-full flex items-center justify-center"
                style={{ backgroundColor: "#E8B894", color: WHITE, fontSize: 10, fontWeight: 600 }}
              >
                {String(author).slice(0, 1)}
              </div>
              <span style={{ color: COFFEE, fontSize: 12, opacity: 0.75 }}>来自 {author}</span>
            </div>
          </div>
        </div>

        {/* Stat row */}
        <div className="px-5 mt-3">
          <div
            className="flex p-4"
            style={{
              backgroundColor: WHITE,
              borderRadius: 22,
              boxShadow: "0 4px 18px rgba(123,92,72,0.06)",
            }}
          >
            <Stat icon={<Clock size={16} color={ORANGE} />} value={caseItem?.durationText || "10分钟"} label="总计" />
            <Divider />
            <Stat icon={<Layers size={16} color={ORANGE} />} value={String(zones.length)} label="区域" />
            <Divider />
            <Stat icon={<ListChecks size={16} color={ORANGE} />} value={String(items.length)} label="物品" />
            <Divider />
            <Stat icon={<Sparkles size={16} color={ORANGE} />} value={caseItem?.difficultyText || "低压力"} label="难度" />
          </div>
        </div>

        {/* Linked space picker */}
        <div className="px-5 mt-5">
          <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600, marginBottom: 8 }}>
            应用到空间
          </p>
          <div className="flex gap-2 overflow-x-auto">
            {spaceOptions.map((s) => {
              const active = s === linkedSpace;
              return (
                <button
                  key={s}
                  onClick={() => setLinkedSpace(s)}
                  className="px-4 py-2.5 flex-shrink-0"
                  style={{
                    backgroundColor: active ? COFFEE : WHITE,
                    color: active ? WHITE : COFFEE,
                    borderRadius: 14,
                    fontSize: 12,
                    fontWeight: active ? 600 : 500,
                  }}
                >
                  {s}
                </button>
              );
            })}
          </div>
        </div>

        {/* Duration plans */}
        <div className="px-5 mt-6">
          <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600, marginBottom: 10 }}>
            选择节奏
          </p>
          <div className="space-y-2">
            {durations.map((d) => {
              const active = duration === d.id;
              return (
                <button
                  key={d.id}
                  onClick={() => setDuration(d.id)}
                  className="w-full flex items-center gap-3 px-4 py-3 text-left"
                  style={{
                    backgroundColor: WHITE,
                    borderRadius: 18,
                    boxShadow: active
                      ? `0 0 0 2px ${ORANGE}, 0 6px 16px rgba(250,136,58,0.18)`
                      : "0 4px 14px rgba(123,92,72,0.04)",
                    transition: "box-shadow 0.15s",
                  }}
                >
                  <div
                    className="h-10 w-10 rounded-2xl flex items-center justify-center"
                    style={{
                      backgroundColor: active ? ORANGE : LINEN,
                      color: active ? WHITE : COFFEE,
                      fontSize: 11,
                      fontWeight: 600,
                    }}
                  >
                    {d.sub.split(" ")[0]}
                  </div>
                  <div className="flex-1">
                    <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{d.label}</p>
                    <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginTop: 1 }}>
                      {d.desc}
                    </p>
                  </div>
                  <div
                    className="h-5 w-5 rounded-full flex items-center justify-center"
                    style={{
                      backgroundColor: active ? ORANGE : "transparent",
                      border: active ? "none" : `2px solid ${SOFT}`,
                    }}
                  >
                    {active && <CheckCircle2 size={14} color={WHITE} />}
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Zones breakdown */}
        <div className="px-5 mt-7 mb-3 flex items-center justify-between">
          <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>区域分解</p>
          <span style={{ color: ORANGE, fontSize: 12 }}>自定义</span>
        </div>
        <div className="px-5 space-y-2">
          {zones.map((z, i) => (
            <div
              key={z.id}
              className="flex items-center gap-3 px-4 py-3"
              style={{
                backgroundColor: WHITE,
                borderRadius: 16,
                boxShadow: "0 4px 12px rgba(123,92,72,0.04)",
              }}
            >
              <div
                className="h-9 w-9 rounded-full flex items-center justify-center"
                style={{
                  backgroundColor: i === 0 ? ORANGE : BLUE,
                  color: WHITE,
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                {i + 1}
              </div>
              <div className="flex-1">
                <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{z.name}</p>
                <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>
                  {z.tasks} 个任务
                </p>
              </div>
              <span
                className="px-2.5 py-1"
                style={{
                  backgroundColor: LINEN,
                  color: COFFEE,
                  borderRadius: 999,
                  fontSize: 11,
                  fontWeight: 600,
                }}
              >
                {z.time}
              </span>
            </div>
          ))}
        </div>

        {/* Method (5 steps) */}
        <div className="px-5 mt-7 mb-3">
          <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>整理方法</p>
          <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginTop: 2 }}>
            贯穿始终的5条原则
          </p>
        </div>
        <div className="px-5 space-y-2.5">
          {steps.map((s, i) => (
            <div
              key={i}
              className="flex gap-3 p-3 items-start"
              style={{
                backgroundColor: WHITE,
                borderRadius: 14,
                boxShadow: "0 3px 10px rgba(123,92,72,0.03)",
              }}
            >
              <div
                className="h-7 w-7 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5"
                style={{ backgroundColor: ORANGE, color: WHITE, fontSize: 11, fontWeight: 600 }}
              >
                {i + 1}
              </div>
              <p style={{ color: COFFEE, fontSize: 12, lineHeight: 1.5 }}>{s}</p>
            </div>
          ))}
        </div>

        {/* Items in this case */}
        <div className="px-5 mt-7 mb-3">
          <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>案例涉及的物品</p>
        </div>
        <div className="px-5 grid grid-cols-2 gap-2.5">
          {items.length === 0 && (
            <div className="col-span-2 p-4 text-center" style={{ backgroundColor: WHITE, borderRadius: 14 }}>
              <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>该案例没有登记具体物品</p>
            </div>
          )}
          {items.map((t, index) => (
            <div
              key={`${t.id}-${index}`}
              className="flex items-center gap-2 px-3 py-2.5"
              style={{
                backgroundColor: WHITE,
                borderRadius: 14,
                border: `1px solid ${SOFT}`,
              }}
            >
              <CheckCircle2 size={16} color={ORANGE} />
              <div className="flex-1 min-w-0">
                <p style={{ color: COFFEE, fontSize: 11, fontWeight: 600 }}>{t.name}</p>
                <p style={{ color: COFFEE, opacity: 0.5, fontSize: 10 }}>{t.category}</p>
              </div>
            </div>
          ))}
        </div>

        {/* AI personalization */}
        <div
          className="mx-5 mt-6 p-4 flex items-center gap-3"
          style={{
            background: `linear-gradient(135deg, ${ORANGE} 0%, #FFAA66 100%)`,
            borderRadius: 20,
          }}
        >
          <div
            className="h-10 w-10 rounded-full flex items-center justify-center"
            style={{ backgroundColor: "rgba(255,255,255,0.25)" }}
          >
            <Sparkles size={18} color={WHITE} />
          </div>
          <div className="flex-1">
            <p style={{ color: WHITE, fontSize: 13, fontWeight: 600 }}>
              AI 将调整此方案
            </p>
            <p style={{ color: WHITE, opacity: 0.85, fontSize: 11 }}>
              将按 {chosen.label}（{chosen.sub}）为目标生成你自己的方案
            </p>
          </div>
        </div>
      </div>

      {/* Bottom CTA */}
      <div
        className="absolute bottom-0 left-0 right-0 px-5 pt-3 pb-6"
        style={{
          background: "linear-gradient(180deg, rgba(246,241,235,0) 0%, rgba(246,241,235,1) 30%)",
        }}
      >
        <div className="flex gap-2">
          <button
            onClick={() => {
              if (!caseItem) return;
              setSaved(true);
              void nativeRequest("community.favorite", { id: caseItem.id })
                .then(() => onNativeChange?.())
                .catch(() => undefined);
            }}
            className="h-14 px-4 rounded-full flex items-center justify-center gap-2"
            style={{
              backgroundColor: WHITE,
              color: COFFEE,
              fontSize: 12,
              fontWeight: 600,
              boxShadow: "0 4px 14px rgba(123,92,72,0.06)",
            }}
          >
            <Bookmark size={16} fill={saved ? ORANGE : "none"} color={saved ? ORANGE : COFFEE} />
            {saved ? "已收藏" : "收藏"}
          </button>
          <button
            onClick={() => setConfirming(true)}
            className="flex-1 h-14 rounded-full flex items-center justify-center gap-2"
            style={{
              backgroundColor: ORANGE,
              color: WHITE,
              fontSize: 14,
              fontWeight: 600,
              boxShadow: "0 8px 24px rgba(250,136,58,0.35)",
            }}
          >
            <Play size={16} fill={WHITE} /> 开始此方案
          </button>
        </div>
      </div>

      {/* Confirmation modal */}
      {confirming && (
        <div
          className="absolute inset-0 z-50 flex items-center justify-center px-7"
          style={{ backgroundColor: "rgba(45,32,26,0.5)" }}
          onClick={() => setConfirming(false)}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="w-full p-6"
            style={{ backgroundColor: WHITE, borderRadius: 28 }}
          >
            <div
              className="h-14 w-14 rounded-2xl flex items-center justify-center mb-4 mx-auto"
              style={{ backgroundColor: ORANGE, boxShadow: "0 8px 20px rgba(250,136,58,0.35)" }}
            >
              <Play size={22} color={WHITE} fill={WHITE} />
            </div>
            <p
              style={{
                color: COFFEE,
                fontSize: 17,
                fontWeight: 600,
                textAlign: "center",
              }}
            >
              开始方案？
            </p>
            <p
              style={{
                color: COFFEE,
                opacity: 0.6,
                fontSize: 12,
                textAlign: "center",
                marginTop: 6,
                lineHeight: 1.5,
              }}
            >
              "{caseItem?.title || "社区方案"}"方案将应用到<b>{linkedSpace}</b> · 节奏<b>{chosen.label}</b>。
              你可以随时暂停。
            </p>
            {startResult && (
              <p style={{ color: ORANGE, fontSize: 12, textAlign: "center", marginTop: 8 }}>{startResult}</p>
            )}
            <div className="flex gap-2 mt-5">
              <button
                onClick={() => setConfirming(false)}
                className="flex-1 py-3"
                style={{
                  backgroundColor: LINEN,
                  color: COFFEE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                取消
              </button>
              <button
                onClick={() => {
                  if (!caseItem || starting) return;
                  setStarting(true);
                  setStartResult(null);
                  void nativeRequest("plan.generate", {
                    style: caseItem.style,
                    minutes: chosen.minutes,
                    goal: caseItem.title,
                    focusZone: "",
                  })
                    .then(() => {
                      setStarting(false);
                      setStartResult("方案已生成，返回空间地图查看");
                      onNativeChange?.();
                      setTimeout(() => onBack(), 900);
                    })
                    .catch((error) => {
                      setStarting(false);
                      setStartResult(error instanceof Error ? error.message : "生成失败，请重试");
                    });
                }}
                className="flex-1 py-3"
                style={{
                  backgroundColor: ORANGE,
                  color: WHITE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                  opacity: starting ? 0.6 : 1,
                  boxShadow: "0 6px 16px rgba(250,136,58,0.3)",
                }}
              >
                {starting ? "生成中…" : "开始"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function Stat({
  icon,
  value,
  label,
}: {
  icon: React.ReactNode;
  value: string;
  label: string;
}) {
  return (
    <div className="flex-1 flex flex-col items-center">
      {icon}
      <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600, marginTop: 4 }}>{value}</p>
      <p style={{ color: COFFEE, opacity: 0.55, fontSize: 10 }}>{label}</p>
    </div>
  );
}

function Divider() {
  return <div className="w-px self-stretch" style={{ backgroundColor: SOFT }} />;
}
