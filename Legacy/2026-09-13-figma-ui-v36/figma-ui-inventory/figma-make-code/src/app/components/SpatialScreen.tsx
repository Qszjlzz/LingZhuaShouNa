import { useState } from "react";
import { Bell, ChevronRight } from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { Raccoon } from "./Raccoon";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { FinishedSpaceDetail } from "./FinishedSpaceDetail";
import { InProgressDetail } from "./InProgressDetail";

const finishedSpaces = [
  {
    id: "s1",
    title: "Living Room",
    progress: 92,
    items: 24,
    image:
      "https://images.unsplash.com/photo-1749705319317-f9a2bf24fe3d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
    tag: "Done",
  },
  {
    id: "s2",
    title: "Kitchen Pantry",
    progress: 100,
    items: 36,
    image:
      "https://images.unsplash.com/photo-1772475385491-f3cf64d4131a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
    tag: "Done",
  },
  {
    id: "s3",
    title: "Wardrobe",
    progress: 78,
    items: 42,
    image:
      "https://images.unsplash.com/photo-1775029918191-32e44ee20d06?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
    tag: "Almost",
  },
];

const inProgress = [
  {
    id: "p1",
    title: "Bathroom",
    progress: 35,
    image:
      "https://images.unsplash.com/photo-1758239873506-82d0e76244f6?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
  },
  {
    id: "p2",
    title: "Office Desk",
    progress: 60,
    image:
      "https://images.unsplash.com/photo-1764588037085-a78240016f8b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
  },
];

function ProgressRing({ value }: { value: number }) {
  const r = 60;
  const c = 2 * Math.PI * r;
  const offset = c - (value / 100) * c;
  return (
    <svg width="148" height="148" viewBox="0 0 148 148">
      <circle cx="74" cy="74" r={r} stroke={SOFT} strokeWidth="12" fill="none" />
      <circle
        cx="74"
        cy="74"
        r={r}
        stroke={ORANGE}
        strokeWidth="12"
        strokeLinecap="round"
        fill="none"
        strokeDasharray={c}
        strokeDashoffset={offset}
        transform="rotate(-90 74 74)"
      />
      <text x="74" y="76" textAnchor="middle" fill={COFFEE} style={{ fontSize: "30px", fontWeight: 600 }}>
        {value}%
      </text>
      <text x="74" y="98" textAnchor="middle" fill={COFFEE} opacity="0.55" style={{ fontSize: "11px" }}>
        Storage Progress
      </text>
    </svg>
  );
}

export function SpatialScreen() {
  const [openFinished, setOpenFinished] = useState<string | null>(null);
  const [openProgress, setOpenProgress] = useState<string | null>(null);

  if (openFinished) {
    return <FinishedSpaceDetail onBack={() => setOpenFinished(null)} />;
  }
  if (openProgress) {
    return <InProgressDetail onBack={() => setOpenProgress(null)} />;
  }

  return (
    <div className="h-full w-full overflow-y-auto pb-32" style={{ backgroundColor: LINEN }}>
      <div className="px-6 pt-14 pb-2 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div
            className="h-11 w-11 rounded-full flex items-center justify-center"
            style={{ backgroundColor: WHITE }}
          >
            <Raccoon size={32} />
          </div>
          <div>
            <p style={{ color: COFFEE, opacity: 0.55, fontSize: "12px" }}>Welcome back</p>
            <p style={{ color: COFFEE, fontSize: "18px", fontWeight: 600 }}>浣序 · Huànxù</p>
          </div>
        </div>
        <div
          className="h-11 w-11 rounded-full flex items-center justify-center relative"
          style={{ backgroundColor: WHITE }}
        >
          <Bell size={20} color={COFFEE} />
          <span
            className="absolute top-2.5 right-2.5 h-2 w-2 rounded-full"
            style={{ backgroundColor: ORANGE }}
          />
        </div>
      </div>

      <div
        className="mx-6 mt-5 p-6 flex items-center gap-4"
        style={{
          backgroundColor: WHITE,
          borderRadius: "28px",
          boxShadow: "0 4px 20px rgba(123,92,72,0.06)",
        }}
      >
        <ProgressRing value={65} />
        <div className="flex-1">
          <p style={{ color: COFFEE, opacity: 0.55, fontSize: "12px" }}>This week</p>
          <p style={{ color: COFFEE, fontSize: "17px", fontWeight: 600, marginBottom: 10 }}>
            Keep going!
          </p>
          <div className="flex flex-wrap gap-2">
            <span
              className="px-3 py-1"
              style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, fontSize: 11 }}
            >
              12 spaces
            </span>
            <span
              className="px-3 py-1"
              style={{ backgroundColor: BLUE, color: WHITE, borderRadius: 999, fontSize: 11 }}
            >
              +5 done
            </span>
          </div>
        </div>
      </div>

      <div className="px-6 mt-7 mb-3 flex items-center justify-between">
        <p style={{ color: COFFEE, fontSize: "16px", fontWeight: 600 }}>Finished Spaces</p>
        <div className="flex items-center gap-1" style={{ color: ORANGE, fontSize: 12 }}>
          See all <ChevronRight size={14} />
        </div>
      </div>

      <div className="overflow-x-auto pb-2">
        <div className="flex gap-3 px-6 pr-6" style={{ width: "max-content" }}>
          {finishedSpaces.map((s) => (
            <button
              key={s.id}
              onClick={() => setOpenFinished(s.id)}
              className="text-left"
              style={{
                backgroundColor: WHITE,
                borderRadius: 24,
                overflow: "hidden",
                width: 200,
                boxShadow: "0 4px 20px rgba(123,92,72,0.05)",
              }}
            >
              <div className="h-32 w-full relative">
                <ImageWithFallback src={s.image} alt={s.title} className="h-full w-full object-cover" />
                <span
                  className="absolute top-3 right-3 px-2.5 py-1"
                  style={{
                    backgroundColor: s.progress === 100 ? ORANGE : BLUE,
                    color: WHITE,
                    borderRadius: 999,
                    fontSize: 10,
                  }}
                >
                  {s.tag}
                </span>
              </div>
              <div className="p-4">
                <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>{s.title}</p>
                <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginTop: 2 }}>
                  {s.items} items · {s.progress}%
                </p>
              </div>
            </button>
          ))}
        </div>
      </div>

      <div className="px-6 mt-6 mb-3 flex items-center justify-between">
        <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>In Progress</p>
        <span style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>{inProgress.length} active</span>
      </div>

      <div className="px-6 space-y-3">
        {inProgress.map((p) => (
          <button
            key={p.id}
            onClick={() => setOpenProgress(p.id)}
            className="w-full flex items-center gap-4 p-3 text-left"
            style={{
              backgroundColor: WHITE,
              borderRadius: 24,
              boxShadow: "0 4px 20px rgba(123,92,72,0.05)",
            }}
          >
            <div className="h-16 w-16 rounded-2xl overflow-hidden flex-shrink-0">
              <ImageWithFallback src={p.image} alt={p.title} className="h-full w-full object-cover" />
            </div>
            <div className="flex-1">
              <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>{p.title}</p>
              <div className="flex items-center gap-2 mt-2">
                <div className="flex-1 h-1.5 rounded-full" style={{ backgroundColor: LINEN }}>
                  <div
                    style={{
                      width: `${p.progress}%`,
                      height: "100%",
                      backgroundColor: ORANGE,
                      borderRadius: 999,
                    }}
                  />
                </div>
                <span style={{ color: COFFEE, opacity: 0.6, fontSize: 11 }}>{p.progress}%</span>
              </div>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}
