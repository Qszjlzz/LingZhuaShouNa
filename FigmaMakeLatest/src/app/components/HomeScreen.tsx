import { Plus, Home, Grid3x3, Users, User, Bell, ChevronRight } from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";

const COFFEE = "#7B5C48";
const ORANGE = "#FA883A";
const LINEN = "#F6F1EB";
const BLUE = "#B4C7DC";

const spaces = [
  {
    id: "s1",
    title: "Living Room",
    progress: 80,
    items: 24,
    image:
      "https://images.unsplash.com/photo-1749703973804-f1cadd32f8d4?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
    tag: "Completed",
  },
  {
    id: "s2",
    title: "Bedroom Closet",
    progress: 45,
    items: 18,
    image:
      "https://images.unsplash.com/photo-1775029918191-32e44ee20d06?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
    tag: "In Progress",
  },
  {
    id: "s3",
    title: "Kitchen Cabinet",
    progress: 60,
    items: 12,
    image:
      "https://images.unsplash.com/photo-1758565811303-8aeff0e6bbae?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
    tag: "In Progress",
  },
];

function ProgressRing({ value }: { value: number }) {
  const r = 56;
  const c = 2 * Math.PI * r;
  const offset = c - (value / 100) * c;
  return (
    <svg width="140" height="140" viewBox="0 0 140 140">
      <circle cx="70" cy="70" r={r} stroke="#EFE6DC" strokeWidth="12" fill="none" />
      <circle
        cx="70"
        cy="70"
        r={r}
        stroke={ORANGE}
        strokeWidth="12"
        strokeLinecap="round"
        fill="none"
        strokeDasharray={c}
        strokeDashoffset={offset}
        transform="rotate(-90 70 70)"
      />
      <text
        x="70"
        y="74"
        textAnchor="middle"
        fill={COFFEE}
        style={{ fontSize: "28px", fontWeight: 600 }}
      >
        {value}%
      </text>
      <text x="70" y="94" textAnchor="middle" fill={COFFEE} opacity="0.6" style={{ fontSize: "11px" }}>
        Organized
      </text>
    </svg>
  );
}

export function HomeScreen({ onPlusClick }: { onPlusClick: () => void }) {
  return (
    <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: LINEN }}>
      <div className="h-full w-full overflow-y-auto pb-32">
        <div className="px-6 pt-14 pb-4 flex items-center justify-between">
          <div>
            <p style={{ color: COFFEE, opacity: 0.6, fontSize: "13px" }}>Good morning</p>
            <p style={{ color: COFFEE, fontSize: "20px", fontWeight: 600 }}>Sarah Chen</p>
          </div>
          <div
            className="h-11 w-11 rounded-full flex items-center justify-center"
            style={{ backgroundColor: "#FFFFFF" }}
          >
            <Bell size={20} color={COFFEE} />
          </div>
        </div>

        <div
          className="mx-6 mt-2 p-6 flex items-center gap-5"
          style={{
            backgroundColor: "#FFFFFF",
            borderRadius: "24px",
            boxShadow: "0 4px 20px rgba(123,92,72,0.06)",
          }}
        >
          <ProgressRing value={65} />
          <div className="flex-1">
            <p style={{ color: COFFEE, opacity: 0.6, fontSize: "12px" }}>Overall</p>
            <p style={{ color: COFFEE, fontSize: "18px", fontWeight: 600, marginBottom: 12 }}>
              Storage Progress
            </p>
            <div className="flex gap-2 flex-wrap">
              <span
                className="px-3 py-1"
                style={{
                  backgroundColor: LINEN,
                  color: COFFEE,
                  borderRadius: "999px",
                  fontSize: "11px",
                }}
              >
                12 spaces
              </span>
              <span
                className="px-3 py-1"
                style={{
                  backgroundColor: BLUE,
                  color: "#FFFFFF",
                  borderRadius: "999px",
                  fontSize: "11px",
                }}
              >
                +5 this week
              </span>
            </div>
          </div>
        </div>

        <div className="px-6 mt-8 mb-4 flex items-center justify-between">
          <p style={{ color: COFFEE, fontSize: "18px", fontWeight: 600 }}>Organized Spaces</p>
          <div className="flex items-center gap-1" style={{ color: ORANGE, fontSize: "13px" }}>
            See all <ChevronRight size={16} />
          </div>
        </div>

        <div className="px-6 space-y-4">
          {spaces.map((s) => (
            <div
              key={s.id}
              style={{
                backgroundColor: "#FFFFFF",
                borderRadius: "24px",
                overflow: "hidden",
                boxShadow: "0 4px 20px rgba(123,92,72,0.05)",
              }}
            >
              <div className="h-44 w-full overflow-hidden">
                <ImageWithFallback
                  src={s.image}
                  alt={s.title}
                  className="h-full w-full object-cover"
                />
              </div>
              <div className="p-5">
                <div className="flex items-center justify-between mb-3">
                  <p style={{ color: COFFEE, fontSize: "16px", fontWeight: 600 }}>{s.title}</p>
                  <span
                    className="px-3 py-1"
                    style={{
                      backgroundColor: s.progress >= 80 ? ORANGE : BLUE,
                      color: "#FFFFFF",
                      borderRadius: "999px",
                      fontSize: "11px",
                    }}
                  >
                    {s.tag}
                  </span>
                </div>
                <div className="flex items-center gap-3">
                  <div
                    className="flex-1 h-2 rounded-full overflow-hidden"
                    style={{ backgroundColor: LINEN }}
                  >
                    <div
                      style={{
                        width: `${s.progress}%`,
                        height: "100%",
                        backgroundColor: ORANGE,
                        borderRadius: "999px",
                      }}
                    />
                  </div>
                  <span style={{ color: COFFEE, fontSize: "13px", opacity: 0.7 }}>
                    {s.items} items
                  </span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Bottom Nav */}
      <div className="absolute bottom-0 left-0 right-0">
        <div
          className="mx-4 mb-4 px-6 py-4 flex items-center justify-between relative"
          style={{
            backgroundColor: "#FFFFFF",
            borderRadius: "32px",
            boxShadow: "0 8px 30px rgba(123,92,72,0.08)",
          }}
        >
          <NavIcon icon={<Home size={22} />} label="Space" active />
          <NavIcon icon={<Grid3x3 size={22} />} label="Categories" />
          <div className="w-14" />
          <NavIcon icon={<Users size={22} />} label="Community" />
          <NavIcon icon={<User size={22} />} label="Profile" />

          <button
            onClick={onPlusClick}
            className="absolute left-1/2 -translate-x-1/2 -top-7 h-16 w-16 rounded-full flex items-center justify-center"
            style={{
              backgroundColor: ORANGE,
              boxShadow: "0 8px 24px rgba(250,136,58,0.4)",
            }}
          >
            <Plus size={30} color="#FFFFFF" strokeWidth={2.5} />
          </button>
        </div>
      </div>
    </div>
  );
}

function NavIcon({
  icon,
  label,
  active,
}: {
  icon: React.ReactNode;
  label: string;
  active?: boolean;
}) {
  return (
    <div className="flex flex-col items-center gap-1" style={{ width: 50 }}>
      <div style={{ color: active ? ORANGE : COFFEE, opacity: active ? 1 : 0.5 }}>{icon}</div>
      <span
        style={{
          color: active ? ORANGE : COFFEE,
          opacity: active ? 1 : 0.5,
          fontSize: "10px",
        }}
      >
        {label}
      </span>
    </div>
  );
}
