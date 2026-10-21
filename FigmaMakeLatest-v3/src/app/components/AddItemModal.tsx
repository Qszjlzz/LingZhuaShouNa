import { useState } from "react";
import { Camera, Type, X, Check } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";

type Mode = "choice" | "text";

export function AddItemModal({
  onClose,
  onAdd,
  onCamera,
  subgroups: subgroupsProp,
  selectedSubgroup,
}: {
  onClose: () => void;
  onAdd: (item: { name: string; subgroup: string }) => Promise<void>;
  onCamera?: () => void;
  subgroups?: string[];
  selectedSubgroup?: string;
}) {
  const subgroups = subgroupsProp && subgroupsProp.length > 0 ? subgroupsProp : ["未分组"];
  const [mode, setMode] = useState<Mode>("choice");
  const [name, setName] = useState("");
  const [subgroup, setSubgroup] = useState(selectedSubgroup && subgroups.includes(selectedSubgroup) ? selectedSubgroup : subgroups[0]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const save = async () => {
    if (!name.trim() || saving) return;
    setSaving(true);
    setError(null);
    try {
      await onAdd({ name: name.trim(), subgroup });
      onClose();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "保存失败，请重试");
    } finally {
      setSaving(false);
    }
  };

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
            {mode === "choice" && "添加新物品"}
            {mode === "text" && "手动填写"}
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
              title="拍照"
              sub="AI 自动识别"
              onClick={() => { onClose(); onCamera?.(); }}
            />
            <ChoiceCard
              icon={<Type size={26} color={WHITE} />}
              bg={BLUE}
              title="手动输入"
              sub="填写物品信息"
              onClick={() => setMode("text")}
            />
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
              placeholder="例如：《活着》"
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
                返回
              </button>
              <button
                disabled={!name.trim() || saving}
                onClick={() => void save()}
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
                <Check size={16} /> {saving ? "保存中" : "保存物品"}
              </button>
            </div>
            {error && <p role="alert" className="mt-3 text-xs" style={{ color: "#B44740" }}>{error}</p>}
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
