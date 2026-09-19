import { Home, Grid3x3, Users, User, Camera } from "lucide-react";
import { COFFEE, ORANGE, WHITE } from "./theme";

export type Tab = "spatial" | "classification" | "community" | "mine";

export function BottomNav({
  active,
  onChange,
  onCamera,
}: {
  active: Tab;
  onChange: (t: Tab) => void;
  onCamera: () => void;
}) {
  return (
    <div className="absolute bottom-0 left-0 right-0 z-50">
      <div
        className="mx-4 mb-4 px-6 py-4 flex items-center justify-between relative"
        style={{
          backgroundColor: WHITE,
          borderRadius: "32px",
          boxShadow: "0 8px 30px rgba(123,92,72,0.08)",
        }}
      >
        <NavIcon
          icon={<Home size={22} />}
          label="Spatial"
          active={active === "spatial"}
          onClick={() => onChange("spatial")}
        />
        <NavIcon
          icon={<Grid3x3 size={22} />}
          label="Classify"
          active={active === "classification"}
          onClick={() => onChange("classification")}
        />
        <div className="w-14" />
        <NavIcon
          icon={<Users size={22} />}
          label="Community"
          active={active === "community"}
          onClick={() => onChange("community")}
        />
        <NavIcon
          icon={<User size={22} />}
          label="Mine"
          active={active === "mine"}
          onClick={() => onChange("mine")}
        />

        <button
          onClick={onCamera}
          className="absolute left-1/2 -translate-x-1/2 -top-7 h-16 w-16 rounded-full flex items-center justify-center"
          style={{
            backgroundColor: ORANGE,
            boxShadow: "0 8px 24px rgba(250,136,58,0.4)",
          }}
        >
          <Camera size={26} color={WHITE} strokeWidth={2.2} />
        </button>
      </div>
    </div>
  );
}

function NavIcon({
  icon,
  label,
  active,
  onClick,
}: {
  icon: React.ReactNode;
  label: string;
  active?: boolean;
  onClick: () => void;
}) {
  return (
    <button onClick={onClick} className="flex flex-col items-center gap-1" style={{ width: 50 }}>
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
    </button>
  );
}
