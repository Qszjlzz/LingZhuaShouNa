import { ArrowLeft, Play, Pause, CheckCircle2, Circle, Clock, Flame } from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";

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

const sample: ProgressSpace = {
  id: "p1",
  title: "Bathroom",
  progress: 35,
  cover:
    "https://images.unsplash.com/photo-1758239873506-82d0e76244f6?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
  estimate: "12 min left",
  streak: 4,
  zones: [
    { id: "z1", name: "Counter Top", done: true, tasks: 3 },
    { id: "z2", name: "Mirror Cabinet", done: true, tasks: 5 },
    { id: "z3", name: "Shower Caddy", done: false, current: true, tasks: 4 },
    { id: "z4", name: "Under-sink Storage", done: false, tasks: 6 },
    { id: "z5", name: "Towel Rack", done: false, tasks: 2 },
  ],
  recentActivity: [
    { time: "Just now", text: "Wiped down counter & relocated cosmetics" },
    { time: "5 min ago", text: "Sorted skincare into top drawer" },
    { time: "12 min ago", text: "Tossed 3 expired products" },
  ],
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
  space = sample,
}: {
  onBack: () => void;
  space?: ProgressSpace;
}) {
  const completedZones = space.zones.filter((z) => z.done).length;

  return (
    <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: LINEN }}>
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
                {space.streak}-day streak
              </span>
            </div>
          </div>
          <div className="absolute bottom-3 left-6 right-6">
            <span
              className="inline-block px-3 py-1 mb-2"
              style={{ backgroundColor: BLUE, color: WHITE, borderRadius: 999, fontSize: 10 }}
            >
              IN PROGRESS
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
            <Row icon={<Clock size={14} />} label="Estimate" value={space.estimate} />
            <Row
              icon={<CheckCircle2 size={14} />}
              label="Zones"
              value={`${completedZones} / ${space.zones.length}`}
            />
            <Row
              icon={<Flame size={14} />}
              label="Streak"
              value={`${space.streak} days`}
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
      <div className="absolute left-0 right-0 bottom-0 px-6 pb-6 pt-3">
        <div className="flex gap-2">
          <button
            className="h-14 px-5 rounded-full flex items-center justify-center gap-2"
            style={{ backgroundColor: WHITE, color: COFFEE, fontSize: 13, fontWeight: 600 }}
          >
            <Pause size={16} /> Pause
          </button>
          <button
            className="flex-1 h-14 rounded-full flex items-center justify-center gap-2"
            style={{
              backgroundColor: ORANGE,
              color: WHITE,
              fontSize: 14,
              fontWeight: 600,
              boxShadow: "0 8px 24px rgba(250,136,58,0.35)",
            }}
          >
            <Play size={16} fill={WHITE} /> Resume Cleaning
          </button>
        </div>
      </div>
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
