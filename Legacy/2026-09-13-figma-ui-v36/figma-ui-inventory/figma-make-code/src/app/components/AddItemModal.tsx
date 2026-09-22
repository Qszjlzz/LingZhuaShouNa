import { useState } from "react";
import { Camera, Type, X, Check } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";

type Mode = "choice" | "photo" | "text";

export function AddItemModal({
  onClose,
  onAdd,
  subgroups: subgroupsProp,
}: {
  onClose: () => void;
  onAdd: (item: { name: string; subgroup: string }) => void;
  subgroups?: string[];
}) {
  const subgroups = subgroupsProp && subgroupsProp.length > 0 ? subgroupsProp : ["Novel", "Study", "Philosophy"];
  const [mode, setMode] = useState<Mode>("choice");
  const [name, setName] = useState("");
  const [subgroup, setSubgroup] = useState(subgroups[0]);

  return (
    <div
      className="absolute inset-0 z-50 flex items-end justify-center"
      style={{ backgroundColor: "rgba(45,32,26,0.45)" }}
      onClick={onClose}
    >
      <div
        className="w-full px-6 pt-5 pb-7"
        onClick={(e) => e.stopPropagation()}
        style={{
          backgroundColor: WHITE,
          borderTopLeftRadius: 32,
          borderTopRightRadius: 32,
          boxShadow: "0 -10px 40px rgba(123,92,72,0.18)",
        }}
      >
        <div className="flex items-center justify-center mb-4">
          <div className="h-1 w-10 rounded-full" style={{ backgroundColor: SOFT }} />
        </div>

        <div className="flex items-center justify-between mb-5">
          <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>
            {mode === "choice" && "Add New Item"}
            {mode === "photo" && "Capture Item"}
            {mode === "text" && "Enter Item Details"}
          </p>
          <button
            onClick={onClose}
            className="h-9 w-9 rounded-full flex items-center justify-center"
            style={{ backgroundColor: LINEN }}
          >
            <X size={16} color={COFFEE} />
          </button>
        </div>

        {mode === "choice" && (
          <div className="grid grid-cols-2 gap-3">
            <ChoiceCard
              icon={<Camera size={26} color={WHITE} />}
              bg={ORANGE}
              title="Take Photo"
              sub="AI auto-recognize"
              onClick={() => setMode("photo")}
            />
            <ChoiceCard
              icon={<Type size={26} color={WHITE} />}
              bg={BLUE}
              title="Type Manually"
              sub="Enter details"
              onClick={() => setMode("text")}
            />
          </div>
        )}

        {mode === "photo" && (
          <div>
            <div
              className="h-48 w-full flex flex-col items-center justify-center mb-4"
              style={{ backgroundColor: LINEN, borderRadius: 20 }}
            >
              <div
                className="h-16 w-16 rounded-full flex items-center justify-center mb-3"
                style={{ backgroundColor: ORANGE, boxShadow: "0 8px 20px rgba(250,136,58,0.35)" }}
              >
                <Camera size={28} color={WHITE} />
              </div>
              <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>Tap to capture</p>
              <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginTop: 2 }}>
                AI will detect & tag the book
              </p>
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => setMode("choice")}
                className="flex-1 py-3"
                style={{
                  backgroundColor: LINEN,
                  color: COFFEE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                Back
              </button>
              <button
                onClick={() => {
                  onAdd({ name: "New Book", subgroup });
                  onClose();
                }}
                className="flex-1 py-3 flex items-center justify-center gap-2"
                style={{
                  backgroundColor: ORANGE,
                  color: WHITE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                  boxShadow: "0 6px 16px rgba(250,136,58,0.3)",
                }}
              >
                <Check size={16} /> Confirm
              </button>
            </div>
          </div>
        )}

        {mode === "text" && (
          <div>
            <label
              style={{ color: COFFEE, opacity: 0.6, fontSize: 11, fontWeight: 500 }}
            >
              ITEM NAME
            </label>
            <input
              autoFocus
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. 《活着》"
              className="w-full mt-2 px-4 py-3 outline-none"
              style={{
                backgroundColor: LINEN,
                borderRadius: 14,
                color: COFFEE,
                fontSize: 14,
              }}
            />
            <label
              style={{
                color: COFFEE,
                opacity: 0.6,
                fontSize: 11,
                fontWeight: 500,
                display: "block",
                marginTop: 16,
              }}
            >
              SUBGROUP
            </label>
            <div className="flex gap-2 mt-2">
              {subgroups.map((s) => {
                const active = subgroup === s;
                return (
                  <button
                    key={s}
                    onClick={() => setSubgroup(s)}
                    className="px-4 py-2"
                    style={{
                      backgroundColor: active ? COFFEE : LINEN,
                      color: active ? WHITE : COFFEE,
                      borderRadius: 999,
                      fontSize: 12,
                      fontWeight: active ? 600 : 500,
                    }}
                  >
                    {s}
                  </button>
                );
              })}
            </div>
            <div className="flex gap-2 mt-5">
              <button
                onClick={() => setMode("choice")}
                className="flex-1 py-3"
                style={{
                  backgroundColor: LINEN,
                  color: COFFEE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                Back
              </button>
              <button
                disabled={!name.trim()}
                onClick={() => {
                  onAdd({ name: name.trim(), subgroup });
                  onClose();
                }}
                className="flex-1 py-3 flex items-center justify-center gap-2"
                style={{
                  backgroundColor: name.trim() ? ORANGE : SOFT,
                  color: WHITE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                  boxShadow: name.trim() ? "0 6px 16px rgba(250,136,58,0.3)" : "none",
                }}
              >
                <Check size={16} /> Save Item
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function ChoiceCard({
  icon,
  bg,
  title,
  sub,
  onClick,
}: {
  icon: React.ReactNode;
  bg: string;
  title: string;
  sub: string;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className="p-5 flex flex-col items-start"
      style={{
        backgroundColor: LINEN,
        borderRadius: 20,
      }}
    >
      <div
        className="h-12 w-12 rounded-2xl flex items-center justify-center mb-3"
        style={{ backgroundColor: bg, boxShadow: `0 6px 16px ${bg}55` }}
      >
        {icon}
      </div>
      <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>{title}</p>
      <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginTop: 2 }}>{sub}</p>
    </button>
  );
}
