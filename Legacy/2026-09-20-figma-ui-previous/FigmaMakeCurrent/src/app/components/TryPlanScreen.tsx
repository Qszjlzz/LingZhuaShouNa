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

const COVER =
  "https://images.unsplash.com/photo-1775029918191-32e44ee20d06?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080";

const zones = [
  { id: "z1", name: "悬挂区", time: "12分钟", tasks: 5 },
  { id: "z2", name: "折叠堆叠区", time: "18分钟", tasks: 7 },
  { id: "z3", name: "配饰抽屉", time: "8分钟", tasks: 4 },
  { id: "z4", name: "捐赠堆", time: "10分钟", tasks: 3 },
];

const steps = [
  "把所有东西倒在床上 — 不要跳过",
  "按类别分类，而不是按抽屉",
  "捐赠12个月内没穿过的任何衣物",
  "使用纤薄天鹅绒衣架 — 节省40%空间",
  "把针织衫垂直卷放在浅篮子里",
];

const tools = [
  { name: "纤薄天鹅绒衣架", count: "×30" },
  { name: "软质收纳篮（L）", count: "×4" },
  { name: "抽屉分隔板", count: "×6" },
  { name: "捐赠袋", count: "×1" },
];

const durations = [
  { id: "express", label: "快速模式", sub: "30分钟", desc: "跳过捐赠阶段" },
  { id: "full", label: "完整方案", sub: "1小时12分钟", desc: "Mira分享的版本" },
  { id: "deep", label: "深度整理", sub: "2小时", desc: "+ 深度清洁" },
];

export function TryPlanScreen({ onBack }: { onBack: () => void }) {
  const [duration, setDuration] = useState("full");
  const [linkedSpace, setLinkedSpace] = useState("我的衣柜");
  const [saved, setSaved] = useState(false);
  const [confirming, setConfirming] = useState(false);

  return (
    <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: LINEN }}>
      <div className="h-full w-full overflow-y-auto pb-32">
        {/* Hero */}
        <div className="relative w-full" style={{ height: 220 }}>
          <ImageWithFallback src={COVER} alt="Plan" className="h-full w-full object-cover" />
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
              onClick={() => setSaved((s) => !s)}
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
              共享方案 · 1.2k 次尝试
            </span>
            <p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>
              小公寓衣柜
            </p>
            <div className="flex items-center gap-2 mt-1.5">
              <div
                className="h-6 w-6 rounded-full flex items-center justify-center"
                style={{ backgroundColor: "#E8B894", color: WHITE, fontSize: 10, fontWeight: 600 }}
              >
                M
              </div>
              <span style={{ color: COFFEE, fontSize: 12, opacity: 0.75 }}>来自 Mira</span>
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
            <Stat icon={<Clock size={16} color={ORANGE} />} value="1小时12分" label="总计" />
            <Divider />
            <Stat icon={<Layers size={16} color={ORANGE} />} value="4" label="区域" />
            <Divider />
            <Stat icon={<ListChecks size={16} color={ORANGE} />} value="19" label="任务" />
            <Divider />
            <Stat icon={<Sparkles size={16} color={ORANGE} />} value="A+" label="匹配度" />
          </div>
        </div>

        {/* Linked space picker */}
        <div className="px-5 mt-5">
          <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600, marginBottom: 8 }}>
            应用到空间
          </p>
          <div className="flex gap-2 overflow-x-auto">
            {["我的衣柜", "备用衣柜", "+ 新空间"].map((s) => {
              const active = s === linkedSpace;
              const isAdd = s.startsWith("+");
              return (
                <button
                  key={s}
                  onClick={() => !isAdd && setLinkedSpace(s)}
                  className="px-4 py-2.5 flex-shrink-0"
                  style={{
                    backgroundColor: active ? COFFEE : WHITE,
                    color: active ? WHITE : COFFEE,
                    borderRadius: 14,
                    fontSize: 12,
                    fontWeight: active ? 600 : 500,
                    border: isAdd ? `1.5px dashed ${ORANGE}` : "none",
                  }}
                >
                  {isAdd ? <span style={{ color: ORANGE }}>{s}</span> : s}
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

        {/* Tools needed */}
        <div className="px-5 mt-7 mb-3">
          <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>所需工具</p>
        </div>
        <div className="px-5 grid grid-cols-2 gap-2.5">
          {tools.map((t) => (
            <div
              key={t.name}
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
                <p style={{ color: COFFEE, opacity: 0.5, fontSize: 10 }}>{t.count}</p>
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
              根据你的空间大小和物品数量
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
            onClick={() => setSaved((v) => !v)}
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
            {saved ? "已保存" : "保存"}
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
              "小公寓衣柜"方案将应用到<b>{linkedSpace}</b> · 节奏<b>{duration}</b>。
              你可以随时暂停。
            </p>
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
                  setConfirming(false);
                  onBack();
                }}
                className="flex-1 py-3"
                style={{
                  backgroundColor: ORANGE,
                  color: WHITE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                  boxShadow: "0 6px 16px rgba(250,136,58,0.3)",
                }}
              >
                开始
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
