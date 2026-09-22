import { useState } from "react";
import { ArrowLeft, Share2, Heart, Lightbulb, Sparkles, MoveHorizontal } from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";

export type FinishedSpace = {
  id: string;
  title: string;
  items: number;
  duration: string;
  date: string;
  before: string;
  after: string;
  itemList: { name: string; cat: string; emoji: string }[];
  tips: { title: string; body: string }[];
};

const sample: FinishedSpace = {
  id: "s1",
  title: "Living Room",
  items: 24,
  duration: "32 min",
  date: "May 1, 2026",
  before:
    "https://images.unsplash.com/photo-1768548273848-ebab6f26b48c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
  after:
    "https://images.unsplash.com/photo-1749705319317-f9a2bf24fe3d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
  itemList: [
    { name: "Throw Blanket", cat: "Textile", emoji: "🧣" },
    { name: "Coffee Mug", cat: "Kitchen", emoji: "☕" },
    { name: "Magazines (×3)", cat: "Books", emoji: "📚" },
    { name: "Remote", cat: "Electronics", emoji: "📺" },
    { name: "Candle", cat: "Decor", emoji: "🕯️" },
    { name: "Sofa Cushions", cat: "Textile", emoji: "🛋️" },
  ],
  tips: [
    {
      title: "Use a tray for the coffee table",
      body: "Group remote, coaster, and candle on a single tray — visual order in 5 seconds.",
    },
    {
      title: "Vertical-fold blankets",
      body: "Roll instead of fold. Stand them in a basket so any one can be pulled without unstacking.",
    },
    {
      title: "Daily 2-minute reset",
      body: "Before bed, reset cushions & clear surfaces. The space stays 80% organized with zero effort.",
    },
  ],
};

