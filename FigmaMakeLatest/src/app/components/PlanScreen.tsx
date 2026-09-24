import { useState } from "react";
import { ArrowLeft, Sparkles, Check } from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";

const COFFEE = "#7B5C48";
const ORANGE = "#FA883A";
const LINEN = "#F6F1EB";
const BLUE = "#B4C7DC";

const durations = ["5min", "10min", "1h"] as const;
type Duration = (typeof durations)[number];

const zones = [
  { n: 1, label: "Coffee Table", left: "12%", top: "38%", w: "32%", h: "26%" },
  { n: 2, label: "Sofa Area", left: "46%", top: "28%", w: "38%", h: "42%" },
  { n: 3, label: "Shelf Corner", left: "8%", top: "8%", w: "28%", h: "24%" },
];

export function PlanScreen({ onBack }: { onBack: () => void }) {
  const [selected, setSelected] = useState<Duration>("10min");
  const [activeZone] = useState(1);

  return (
    <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: LINEN }}>
      {/* Top photo */}
      <div className="relative h-[58%] w-full overflow-hidden">
        <ImageWithFallback
          src="https://images.unsplash.com/photo-1768548273848-ebab6f26b48c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080"
          alt="Living room"
          className="h-full w-full object-cover"
        />
        <div
          className="absolute inset-0"
          style={{
            background:
              "linear-gradient(180deg, rgba(123,92,72,0.25) 0%, rgba(123,92,72,0) 30%, rgba(246,241,235,0) 70%, rgba(246,241,235,0.4) 100%)",
          }}
        />

        {/* Top bar */}
        <div className="absolute top-0 left-0 right-0 px-6 pt-14 flex items-center justify-between">
          <button
            onClick={onBack}
            className="h-11 w-11 rounded-full flex items-center justify-center"
            style={{ backgroundColor: "rgba(255,255,255,0.9)" }}
          >
            <ArrowLeft size={20} color={COFFEE} />
          </button>
          <div
            className="px-4 py-2 flex items-center gap-2"
            style={{ backgroundColor: "rgba(255,255,255,0.9)", borderRadius: "999px" }}
          >
            <Sparkles size={14} color={ORANGE} />
            <span style={{ color: COFFEE, fontSize: "12px" }}>AI 识别到 3 个区域</span>
          </div>
        </div>

        {/* Bounding boxes */}
        {zones.map((z) => (
          <div
            key={z.n}
            className="absolute"
            style={{
              left: z.left,
              top: z.top,
              width: z.w,
              height: z.h,
              border: `2.5px solid ${ORANGE}`,
              borderRadius: "16px",
              boxShadow: `0 0 0 4px rgba(250,136,58,0.15), 0 0 24px rgba(250,136,58,0.4)`,
              backgroundColor: "rgba(250,136,58,0.08)",
            }}
          >
            <div
              className="absolute -top-3 -left-3 h-8 w-8 rounded-full flex items-center justify-center"
              style={{
                backgroundColor: ORANGE,
                color: "#FFFFFF",
                fontSize: "13px",
                fontWeight: 600,
                boxShadow: "0 4px 12px rgba(250,136,58,0.5)",
              }}
            >
              {z.n}
            </div>
            <div
              className="absolute -bottom-3 left-3 px-2 py-1"
              style={{
                backgroundColor: "#FFFFFF",
                color: COFFEE,
                fontSize: "10px",
                borderRadius: "8px",
                boxShadow: "0 2px 8px rgba(0,0,0,0.1)",
              }}
            >
              {z.label}
            </div>
          </div>
        ))}
      </div>

      {/* Bottom sheet */}
      <div
        className="absolute bottom-0 left-0 right-0 px-6 pt-7 pb-8"
        style={{
          backgroundColor: "#FFFFFF",
          borderTopLeftRadius: "32px",
          borderTopRightRadius: "32px",
          height: "48%",
          boxShadow: "0 -8px 30px rgba(123,92,72,0.08)",
        }}
      >
        <div className="flex items-center justify-center mb-5">
          <div className="h-1 w-10 rounded-full" style={{ backgroundColor: "#EFE6DC" }} />
        </div>

        <div className="flex items-center justify-between mb-4">
          <p style={{ color: COFFEE, fontSize: "18px", fontWeight: 600 }}>选择方案</p>
          <span style={{ color: COFFEE, opacity: 0.5, fontSize: "12px" }}>选择时长</span>
        </div>

        <div className="grid grid-cols-3 gap-3 mb-6">
          {durations.map((d) => {
            const active = selected === d;
            return (
              <button
                key={d}
                onClick={() => setSelected(d)}
                className="py-3 transition-all"
                style={{
                  backgroundColor: active ? ORANGE : LINEN,
                  color: active ? "#FFFFFF" : COFFEE,
                  borderRadius: "16px",
                  fontSize: "14px",
                  fontWeight: active ? 600 : 500,
                  boxShadow: active ? "0 6px 16px rgba(250,136,58,0.3)" : "none",
                }}
              >
                {d}
              </button>
            );
          })}
        </div>

        {/* Zone progress tracker */}
        <div className="flex items-center justify-between mb-7 px-1">
          {[1, 2, 3].map((n, i) => (
            <div key={n} className="flex items-center flex-1 last:flex-none">
              <div className="flex flex-col items-center">
                <div
                  className="h-9 w-9 rounded-full flex items-center justify-center"
                  style={{
                    backgroundColor: n === activeZone ? ORANGE : n < activeZone ? BLUE : LINEN,
                    color: n <= activeZone ? "#FFFFFF" : COFFEE,
                    fontSize: "13px",
                    fontWeight: 600,
                  }}
                >
                  {n < activeZone ? <Check size={16} /> : n}
                </div>
                <span
                  style={{
                    color: COFFEE,
                    fontSize: "10px",
                    marginTop: 6,
                    opacity: n === activeZone ? 1 : 0.5,
                  }}
                >
                  Zone {n}
                </span>
              </div>
              {i < 2 && (
                <div
                  className="flex-1 h-[2px] mx-2 mb-4"
                  style={{ backgroundColor: n < activeZone ? BLUE : "#EFE6DC" }}
                />
              )}
            </div>
          ))}
        </div>

        <button
          className="w-full py-4"
          style={{
            backgroundColor: ORANGE,
            color: "#FFFFFF",
            borderRadius: "999px",
            fontSize: "15px",
            fontWeight: 600,
            boxShadow: "0 8px 24px rgba(250,136,58,0.35)",
          }}
        >
          Start Cleaning Zone 1
        </button>
      </div>
    </div>
  );
}