export function FinishedSpaceDetail({
  onBack,
  space = sample,
}: {
  onBack: () => void;
  space?: FinishedSpace;
}) {
  const [slider, setSlider] = useState(50);

  return (
    <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: LINEN }}>
      <div className="h-full w-full overflow-y-auto pb-10">
        {/* Top bar */}
        <div className="px-6 pt-14 pb-2 flex items-center justify-between">
          <button
            onClick={onBack}
            className="h-11 w-11 rounded-full flex items-center justify-center"
            style={{ backgroundColor: WHITE }}
          >
            <ArrowLeft size={20} color={COFFEE} />
          </button>
          <div className="flex items-center gap-2">
            <div
              className="h-11 w-11 rounded-full flex items-center justify-center"
              style={{ backgroundColor: WHITE }}
            >
              <Heart size={18} color={COFFEE} />
            </div>
            <div
              className="h-11 w-11 rounded-full flex items-center justify-center"
              style={{ backgroundColor: WHITE }}
            >
              <Share2 size={18} color={COFFEE} />
            </div>
          </div>
        </div>

        {/* Title */}
        <div className="px-6 mt-3">
          <span
            className="inline-block px-3 py-1 mb-2"
            style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, fontSize: 10 }}
          >
            COMPLETED · {space.date}
          </span>
          <p style={{ color: COFFEE, fontSize: 26, fontWeight: 600 }}>{space.title}</p>
          <div className="flex gap-4 mt-2">
            <Stat label="Items" value={String(space.items)} />
            <Stat label="Duration" value={space.duration} />
            <Stat label="Score" value="A+" />
          </div>
        </div>

        {/* Before / After slider */}
        <div className="px-6 mt-6">
          <div className="flex items-center justify-between mb-3">
            <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>Before / After</p>
            <span style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>Drag to compare</span>
          </div>
          <div
            className="relative w-full overflow-hidden"
            style={{
              height: 230,
              borderRadius: 24,
              backgroundColor: WHITE,
              boxShadow: "0 4px 20px rgba(123,92,72,0.06)",
            }}
          >
            <ImageWithFallback
              src={space.after}
              alt="After"
              className="absolute inset-0 h-full w-full object-cover"
            />
            <div
              className="absolute inset-y-0 left-0 overflow-hidden"
              style={{ width: `${slider}%` }}
            >
              <ImageWithFallback
                src={space.before}
                alt="Before"
                className="h-full object-cover"
                style={{ width: `${(100 / slider) * 100}%`, minWidth: "100%" }}
              />
            </div>
            {/* Labels */}
            <span
              className="absolute top-3 left-3 px-2.5 py-1"
              style={{
                backgroundColor: "rgba(123,92,72,0.85)",
                color: WHITE,
                borderRadius: 999,
                fontSize: 10,
                fontWeight: 600,
              }}
            >
              BEFORE
            </span>
            <span
              className="absolute top-3 right-3 px-2.5 py-1"
              style={{
                backgroundColor: ORANGE,
                color: WHITE,
                borderRadius: 999,
                fontSize: 10,
                fontWeight: 600,
              }}
            >
              AFTER
            </span>
            {/* Divider */}
            <div
              className="absolute top-0 bottom-0"
              style={{
                left: `${slider}%`,
                width: 3,
                backgroundColor: WHITE,
                transform: "translateX(-50%)",
                boxShadow: "0 0 12px rgba(0,0,0,0.25)",
              }}
            >
              <div
                className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 h-9 w-9 rounded-full flex items-center justify-center"
                style={{ backgroundColor: WHITE, boxShadow: "0 4px 12px rgba(0,0,0,0.2)" }}
              >
                <MoveHorizontal size={16} color={COFFEE} />
              </div>
            </div>
            <input
              type="range"
              min={0}
              max={100}
              value={slider}
              onChange={(e) => setSlider(Number(e.target.value))}
              className="absolute inset-0 w-full h-full opacity-0 cursor-ew-resize"
            />
          </div>
        </div>

        {/* Items list */}
        <div className="px-6 mt-7 mb-3 flex items-center justify-between">
          <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>
            Organized Items · {space.items}
          </p>
          <span style={{ color: ORANGE, fontSize: 12 }}>View all</span>
        </div>
        <div className="px-6 grid grid-cols-2 gap-3">
          {space.itemList.map((it) => (
            <div
              key={it.name}
              className="flex items-center gap-3 p-3"
              style={{
                backgroundColor: WHITE,
                borderRadius: 16,
                boxShadow: "0 4px 12px rgba(123,92,72,0.04)",
              }}
            >
              <div
                className="h-10 w-10 rounded-xl flex items-center justify-center"
                style={{ backgroundColor: LINEN, fontSize: 20 }}
              >
                {it.emoji}
              </div>
              <div className="flex-1 min-w-0">
                <p style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>{it.name}</p>
                <span
                  className="inline-block mt-1 px-2 py-0.5"
                  style={{
                    backgroundColor: BLUE,
                    color: WHITE,
                    borderRadius: 999,
                    fontSize: 9,
                  }}
                >
                  {it.cat}
                </span>
              </div>
            </div>
          ))}
        </div>

        {/* Tips */}
        <div className="px-6 mt-7 mb-3 flex items-center gap-2">
          <Lightbulb size={18} color={ORANGE} />
          <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>Storage Tips</p>
        </div>
        <div className="px-6 space-y-3">
          {space.tips.map((tip, i) => (
            <div
              key={tip.title}
              className="p-4"
              style={{
                backgroundColor: WHITE,
                borderRadius: 20,
                boxShadow: "0 4px 14px rgba(123,92,72,0.05)",
              }}
            >
              <div className="flex items-center gap-2 mb-2">
                <div
                  className="h-7 w-7 rounded-full flex items-center justify-center"
                  style={{
                    backgroundColor: ORANGE,
                    color: WHITE,
                    fontSize: 11,
                    fontWeight: 600,
                  }}
                >
                  {i + 1}
                </div>
                <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{tip.title}</p>
              </div>
              <p style={{ color: COFFEE, opacity: 0.65, fontSize: 12, lineHeight: 1.5 }}>
                {tip.body}
              </p>
            </div>
          ))}
        </div>

        {/* AI suggestion */}
        <div
          className="mx-6 mt-5 p-4 flex items-center gap-3"
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
            <p style={{ color: WHITE, fontSize: 13, fontWeight: 600 }}>Maintain this space?</p>
            <p style={{ color: WHITE, opacity: 0.85, fontSize: 11 }}>
              Schedule a 2-min reset reminder
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div
      className="px-3 py-2"
      style={{
        backgroundColor: WHITE,
        borderRadius: 14,
        boxShadow: "0 2px 8px rgba(123,92,72,0.04)",
      }}
    >
      <p style={{ color: ORANGE, fontSize: 14, fontWeight: 600 }}>{value}</p>
      <p style={{ color: COFFEE, opacity: 0.55, fontSize: 10 }}>{label}</p>
    </div>
  );
}
