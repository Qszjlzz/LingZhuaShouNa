import { useState, useRef } from "react";
import {
  ArrowLeft,
  Sparkles,
  Send,
  Check,
  X,
  Zap,
  Image as ImageIcon,
  RotateCcw,
  Plus,
  AlertTriangle,
  Camera,
  Edit3,
  Trash2,
  Mic,
  ChevronRight,
  Paperclip,
  ImagePlus,
  Box,
  Layers,
  Move3d,
  CheckCircle2,
  SkipForward,
  GitCompare,
  ChevronUp,
  Vibrate,
  MoveHorizontal,
} from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { Raccoon } from "./Raccoon";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";

const ROOM_IMG =
  "https://images.unsplash.com/photo-1768548273848-ebab6f26b48c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080";
const THUMB_IMG =
  "https://images.unsplash.com/photo-1764588037085-a78240016f8b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400";

type Step = "capture" | "review" | "confirm" | "prompt" | "plans" | "zones" | "arPreview" | "tools" | "arGuide" | "task" | "reward";

type PlanTier = "basic" | "smart" | "pro";

export type CapturedAsset =
  | { id: string; kind: "photo"; src: string; label: string }
  | { id: string; kind: "video"; src: string; label: string; duration: number };

export function ShootFlow({
  onClose,
  onFinish,
}: {
  onClose: () => void;
  onFinish?: () => void;
}) {
  const [step, setStep] = useState<Step>("capture");
  const [assets, setAssets] = useState<CapturedAsset[]>([]);
  const [tier, setTier] = useState<PlanTier>("smart");

  return (
    <div className="absolute inset-0 z-50" style={{ backgroundColor: LINEN }}>
      {step === "capture" && (
        <CaptureStep
          onClose={onClose}
          on完成={(captured) => {
            setAssets(captured);
            setStep("review");
          }}
        />
      )}
      {step === "review" && (
        <ReviewStep
          assets={assets}
          onBack={() => setStep("capture")}
          onNext={() => setStep("confirm")}
          onRetake={() => setStep("capture")}
        />
      )}
      {step === "confirm" && (
        <ConfirmStep onBack={() => setStep("review")} onNext={() => setStep("prompt")} />
      )}
      {step === "prompt" && (
        <PromptStep onBack={() => setStep("confirm")} onNext={() => setStep("plans")} />
      )}
      {step === "plans" && (
        <PlansStep
          onBack={() => setStep("prompt")}
          onPick={(t) => {
            setTier(t);
            setStep("zones");
          }}
        />
      )}
      {step === "zones" && (
        <ZoneSelectStep
          onBack={() => setStep("plans")}
          onNext={() => setStep(tier === "basic" ? "arPreview" : "tools")}
        />
      )}
      {step === "tools" && (
        <ToolsStep
          onBack={() => setStep("zones")}
          onNext={() => setStep("arPreview")}
        />
      )}
      {step === "arPreview" && (
        <ARPreviewStep
          onBack={() => setStep(tier === "pro" ? "tools" : "zones")}
          onNext={() => setStep("arGuide")}
        />
      )}
      {step === "arGuide" && (
        <ARGuideStep
          tier={tier}
          onBack={() => setStep("arPreview")}
          onComplete={() => setStep("reward")}
        />
      )}
      {step === "task" && (
        <TaskStep onBack={() => setStep("plan")} onComplete={() => setStep("reward")} />
      )}
      {step === "reward" && <RewardStep onClose={onFinish || onClose} />}
    </div>
  );
}

/* ---------- 0. Camera capture ---------- */

const ANGLE_HINTS = ["广角", "左侧", "右侧", "俯视"];

function CaptureStep({
  onClose,
  on完成,
}: {
  onClose: () => void;
  on完成: (assets: CapturedAsset[]) => void;
}) {
  const [flash, setFlash] = useState(false);
  const [pressed, setPressed] = useState(false);
  const [mode, setMode] = useState<"photo" | "video">("photo");
  const [shots, setShots] = useState<CapturedAsset[]>([]);
  const [recording, setRecording] = useState(false);
  const [recDuration, setRecDuration] = useState(0);
  const [shutter, setShutter] = useState(false);
  const recTimer = useRef<any>(null);

  const angleHint = ANGLE_HINTS[Math.min(shots.length, ANGLE_HINTS.length - 1)];

  const snapPhoto = () => {
    setShutter(true);
    setTimeout(() => setShutter(false), 220);
    setShots((arr) => [
      ...arr,
      {
        id: `p${Date.now()}`,
        kind: "photo",
        src: ROOM_IMG,
        label: ANGLE_HINTS[arr.length] || `拍摄 ${arr.length + 1}`,
      },
    ]);
  };

  const toggleRecord = () => {
    if (recording) {
      clearInterval(recTimer.current);
      setRecording(false);
      setShots((arr) => [
        ...arr,
        {
          id: `v${Date.now()}`,
          kind: "video",
          src: ROOM_IMG,
          label: "AR扫描视频",
          duration: recDuration,
        },
      ]);
      setRecDuration(0);
    } else {
      setRecording(true);
      setRecDuration(0);
      recTimer.current = setInterval(() => setRecDuration((d) => d + 1), 1000);
    }
  };

  const fmt = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

  return (
    <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: "#1a1411" }}>
      {/* Live camera feed */}
      <ImageWithFallback src={ROOM_IMG} alt="Camera" className="h-full w-full object-cover" />

      {/* subtle vignette */}
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          background:
            "radial-gradient(ellipse at center, rgba(0,0,0,0) 55%, rgba(0,0,0,0.35) 100%)",
        }}
      />

      {/* Shutter flash */}
      {shutter && (
        <div
          className="absolute inset-0 pointer-events-none"
          style={{ backgroundColor: WHITE, opacity: 0.85 }}
        />
      )}

      {/* Top bar */}
      <div className="absolute top-0 left-0 right-0 px-5 pt-14 flex items-center justify-between">
        <button
          onClick={onClose}
          className="h-10 w-10 rounded-full flex items-center justify-center"
          style={{ backgroundColor: "rgba(255,255,255,0.92)" }}
        >
          <X size={18} color={COFFEE} />
        </button>
        <div
          className="px-3.5 py-2 flex items-center gap-2"
          style={{
            backgroundColor: recording ? "#E25555" : "rgba(255,255,255,0.92)",
            borderRadius: 999,
          }}
        >
          {recording ? (
            <>
              <div
                className="h-2 w-2 rounded-full"
                style={{ backgroundColor: WHITE, animation: "pulse 1s infinite" }}
              />
              <span style={{ color: WHITE, fontSize: 12, fontWeight: 600 }}>REC {fmt(recDuration)}</span>
            </>
          ) : (
            <>
              <Sparkles size={13} color={ORANGE} />
              <span style={{ color: COFFEE, fontSize: 12, fontWeight: 500 }}>
                {mode === "photo" ? `${shots.length} shots · ${angleHint}` : "AR scan ready"}
              </span>
            </>
          )}
        </div>
      </div>

      {/* Mode switcher */}
      <div className="absolute left-1/2 -translate-x-1/2" style={{ top: 110 }}>
        <div
          className="flex p-1"
          style={{ backgroundColor: "rgba(0,0,0,0.45)", borderRadius: 999, backdropFilter: "blur(8px)" }}
        >
          {(["photo", "video"] as const).map((m) => (
            <button
              key={m}
              onClick={() => setMode(m)}
              disabled={recording}
              className="px-4 py-1.5 flex items-center gap-1.5"
              style={{
                backgroundColor: mode === m ? WHITE : "transparent",
                color: mode === m ? COFFEE : WHITE,
                borderRadius: 999,
                fontSize: 11,
                fontWeight: 600,
              }}
            >
              {m === "photo" ? <Camera size={12} /> : <Box size={12} />}
              {m === "photo" ? "Multi-shot" : "AR Scan"}
            </button>
          ))}
        </div>
      </div>

      {/* Framing guides — subtle corner brackets */}
      <div className="absolute inset-x-10 top-32 bottom-52 pointer-events-none">
        <CornerBracket pos="tl" />
        <CornerBracket pos="tr" />
        <CornerBracket pos="bl" />
        <CornerBracket pos="br" />
      </div>

      {/* Flash button (mid-bottom over feed) */}
      <button
        onClick={() => setFlash((f) => !f)}
        className="absolute h-9 w-9 rounded-full flex items-center justify-center"
        style={{
          left: "50%",
          transform: "translateX(-50%)",
          bottom: 188,
          backgroundColor: flash ? ORANGE : "rgba(0,0,0,0.45)",
          backdropFilter: "blur(6px)",
        }}
      >
        <Zap size={16} color={WHITE} fill={flash ? WHITE : "none"} />
      </button>

      {/* Bottom dock */}
      <div
        className="absolute bottom-0 left-0 right-0 px-5 pt-4 pb-8"
        style={{
          backgroundColor: "rgba(246,241,235,0.95)",
          borderTopLeftRadius: 28,
          borderTopRightRadius: 28,
          backdropFilter: "blur(10px)",
        }}
      >
        {/* Thumbnail strip */}
        {shots.length > 0 && (
          <div className="flex gap-2 mb-3 overflow-x-auto -mx-1 px-1">
            {shots.map((s, i) => (
              <div
                key={s.id}
                className="relative flex-shrink-0"
                style={{ width: 52, height: 52, borderRadius: 10, overflow: "hidden", border: `2px solid ${WHITE}` }}
              >
                <ImageWithFallback src={s.src} alt={s.label} className="h-full w-full object-cover" />
                <button
                  onClick={() => setShots((arr) => arr.filter((x) => x.id !== s.id))}
                  className="absolute top-0.5 right-0.5 h-4 w-4 rounded-full flex items-center justify-center"
                  style={{ backgroundColor: "rgba(0,0,0,0.6)" }}
                >
                  <X size={9} color={WHITE} />
                </button>
                {s.kind === "video" && (
                  <div
                    className="absolute bottom-0 left-0 right-0 text-center"
                    style={{ backgroundColor: "rgba(0,0,0,0.55)", color: WHITE, fontSize: 8, padding: 1 }}
                  >
                    {fmt(s.duration)}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        <div className="flex items-center justify-between">
          {/* Left: shot counter / gallery */}
          <div
            className="h-12 w-12 rounded-2xl flex flex-col items-center justify-center flex-shrink-0"
            style={{ backgroundColor: WHITE }}
          >
            <span style={{ color: COFFEE, fontSize: 15, fontWeight: 700, lineHeight: 1 }}>
              {shots.length}
            </span>
            <span style={{ color: COFFEE, opacity: 0.55, fontSize: 8, marginTop: 1 }}>
              {mode === "photo" ? "shots" : "clip"}
            </span>
          </div>

          {/* Shutter */}
          <button
            onMouseDown={() => setPressed(true)}
            onMouseUp={() => setPressed(false)}
            onMouseLeave={() => setPressed(false)}
            onClick={mode === "photo" ? snapPhoto : toggleRecord}
            className="rounded-full flex items-center justify-center"
            style={{
              width: 72,
              height: 72,
              backgroundColor: "rgba(255,255,255,0.6)",
              border: `4px solid ${WHITE}`,
              boxShadow: "0 8px 24px rgba(123,92,72,0.25)",
              transform: pressed ? "scale(0.92)" : "scale(1)",
              transition: "transform 0.1s",
            }}
          >
            {mode === "video" && recording ? (
              <div
                className="rounded"
                style={{ width: 26, height: 26, backgroundColor: "#E25555" }}
              />
            ) : mode === "video" ? (
              <div
                className="rounded-full"
                style={{ width: 52, height: 52, backgroundColor: "#E25555" }}
              />
            ) : (
              <div
                className="rounded-full"
                style={{ width: 52, height: 52, backgroundColor: pressed ? COFFEE : "#cfc6bb" }}
              />
            )}
          </button>

          {/* Right: 完成 */}
          <button
            onClick={() => on完成(shots)}
            disabled={shots.length === 0}
            className="h-12 px-3 rounded-2xl flex items-center gap-1 flex-shrink-0"
            style={{
              backgroundColor: shots.length > 0 ? ORANGE : SOFT,
              opacity: shots.length > 0 ? 1 : 0.5,
              boxShadow: shots.length > 0 ? "0 6px 16px rgba(250,136,58,0.35)" : "none",
            }}
          >
            <Check size={15} color={WHITE} />
            <span style={{ color: WHITE, fontSize: 12, fontWeight: 600 }}>完成</span>
          </button>
        </div>

        {/* Hint */}
        <p style={{ color: COFFEE, opacity: 0.5, fontSize: 10, marginTop: 8, textAlign: "center" }}>
          {mode === "photo"
            ? `Capture different angles for accurate detection · next: ${angleHint}`
            : "Pan slowly around the room to build a 3D scan"}
        </p>

      </div>
    </div>
  );
}

/* ---------- 0b. Review captured assets ---------- */

function ReviewStep({
  assets,
  onBack,
  onNext,
  onRetake,
}: {
  assets: CapturedAsset[];
  onBack: () => void;
  onNext: () => void;
  onRetake: () => void;
}) {
  const [primary, setPrimary] = useState(0);
  const a = assets[primary];

  return (
    <div className="h-full w-full flex flex-col" style={{ backgroundColor: LINEN }}>
      <div className="px-5 pt-14 pb-3 flex items-center justify-between">
        <button
          onClick={onBack}
          className="h-10 w-10 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ArrowLeft size={18} color={COFFEE} />
        </button>
        <div className="text-center">
          <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>Review captures</p>
          <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>
            {assets.length} {assets.length === 1 ? "asset" : "assets"} ready
          </p>
        </div>
        <button
          onClick={onRetake}
          className="h-10 px-3 rounded-full flex items-center gap-1"
          style={{ backgroundColor: WHITE }}
        >
          <Camera size={13} color={COFFEE} />
          <span style={{ color: COFFEE, fontSize: 11, fontWeight: 600 }}>添加</span>
        </button>
      </div>

      <div className="mx-5 mt-2 relative overflow-hidden" style={{ borderRadius: 22, aspectRatio: "4/5" }}>
        {a ? (
          <>
            <ImageWithFallback src={a.src} alt={a.label} className="h-full w-full object-cover" />
            <span
              className="absolute top-3 left-3 px-2.5 py-1"
              style={{
                backgroundColor: a.kind === "video" ? "#E25555" : "rgba(255,255,255,0.92)",
                color: a.kind === "video" ? WHITE : COFFEE,
                borderRadius: 999,
                fontSize: 10,
                fontWeight: 600,
              }}
            >
              {a.kind === "video" ? `▶ AR scan · ${a.duration}s` : a.label}
            </span>
          </>
        ) : (
          <div className="h-full w-full flex items-center justify-center" style={{ backgroundColor: WHITE }}>
            <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>No captures yet</p>
          </div>
        )}
      </div>

      <div className="px-5 mt-3 flex gap-2 overflow-x-auto">
        {assets.map((s, i) => (
          <button
            key={s.id}
            onClick={() => setPrimary(i)}
            className="relative flex-shrink-0 overflow-hidden"
            style={{
              width: 56,
              height: 56,
              borderRadius: 12,
              border: i === primary ? `2.5px solid ${ORANGE}` : `2px solid ${WHITE}`,
            }}
          >
            <ImageWithFallback src={s.src} alt={s.label} className="h-full w-full object-cover" />
            {s.kind === "video" && (
              <div
                className="absolute inset-0 flex items-center justify-center"
                style={{ backgroundColor: "rgba(0,0,0,0.35)" }}
              >
                <div
                  className="h-5 w-5 rounded-full flex items-center justify-center"
                  style={{ backgroundColor: "rgba(255,255,255,0.92)" }}
                >
                  <div
                    style={{
                      width: 0,
                      height: 0,
                      borderLeft: "6px solid #E25555",
                      borderTop: "4px solid transparent",
                      borderBottom: "4px solid transparent",
                      marginLeft: 2,
                    }}
                  />
                </div>
              </div>
            )}
          </button>
        ))}
      </div>

      <div className="px-5 mt-5">
        <div
          className="p-3 flex items-start gap-3"
          style={{ backgroundColor: WHITE, borderRadius: 16 }}
        >
          <div
            className="h-9 w-9 rounded-xl flex items-center justify-center flex-shrink-0"
            style={{ backgroundColor: BLUE }}
          >
            <Sparkles size={16} color={WHITE} />
          </div>
          <div className="flex-1">
            <p style={{ color: COFFEE, fontSize: 12.5, fontWeight: 600 }}>AR scan ready</p>
            <p style={{ color: COFFEE, opacity: 0.6, fontSize: 11, marginTop: 2 }}>
              {assets.some((x) => x.kind === "video")
                ? "Video scan will be reconstructed into a 3D mesh."
                : "Multiple angles will be stitched for depth analysis."}
            </p>
          </div>
        </div>
      </div>

      <div className="mt-auto px-5 pt-3 pb-6" style={{ backgroundColor: WHITE, borderTop: `1px solid ${SOFT}` }}>
        <button
          onClick={onNext}
          disabled={assets.length === 0}
          className="w-full py-3.5"
          style={{
            backgroundColor: assets.length > 0 ? ORANGE : SOFT,
            color: WHITE,
            borderRadius: 999,
            fontSize: 14,
            fontWeight: 600,
            boxShadow: assets.length > 0 ? "0 8px 22px rgba(250,136,58,0.32)" : "none",
            opacity: assets.length > 0 ? 1 : 0.6,
          }}
        >
          确认并识别物品 →
        </button>
      </div>
    </div>
  );
}

/* ---------- 1. Item confirmation ---------- */

type DetectedItem = { id: string; name: string; confidence: number; emoji?: string; category?: string };
type BlindSpot = {
  id: string;
  label: string;
  reason: string;
  left: string;
  top: string;
  w: string;
  h: string;
  resolved?: boolean;
};

function ConfirmStep({ onBack, onNext }: { onBack: () => void; onNext: () => void }) {
  const [items, setItems] = useState<DetectedItem[]>([
    { id: "i1", name: "咖啡杯", confidence: 0.97, emoji: "☕", category: "厨房" },
    { id: "i2", name: "装饰毯", confidence: 0.92, emoji: "🛋️", category: "装饰" },
    { id: "i3", name: "书籍叠放", confidence: 0.88, emoji: "📚", category: "书籍" },
    { id: "i4", name: "台灯", confidence: 0.95, emoji: "💡", category: "装饰" },
    { id: "i5", name: "装饰碗", confidence: 0.71, emoji: "🥣", category: "厨房" },
  ]);
  const [adding, set添加ing] = useState(false);
  const [newItem, setNewItem] = useState("");
  const [showItemPicker, setShowItemPicker] = useState(false);
  const [blindSpots, setBlindSpots] = useState<BlindSpot[]>([
    { id: "b1", label: "沙发后方", reason: "遮挡 — 请重新拍摄", left: "8%", top: "30%", w: "22%", h: "26%" },
    { id: "b2", label: "桌子下方", reason: "光线不足 — 请描述物品", left: "42%", top: "62%", w: "26%", h: "18%" },
  ]);
  const [activeSpot, setActiveSpot] = useState<string | null>(null);
  const [spotNote, setSpotNote] = useState("");

  const allResolved = blindSpots.every((b) => b.resolved);
  const activeBlind = blindSpots.find((b) => b.id === activeSpot);

  const removeItem = (id: string) => setItems((arr) => arr.filter((i) => i.id !== id));

  const getEmojiForItem = (name: string): string => {
    const lowerName = name.toLowerCase();
    // Simple keyword matching for common items
    if (lowerName.includes("book")) return "📚";
    if (lowerName.includes("mug") || lowerName.includes("cup") || lowerName.includes("coffee")) return "☕";
    if (lowerName.includes("lamp") || lowerName.includes("light")) return "💡";
    if (lowerName.includes("blanket") || lowerName.includes("pillow")) return "🛋️";
    if (lowerName.includes("bowl") || lowerName.includes("plate")) return "🥣";
    if (lowerName.includes("candle")) return "🕯️";
    if (lowerName.includes("plant")) return "🌿";
    if (lowerName.includes("toy")) return "🧸";
    if (lowerName.includes("cloth") || lowerName.includes("shirt") || lowerName.includes("sweater")) return "👔";
    if (lowerName.includes("tool")) return "🔧";
    if (lowerName.includes("vitamin") || lowerName.includes("pill") || lowerName.includes("medicine")) return "💊";
    return "📦"; // Default icon for unknown items
  };

  const addItem = () => {
    if (!newItem.trim()) return;
    const emoji = getEmojiForItem(newItem.trim());
    setItems((arr) => [...arr, { id: `n${Date.now()}`, name: newItem.trim(), confidence: 1, emoji }]);
    setNewItem("");
    set添加ing(false);
  };
  const resolveSpot = () => {
    if (!activeSpot) return;
    setBlindSpots((arr) => arr.map((b) => (b.id === activeSpot ? { ...b, resolved: true } : b)));
    setSpotNote("");
    setActiveSpot(null);
  };

  return (
    <div className="h-full w-full flex flex-col" style={{ backgroundColor: LINEN }}>
      {/* Image with overlays */}
      <div className="relative w-full" style={{ height: "42%" }}>
        <ImageWithFallback src={ROOM_IMG} alt="Captured" className="h-full w-full object-cover" />
        <div
          className="absolute inset-0"
          style={{
            background:
              "linear-gradient(180deg, rgba(0,0,0,0.35) 0%, rgba(0,0,0,0) 30%, rgba(0,0,0,0) 70%, rgba(246,241,235,0.6) 100%)",
          }}
        />

        <div className="absolute top-0 left-0 right-0 px-5 pt-14 flex items-center justify-between">
          <button
            onClick={onBack}
            className="h-10 w-10 rounded-full flex items-center justify-center"
            style={{ backgroundColor: "rgba(255,255,255,0.92)" }}
          >
            <ArrowLeft size={18} color={COFFEE} />
          </button>
          <div
            className="px-3.5 py-2 flex items-center gap-2"
            style={{ backgroundColor: "rgba(255,255,255,0.92)", borderRadius: 999 }}
          >
            <Sparkles size={13} color={ORANGE} />
            <span style={{ color: COFFEE, fontSize: 12, fontWeight: 500 }}>
              {items.length} items · {blindSpots.length} blind spots
            </span>
          </div>
        </div>

        {/* Blind-spot overlays */}
        {blindSpots.map((b) => (
          <button
            key={b.id}
            onClick={() => setActiveSpot(b.id)}
            className="absolute flex items-end justify-start"
            style={{
              left: b.left,
              top: b.top,
              width: b.w,
              height: b.h,
              border: `2px dashed ${b.resolved ? "#7BB28F" : ORANGE}`,
              backgroundColor: b.resolved ? "rgba(123,178,143,0.18)" : "rgba(250,136,58,0.18)",
              borderRadius: 14,
              padding: 6,
            }}
          >
            <div
              className="px-2 py-1 flex items-center gap-1"
              style={{
                backgroundColor: b.resolved ? "#7BB28F" : ORANGE,
                color: WHITE,
                borderRadius: 8,
                fontSize: 10,
                fontWeight: 600,
              }}
            >
              {b.resolved ? <Check size={10} /> : <AlertTriangle size={10} />}
              {b.label}
            </div>
          </button>
        ))}
      </div>

      {/* Sheet */}
      <div
        className="flex-1 -mt-6 px-5 pt-5 pb-6 overflow-y-auto"
        style={{
          backgroundColor: WHITE,
          borderTopLeftRadius: 28,
          borderTopRightRadius: 28,
          boxShadow: "0 -8px 30px rgba(123,92,72,0.06)",
        }}
      >
        <div className="flex items-center justify-center mb-3">
          <div className="h-1 w-10 rounded-full" style={{ backgroundColor: SOFT }} />
        </div>

        {/* Raccoon prompt */}
        <div className="flex items-start gap-3 mb-4">
          <Raccoon size={36} />
          <div
            className="flex-1 px-3.5 py-2.5"
            style={{ backgroundColor: LINEN, borderRadius: 16, borderTopLeftRadius: 4 }}
          >
            <p style={{ color: COFFEE, fontSize: 12.5, lineHeight: 1.5 }}>
              I detected {items.length} items. Please confirm, then help me with{" "}
              <span style={{ color: ORANGE, fontWeight: 600 }}>
                {blindSpots.filter((b) => !b.resolved).length} unclear area
                {blindSpots.filter((b) => !b.resolved).length === 1 ? "" : "s"}
              </span>
              .
            </p>
          </div>
        </div>

        {/* Blind spot alert list */}
        {!allResolved && (
          <div
            className="mb-4 p-3"
            style={{
              backgroundColor: "rgba(250,136,58,0.08)",
              border: `1px solid rgba(250,136,58,0.25)`,
              borderRadius: 16,
            }}
          >
            <div className="flex items-center gap-2 mb-2">
              <AlertTriangle size={14} color={ORANGE} />
              <p style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>需要你的帮助</p>
            </div>
            <div className="space-y-1.5">
              {blindSpots
                .filter((b) => !b.resolved)
                .map((b) => (
                  <button
                    key={b.id}
                    onClick={() => setActiveSpot(b.id)}
                    className="w-full flex items-center gap-2"
                  >
                    <div
                      className="h-1.5 w-1.5 rounded-full"
                      style={{ backgroundColor: ORANGE }}
                    />
                    <span style={{ color: COFFEE, fontSize: 12, flex: 1, textAlign: "left" }}>
                      <strong>{b.label}</strong> · {b.reason}
                    </span>
                    <ChevronRight size={14} color={COFFEE} opacity={0.5} />
                  </button>
                ))}
            </div>
          </div>
        )}

        {/* Detected items */}
        <div className="flex items-center justify-between mb-2">
          <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>识别到的物品</p>
          <button
            onClick={() => setShowItemPicker(true)}
            className="flex items-center gap-1 px-2.5 py-1"
            style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, fontSize: 11, fontWeight: 600 }}
          >
            <Plus size={12} /> 添加
          </button>
        </div>
        <div className="flex flex-wrap gap-2">
          {items.map((it) => (
            <div
              key={it.id}
              className="flex items-center gap-2 pl-2.5 pr-1.5 py-1.5"
              style={{
                backgroundColor: it.confidence < 0.8 ? "rgba(250,136,58,0.12)" : LINEN,
                borderRadius: 999,
              }}
            >
              {it.emoji && (
                <span style={{ fontSize: 14, lineHeight: 1 }}>{it.emoji}</span>
              )}
              <span style={{ color: COFFEE, fontSize: 12 }}>{it.name}</span>
              {it.confidence < 0.8 && (
                <span style={{ color: ORANGE, fontSize: 9, fontWeight: 600 }}>
                  {Math.round(it.confidence * 100)}%
                </span>
              )}
              <button
                onClick={() => removeItem(it.id)}
                className="h-5 w-5 rounded-full flex items-center justify-center"
                style={{ backgroundColor: WHITE }}
              >
                <X size={11} color={COFFEE} />
              </button>
            </div>
          ))}
        </div>

        <button
          onClick={onNext}
          disabled={!allResolved}
          className="w-full py-3.5 mt-5"
          style={{
            backgroundColor: allResolved ? ORANGE : SOFT,
            color: WHITE,
            borderRadius: 999,
            fontSize: 14,
            fontWeight: 600,
            boxShadow: allResolved ? "0 8px 22px rgba(250,136,58,0.32)" : "none",
          }}
        >
          {allResolved ? "Confirm & continue" : `Resolve ${blindSpots.filter((b) => !b.resolved).length} blind spot${blindSpots.filter((b) => !b.resolved).length === 1 ? "" : "s"} first`}
        </button>
      </div>

      {/* Item picker drawer */}
      {showItemPicker && (
        <div className="absolute inset-0 z-40 flex items-end" style={{ backgroundColor: "rgba(26,20,17,0.45)" }}>
          <div
            className="w-full px-5 pt-5 pb-8 max-h-[85vh] overflow-y-auto"
            style={{
              backgroundColor: WHITE,
              borderTopLeftRadius: 28,
              borderTopRightRadius: 28,
            }}
          >
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <div className="h-1 w-10 rounded-full" style={{ backgroundColor: SOFT }} />
              </div>
              <button
                onClick={() => {
                  set添加ing(true);
                  setShowItemPicker(false);
                }}
                className="flex items-center gap-1 px-3 py-1.5"
                style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, fontSize: 11, fontWeight: 600 }}
              >
                <Plus size={12} /> New Item
              </button>
            </div>

            <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600, marginBottom: 12 }}>从物品库添加</p>

            {/* Categories */}
            <div className="mb-5">
              <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600, marginBottom: 8 }}>分类</p>
              <div className="grid grid-cols-2 gap-2">
                {[
                  { name: "服饰", icon: "👔", count: 124 },
                  { name: "书籍", icon: "📚", count: 56 },
                  { name: "厨房", icon: "🍽️", count: 88 },
                  { name: "饮品", icon: "☕", count: 21 },
                  { name: "玩具", icon: "🎮", count: 34 },
                  { name: "健康", icon: "💊", count: 17 },
                  { name: "工具", icon: "🔧", count: 29 },
                  { name: "装饰", icon: "✨", count: 42 },
                ].map((cat) => (
                  <button
                    key={cat.name}
                    className="p-3 flex items-center gap-2 text-left"
                    style={{
                      backgroundColor: LINEN,
                      borderRadius: 16,
                    }}
                  >
                    <div
                      className="h-9 w-9 rounded-xl flex items-center justify-center"
                      style={{ backgroundColor: WHITE, fontSize: 18 }}
                    >
                      {cat.icon}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>{cat.name}</p>
                      <p style={{ color: COFFEE, opacity: 0.55, fontSize: 10 }}>{cat.count} items</p>
                    </div>
                  </button>
                ))}
              </div>
            </div>

            {/* Recent items */}
            <div>
              <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600, marginBottom: 8 }}>最近标记</p>
              <div className="grid grid-cols-3 gap-2">
                {[
                  { name: "羊毛衫", cat: "服饰", emoji: "🧥" },
                  { name: "陶瓷杯", cat: "厨房", emoji: "☕" },
                  { name: "小说", cat: "书籍", emoji: "📚" },
                  { name: "乐高", cat: "玩具", emoji: "🧱" },
                  { name: "维生素C", cat: "健康", emoji: "💊" },
                  { name: "香薰蜡烛", cat: "装饰", emoji: "🕯️" },
                ].map((it, idx) => (
                  <button
                    key={idx}
                    onClick={() => {
                      setItems((arr) => [
                        ...arr,
                        { id: `n${Date.now()}`, name: it.name, confidence: 1, emoji: it.emoji, category: it.cat },
                      ]);
                      setShowItemPicker(false);
                    }}
                    className="p-2.5 flex flex-col items-center"
                    style={{
                      backgroundColor: LINEN,
                      borderRadius: 14,
                    }}
                  >
                    <div
                      className="h-10 w-10 rounded-xl flex items-center justify-center mb-1.5"
                      style={{ backgroundColor: WHITE, fontSize: 20 }}
                    >
                      {it.emoji}
                    </div>
                    <p style={{ color: COFFEE, fontSize: 10, fontWeight: 600, textAlign: "center" }}>{it.name}</p>
                    <span
                      className="mt-1 px-1.5 py-0.5"
                      style={{ backgroundColor: BLUE, color: WHITE, borderRadius: 999, fontSize: 8 }}
                    >
                      {it.cat}
                    </span>
                  </button>
                ))}
              </div>
            </div>

            <button
              onClick={() => setShowItemPicker(false)}
              className="w-full py-3 mt-4"
              style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, fontSize: 13, fontWeight: 500 }}
            >
              取消
            </button>
          </div>
        </div>
      )}

      {/* 添加 new item modal */}
      {adding && (
        <div className="absolute inset-0 z-50 flex items-end" style={{ backgroundColor: "rgba(26,20,17,0.45)" }}>
          <div
            className="w-full px-5 pt-5 pb-8"
            style={{
              backgroundColor: WHITE,
              borderTopLeftRadius: 28,
              borderTopRightRadius: 28,
            }}
          >
            <div className="flex items-center justify-center mb-3">
              <div className="h-1 w-10 rounded-full" style={{ backgroundColor: SOFT }} />
            </div>
            <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600, marginBottom: 12 }}>添加新物品</p>

            <div
              className="px-4 py-3 mb-3"
              style={{ backgroundColor: LINEN, borderRadius: 16 }}
            >
              <input
                autoFocus
                value={newItem}
                onChange={(e) => setNewItem(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && addItem()}
                placeholder="例如：咖啡杯、抱枕等…"
                className="w-full bg-transparent outline-none"
                style={{ color: COFFEE, fontSize: 14 }}
              />
            </div>

            <div className="flex gap-2">
              <button
                onClick={() => {
                  set添加ing(false);
                  setNewItem("");
                }}
                className="flex-1 py-3"
                style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, fontSize: 13, fontWeight: 500 }}
              >
                取消
              </button>
              <button
                onClick={addItem}
                disabled={!newItem.trim()}
                className="flex-1 py-3"
                style={{
                  backgroundColor: newItem.trim() ? ORANGE : SOFT,
                  color: WHITE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                添加物品
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Blind-spot resolve modal */}
      {activeBlind && (
        <div className="absolute inset-0 z-40 flex items-end" style={{ backgroundColor: "rgba(26,20,17,0.45)" }}>
          <div
            className="w-full px-5 pt-5 pb-8"
            style={{
              backgroundColor: WHITE,
              borderTopLeftRadius: 28,
              borderTopRightRadius: 28,
            }}
          >
            <div className="flex items-center justify-center mb-3">
              <div className="h-1 w-10 rounded-full" style={{ backgroundColor: SOFT }} />
            </div>
            <div className="flex items-center gap-2 mb-1">
              <AlertTriangle size={14} color={ORANGE} />
              <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>{activeBlind.label}</p>
            </div>
            <p style={{ color: COFFEE, opacity: 0.6, fontSize: 12, marginBottom: 14 }}>
              {activeBlind.reason}
            </p>

            <div className="grid grid-cols-2 gap-3 mb-4">
              <button
                className="py-4 flex flex-col items-center gap-2"
                style={{
                  backgroundColor: LINEN,
                  borderRadius: 18,
                  border: `1px dashed ${SOFT}`,
                }}
              >
                <Camera size={20} color={ORANGE} />
                <span style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>
                  重新拍摄区域
                </span>
                <span style={{ color: COFFEE, opacity: 0.55, fontSize: 10 }}>更近角度</span>
              </button>
              <button
                className="py-4 flex flex-col items-center gap-2"
                style={{
                  backgroundColor: LINEN,
                  borderRadius: 18,
                  border: `1px dashed ${SOFT}`,
                }}
              >
                <Edit3 size={20} color={ORANGE} />
                <span style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>
                  描述物品
                </span>
                <span style={{ color: COFFEE, opacity: 0.55, fontSize: 10 }}>在下方输入</span>
              </button>
            </div>

            <div
              className="px-4 py-3 mb-3"
              style={{ backgroundColor: LINEN, borderRadius: 16 }}
            >
              <input
                value={spotNote}
                onChange={(e) => setSpotNote(e.target.value)}
                placeholder="例如：3双鞋子、一个猫玩具…"
                className="w-full bg-transparent outline-none"
                style={{ color: COFFEE, fontSize: 13 }}
              />
            </div>

            <div className="flex gap-2">
              <button
                onClick={() => {
                  setActiveSpot(null);
                  setSpotNote("");
                }}
                className="flex-1 py-3"
                style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, fontSize: 13, fontWeight: 500 }}
              >
                取消
              </button>
              <button
                onClick={resolveSpot}
                className="flex-1 py-3"
                style={{
                  backgroundColor: ORANGE,
                  color: WHITE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                标记已解决
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/* ---------- 2. LLM-style requirement prompt ---------- */

type StyleOption = {
  id: string;
  name: string;
  description: string;
  image: string;
  tags: string[];
};

type ChatMsg = {
  id: string;
  role: "user" | "ai";
  text: string;
  styleOptions?: StyleOption[];
};

const STYLE_OPTIONS: StyleOption[] = [
  {
    id: "minimal",
    name: "极简禅意",
    description: "简洁线条、隐藏式收纳、中性色调",
    image: "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400",
    tags: ["极简", "清爽", "宁静"],
  },
  {
    id: "cozy",
    name: "温馨舒适",
    description: "纹理面料、温暖光线、个人化点缀",
    image: "https://images.unsplash.com/photo-1586023492125-27b2c045efd7?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400",
    tags: ["温馨", "温暖", "舒适"],
  },
  {
    id: "modern",
    name: "现代功能",
    description: "智能收纳、模块化设计、高效布局",
    image: "https://images.unsplash.com/photo-1556912998-c57cc6b63cd7?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400",
    tags: ["现代", "实用", "简约"],
  },
];

const QUICK_TAGS = [
  "极简主义",
  "节省空间",
  "儿童友好",
  "温馨舒适",
  "快速 (5-10分钟)",
  "深度清洁",
  "捐赠闲置",
  "保持可见",
  "宠物安全",
];

const REF_LIBRARY = [
  "https://images.unsplash.com/photo-1775029918191-32e44ee20d06?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400",
  "https://images.unsplash.com/photo-1772475385491-f3cf64d4131a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400",
  "https://images.unsplash.com/photo-1758366278666-902516aac79f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400",
  "https://images.unsplash.com/photo-1769690398992-dfafcba3d41b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400",
  "https://images.unsplash.com/photo-1772475385426-ebd50c772229?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400",
  "https://images.unsplash.com/photo-1764588037085-a78240016f8b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400",
];

function PromptStep({ onBack, onNext }: { onBack: () => void; onNext: () => void }) {
  const [tags, setTags] = useState<string[]>(["Minimalist", "Quick (5–10 min)"]);
  const [input, setInput] = useState("");
  const [refs, setRefs] = useState<string[]>([]);
  const [picker, setPicker] = useState<null | "menu" | "album">(null);
  const [selectedStyle, setSelectedStyle] = useState<string | null>(null);
  const [styleConfirmed, setStyleConfirmed] = useState(false);
  const [messages, setMessages] = useState<ChatMsg[]>([
    {
      id: "m1",
      role: "ai",
      text: "已获取照片和5个物品。你想要什么风格？选择几个标签或用你自己的话描述 ✨",
    },
  ]);

  const toggleTag = (t: string) =>
    setTags((arr) => (arr.includes(t) ? arr.filter((x) => x !== t) : [...arr, t]));

  const send = () => {
    const text = input.trim();
    if (!text && tags.length === 0 && refs.length === 0) return;
    const parts: string[] = [];
    if (text) parts.push(text);
    if (refs.length) parts.push(`📎 ${refs.length} reference photo${refs.length === 1 ? "" : "s"}`);
    const compiled = parts.join("  ·  ") || `Style: ${tags.join(", ")}`;
    const userMsg: ChatMsg = { id: `u${Date.now()}`, role: "user", text: compiled };

    // First message - offer style options
    const isFirstUserMessage = messages.filter(m => m.role === "user").length === 0;

    const aiMsg: ChatMsg = isFirstUserMessage
      ? {
          id: `a${Date.now()}`,
          role: "ai",
          text: "根据你的需求，我为你精选了3种风格方向。看看下面的视觉参考，告诉我哪种更适合你 — 或者告诉我如何调整！🎨",
          styleOptions: STYLE_OPTIONS,
        }
      : {
          id: `a${Date.now()}`,
          role: "ai",
          text: refs.length
            ? `Got it — analyzing your ${refs.length} reference${refs.length === 1 ? "" : "s"} for color, layout & vibe. I'll match the mood in your plan.`
            : `Perfect! I'll adjust the plan with your feedback. ${selectedStyle ? "Let me know if you want to refine the style further." : ""}`,
        };

    setMessages((m) => [...m, userMsg, aiMsg]);
    setInput("");
  };

  const removeRef = (src: string) => setRefs((r) => r.filter((x) => x !== src));
  const addRef = (src: string) => {
    setRefs((r) => (r.includes(src) ? r : [...r, src]));
  };

  return (
    <div className="h-full w-full flex flex-col" style={{ backgroundColor: LINEN }}>
      {/* Header */}
      <div className="px-5 pt-14 pb-3 flex items-center gap-3">
        <button
          onClick={onBack}
          className="h-10 w-10 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ArrowLeft size={18} color={COFFEE} />
        </button>
        <div className="flex-1">
          <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>Describe your goal</p>
          <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>
            浣序 AI · personalized plan
          </p>
        </div>
        <div
          className="h-9 w-9 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <Sparkles size={16} color={ORANGE} />
        </div>
      </div>

      {/* Captured-photo chip */}
      <div className="px-5 mb-2">
        <div
          className="flex items-center gap-3 p-2"
          style={{
            backgroundColor: WHITE,
            borderRadius: 16,
            boxShadow: "0 3px 12px rgba(123,92,72,0.04)",
          }}
        >
          <div className="h-12 w-12 overflow-hidden flex-shrink-0" style={{ borderRadius: 12 }}>
            <ImageWithFallback src={ROOM_IMG} alt="Scene" className="h-full w-full object-cover" />
          </div>
          <div className="flex-1 min-w-0">
            <p style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>客厅扫描</p>
            <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>5 items · 2 zones confirmed</p>
          </div>
          <span
            className="px-2 py-0.5"
            style={{ backgroundColor: "#7BB28F", color: WHITE, borderRadius: 999, fontSize: 10, fontWeight: 600 }}
          >
            READY
          </span>
        </div>
      </div>

      {/* Chat thread */}
      <div className="flex-1 overflow-y-auto px-5 pt-2 pb-2 space-y-3">
        {messages.map((m) =>
          m.role === "ai" ? (
            <div key={m.id} className="space-y-2">
              <div className="flex items-start gap-2">
                <Raccoon size={30} />
                <div
                  className="px-3.5 py-2.5 max-w-[78%]"
                  style={{
                    backgroundColor: WHITE,
                    borderRadius: 18,
                    borderTopLeftRadius: 6,
                    boxShadow: "0 2px 10px rgba(123,92,72,0.04)",
                  }}
                >
                  <p style={{ color: COFFEE, fontSize: 13, lineHeight: 1.55 }}>{m.text}</p>
                </div>
              </div>

              {/* Style options */}
              {m.styleOptions && (
                <div className="ml-9 space-y-2">
                  {m.styleOptions.map((style) => {
                    const isSelected = selectedStyle === style.id;
                    return (
                      <button
                        key={style.id}
                        onClick={() => {
                          setSelectedStyle(style.id);
                          setStyleConfirmed(false);
                        }}
                        className="w-full text-left"
                        style={{
                          backgroundColor: WHITE,
                          borderRadius: 16,
                          overflow: "hidden",
                          border: isSelected ? `2px solid ${ORANGE}` : "2px solid transparent",
                          boxShadow: "0 3px 12px rgba(123,92,72,0.06)",
                        }}
                      >
                        <div className="relative h-28 w-full">
                          <ImageWithFallback
                            src={style.image}
                            alt={style.name}
                            className="h-full w-full object-cover"
                          />
                          {isSelected && (
                            <div
                              className="absolute top-2 right-2 h-7 w-7 rounded-full flex items-center justify-center"
                              style={{ backgroundColor: ORANGE }}
                            >
                              <Check size={14} color={WHITE} />
                            </div>
                          )}
                        </div>
                        <div className="p-3">
                          <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600, marginBottom: 2 }}>
                            {style.name}
                          </p>
                          <p style={{ color: COFFEE, opacity: 0.6, fontSize: 11, marginBottom: 6 }}>
                            {style.description}
                          </p>
                          <div className="flex gap-1.5">
                            {style.tags.map((tag) => (
                              <span
                                key={tag}
                                className="px-2 py-0.5"
                                style={{
                                  backgroundColor: isSelected ? "rgba(250,136,58,0.12)" : LINEN,
                                  color: isSelected ? ORANGE : COFFEE,
                                  borderRadius: 999,
                                  fontSize: 9,
                                  fontWeight: 600,
                                }}
                              >
                                {tag}
                              </span>
                            ))}
                          </div>
                        </div>
                      </button>
                    );
                  })}

                  {/* Confirm style button */}
                  {selectedStyle && !styleConfirmed && (
                    <button
                      onClick={() => {
                        setStyleConfirmed(true);
                        const selectedStyleObj = m.styleOptions?.find((s) => s.id === selectedStyle);
                        const userConfirmMsg: ChatMsg = {
                          id: `u${Date.now()}`,
                          role: "user",
                          text: `我喜欢"${selectedStyleObj?.name}"风格！✨`,
                        };
                        const aiConfirmMsg: ChatMsg = {
                          id: `a${Date.now()}`,
                          role: "ai",
                          text: `很好的选择！"${selectedStyleObj?.name}"将成为你方案的基础。你可以继续添加更多细节或调整，准备好后点击"生成方案"即可！🎯`,
                        };
                        setMessages((msgs) => [...msgs, userConfirmMsg, aiConfirmMsg]);
                      }}
                      className="w-full py-2.5"
                      style={{
                        backgroundColor: ORANGE,
                        color: WHITE,
                        borderRadius: 999,
                        fontSize: 12,
                        fontWeight: 600,
                        boxShadow: "0 4px 14px rgba(250,136,58,0.28)",
                      }}
                    >
                      确认这个风格 →
                    </button>
                  )}
                </div>
              )}
            </div>
          ) : (
            <div key={m.id} className="flex justify-end">
              <div
                className="px-3.5 py-2.5 max-w-[78%]"
                style={{
                  backgroundColor: COFFEE,
                  color: WHITE,
                  borderRadius: 18,
                  borderTopRightRadius: 6,
                }}
              >
                <p style={{ fontSize: 13, lineHeight: 1.55 }}>{m.text}</p>
              </div>
            </div>
          ),
        )}
      </div>

      {/* Quick tag rail */}
      <div className="px-5 pt-2 pb-2">
        <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginBottom: 8 }}>
          Quick tags · {tags.length} selected
        </p>
        <div className="overflow-x-auto -mx-1 px-1">
          <div className="flex gap-2" style={{ width: "max-content" }}>
            {QUICK_TAGS.map((t) => {
              const active = tags.includes(t);
              return (
                <button
                  key={t}
                  onClick={() => toggleTag(t)}
                  className="px-3.5 py-1.5 flex-shrink-0 flex items-center gap-1"
                  style={{
                    backgroundColor: active ? ORANGE : WHITE,
                    color: active ? WHITE : COFFEE,
                    borderRadius: 999,
                    fontSize: 12,
                    fontWeight: active ? 600 : 500,
                    border: active ? "none" : `1px solid ${SOFT}`,
                  }}
                >
                  {active && <Check size={11} />}
                  {t}
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* Composer */}
      <div
        className="px-4 pt-3 pb-6"
        style={{
          backgroundColor: WHITE,
          borderTop: `1px solid ${SOFT}`,
        }}
      >
        {/* Attached reference photos */}
        {refs.length > 0 && (
          <div className="flex gap-2 mb-2 overflow-x-auto -mx-1 px-1">
            {refs.map((src) => (
              <div
                key={src}
                className="relative flex-shrink-0"
                style={{ width: 56, height: 56, borderRadius: 12, overflow: "hidden" }}
              >
                <ImageWithFallback src={src} alt="ref" className="h-full w-full object-cover" />
                <button
                  onClick={() => removeRef(src)}
                  className="absolute top-0.5 right-0.5 h-5 w-5 rounded-full flex items-center justify-center"
                  style={{ backgroundColor: "rgba(26,20,17,0.7)" }}
                >
                  <X size={10} color={WHITE} />
                </button>
              </div>
            ))}
          </div>
        )}

        <div
          className="flex items-end gap-2 px-2 py-2"
          style={{ backgroundColor: LINEN, borderRadius: 22 }}
        >
          <button
            onClick={() => setPicker("menu")}
            className="h-9 w-9 rounded-full flex items-center justify-center flex-shrink-0"
            style={{ backgroundColor: WHITE }}
          >
            <Paperclip size={15} color={COFFEE} />
          </button>
          <button className="h-8 w-8 rounded-full flex items-center justify-center flex-shrink-0">
            <Mic size={16} color={COFFEE} />
          </button>
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="例如：保持书籍可见、隐藏电线、捐赠一年没用过的物品…"
            rows={1}
            className="flex-1 bg-transparent outline-none resize-none py-1.5"
            style={{ color: COFFEE, fontSize: 13, lineHeight: 1.5, maxHeight: 90 }}
          />
          <button
            onClick={send}
            className="h-9 w-9 rounded-full flex items-center justify-center flex-shrink-0"
            style={{
              backgroundColor: ORANGE,
              boxShadow: "0 4px 12px rgba(250,136,58,0.32)",
            }}
          >
            <Send size={15} color={WHITE} />
          </button>
        </div>

        <p style={{ color: COFFEE, opacity: 0.5, fontSize: 10, marginTop: 6, textAlign: "center" }}>
          添加 reference photos for a more accurate plan ✨
        </p>

        <button
          onClick={onNext}
          disabled={!styleConfirmed}
          className="w-full py-3.5 mt-3"
          style={{
            backgroundColor: styleConfirmed ? COFFEE : SOFT,
            color: WHITE,
            borderRadius: 999,
            fontSize: 14,
            fontWeight: 600,
            opacity: styleConfirmed ? 1 : 0.6,
          }}
        >
          {styleConfirmed ? "生成方案 →" : "请先选择风格"}
        </button>
      </div>

      {/* Attachment picker */}
      {picker && (
        <div
          className="absolute inset-0 z-40 flex items-end"
          style={{ backgroundColor: "rgba(26,20,17,0.45)" }}
          onClick={() => setPicker(null)}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="w-full px-5 pt-5 pb-8"
            style={{
              backgroundColor: WHITE,
              borderTopLeftRadius: 28,
              borderTopRightRadius: 28,
              maxHeight: "75%",
              overflowY: "auto",
            }}
          >
            <div className="flex items-center justify-center mb-3">
              <div className="h-1 w-10 rounded-full" style={{ backgroundColor: SOFT }} />
            </div>

            {picker === "menu" && (
              <>
                <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600, marginBottom: 4 }}>
                  添加 reference photo
                </p>
                <p style={{ color: COFFEE, opacity: 0.55, fontSize: 12, marginBottom: 16 }}>
                  Show me a vibe, a layout, or a "before" pic — I'll match it.
                </p>

                <div className="grid grid-cols-2 gap-3 mb-2">
                  <button
                    onClick={() => {
                      addRef(REF_LIBRARY[Math.floor(Math.random() * REF_LIBRARY.length)]);
                      setPicker(null);
                    }}
                    className="py-5 flex flex-col items-center gap-2"
                    style={{
                      backgroundColor: LINEN,
                      borderRadius: 18,
                      border: `1px dashed ${SOFT}`,
                    }}
                  >
                    <div
                      className="h-11 w-11 rounded-2xl flex items-center justify-center"
                      style={{ backgroundColor: ORANGE }}
                    >
                      <Camera size={20} color={WHITE} />
                    </div>
                    <span style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>
                      Take photo
                    </span>
                    <span style={{ color: COFFEE, opacity: 0.55, fontSize: 10 }}>
                      Capture now
                    </span>
                  </button>
                  <button
                    onClick={() => setPicker("album")}
                    className="py-5 flex flex-col items-center gap-2"
                    style={{
                      backgroundColor: LINEN,
                      borderRadius: 18,
                      border: `1px dashed ${SOFT}`,
                    }}
                  >
                    <div
                      className="h-11 w-11 rounded-2xl flex items-center justify-center"
                      style={{ backgroundColor: BLUE }}
                    >
                      <ImagePlus size={20} color={WHITE} />
                    </div>
                    <span style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>
                      From album
                    </span>
                    <span style={{ color: COFFEE, opacity: 0.55, fontSize: 10 }}>
                      Pick existing
                    </span>
                  </button>
                </div>

                <button
                  onClick={() => setPicker(null)}
                  className="w-full py-3 mt-3"
                  style={{
                    backgroundColor: LINEN,
                    color: COFFEE,
                    borderRadius: 999,
                    fontSize: 13,
                    fontWeight: 500,
                  }}
                >
                  取消
                </button>
              </>
            )}

            {picker === "album" && (
              <>
                <div className="flex items-center justify-between mb-3">
                  <button
                    onClick={() => setPicker("menu")}
                    className="flex items-center gap-1"
                    style={{ color: COFFEE, fontSize: 13 }}
                  >
                    <ArrowLeft size={14} /> Back
                  </button>
                  <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>
                    Recent photos
                  </p>
                  <span style={{ color: ORANGE, fontSize: 12, fontWeight: 600 }}>
                    {refs.length} added
                  </span>
                </div>
                <div className="grid grid-cols-3 gap-1.5">
                  {REF_LIBRARY.map((src) => {
                    const sel = refs.includes(src);
                    return (
                      <button
                        key={src}
                        onClick={() => (sel ? removeRef(src) : addRef(src))}
                        className="relative aspect-square overflow-hidden"
                        style={{ borderRadius: 12 }}
                      >
                        <ImageWithFallback src={src} alt="" className="h-full w-full object-cover" />
                        {sel && (
                          <div
                            className="absolute inset-0 flex items-center justify-center"
                            style={{ backgroundColor: "rgba(250,136,58,0.35)" }}
                          >
                            <div
                              className="h-7 w-7 rounded-full flex items-center justify-center"
                              style={{ backgroundColor: ORANGE }}
                            >
                              <Check size={14} color={WHITE} />
                            </div>
                          </div>
                        )}
                      </button>
                    );
                  })}
                </div>
                <button
                  onClick={() => setPicker(null)}
                  className="w-full py-3 mt-4"
                  style={{
                    backgroundColor: ORANGE,
                    color: WHITE,
                    borderRadius: 999,
                    fontSize: 13,
                    fontWeight: 600,
                  }}
                >
                  完成
                </button>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

/* ---------- B. Step Planning ---------- */

const zones = [
  { n: 1, label: "Coffee Table", left: "12%", top: "38%", w: "32%", h: "26%" },
  { n: 2, label: "Sofa Area", left: "46%", top: "28%", w: "38%", h: "42%" },
  { n: 3, label: "Shelf Corner", left: "8%", top: "8%", w: "28%", h: "24%" },
];

const durations = [
  { id: "5min", label: "5min", sub: "Quick Fix" },
  { id: "10min", label: "10min", sub: "Standard" },
  { id: "1h", label: "1h", sub: "Deep Clean" },
];

const PLAN_TIERS: {
  id: PlanTier;
  label: string;
  tagline: string;
  duration: string;
  steps: number;
  badge: string;
  accent: string;
  features: string[];
  tools: boolean;
  image: string;
}[] = [
  {
    id: "basic",
    label: "快速整理",
    tagline: "只做基础整理",
    duration: "10 min",
    steps: 6,
    badge: "BASIC",
    accent: BLUE,
    features: ["表面整理", "物品归位", "无需工具"],
    tools: false,
    image: "https://images.unsplash.com/photo-1649083048269-8bfb755e7b87?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtaW5pbWFsJTIwb3JnYW5pemVkJTIwbGl2aW5nJTIwcm9vbSUyMGNsZWFuJTIwc2ltcGxlfGVufDF8fHx8MTc3ODYzNTc2OHww&ixlib=rb-4.1.0&q=80&w=1080",
  },
  {
    id: "smart",
    label: "智能整理",
    tagline: "AI平衡方案",
    duration: "25 min",
    steps: 12,
    badge: "SMART",
    accent: ORANGE,
    features: ["分区整理", "按类别分组", "可选工具"],
    tools: false,
    image: "https://images.unsplash.com/photo-1768875836660-ff4eeaa8ffeb?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxzbWFydCUyMGhvbWUlMjBvcmdhbml6YXRpb24lMjBzdG9yYWdlJTIwc2hlbHZlcyUyMG1vZGVybnxlbnwxfHx8fDE3Nzg2MzU3Njh8MA&ixlib=rb-4.1.0&q=80&w=1080",
  },
  {
    id: "pro",
    label: "专业收纳",
    tagline: "杂志级效果",
    duration: "1h 20m",
    steps: 22,
    badge: "PRO",
    accent: "#A88370",
    features: ["风格协调", "工具推荐", "持久效果"],
    tools: true,
    image: "https://images.unsplash.com/photo-1721173019267-36e0fc537206?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwzfHxsdXh1cnklMjBvcmdhbml6ZWQlMjBjbG9zZXQlMjBtYWdhemluZSUyMHN0eWxlZCUyMHN0b3JhZ2V8ZW58MXx8fHwxNzc4NjM1NzY5fDA&ixlib=rb-4.1.0&q=80&w=1080",
  },
];

function PlansStep({ onBack, onPick }: { onBack: () => void; onPick: (t: PlanTier) => void }) {
  const [selected, setSelected] = useState<PlanTier>("smart");
  const plan = PLAN_TIERS.find((p) => p.id === selected)!;

  return (
    <div className="h-full w-full overflow-y-auto pb-8" style={{ backgroundColor: LINEN }}>
      <div className="px-6 pt-14 pb-2 flex items-center justify-between">
        <button
          onClick={onBack}
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ArrowLeft size={20} color={COFFEE} />
        </button>
        <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>选择方案</p>
        <div className="w-11" />
      </div>

      <div className="px-6 mt-3">
        <p style={{ color: COFFEE, opacity: 0.6, fontSize: 13 }}>
          3 plans generated for your space · tap to compare
        </p>
      </div>

      <div className="px-6 mt-5 space-y-3">
        {PLAN_TIERS.map((p) => {
          const active = selected === p.id;
          return (
            <button
              key={p.id}
              onClick={() => setSelected(p.id)}
              className="w-full text-left overflow-hidden"
              style={{
                backgroundColor: WHITE,
                borderRadius: 22,
                border: `2px solid ${active ? p.accent : "transparent"}`,
                boxShadow: active
                  ? `0 8px 24px ${p.accent}33`
                  : "0 4px 14px rgba(123,92,72,0.05)",
              }}
            >
              {/* Image preview */}
              <div className="relative h-32 w-full">
                <ImageWithFallback
                  src={p.image}
                  alt={p.label}
                  className="h-full w-full object-cover"
                />
                <div
                  className="absolute inset-0"
                  style={{
                    background: `linear-gradient(180deg, rgba(0,0,0,0.15) 0%, rgba(0,0,0,0.4) 100%)`,
                  }}
                />
                {/* Badge overlay */}
                <div className="absolute top-3 left-3 flex items-center gap-2">
                  <span
                    className="px-2.5 py-1"
                    style={{
                      backgroundColor: p.accent,
                      color: WHITE,
                      borderRadius: 999,
                      fontSize: 10,
                      fontWeight: 600,
                    }}
                  >
                    {p.badge}
                  </span>
                  <div
                    className="h-8 w-8 rounded-xl flex items-center justify-center"
                    style={{ backgroundColor: "rgba(255,255,255,0.92)" }}
                  >
                    {p.id === "basic" && <Zap size={16} color={p.accent} />}
                    {p.id === "smart" && <Sparkles size={16} color={p.accent} />}
                    {p.id === "pro" && <Layers size={16} color={p.accent} />}
                  </div>
                </div>
                {/* Check mark for selected */}
                <div
                  className="absolute top-3 right-3 h-6 w-6 rounded-full flex items-center justify-center"
                  style={{
                    backgroundColor: active ? p.accent : "rgba(255,255,255,0.7)",
                    border: `2px solid ${active ? p.accent : "rgba(255,255,255,0.9)"}`,
                  }}
                >
                  {active && <Check size={12} color={WHITE} />}
                </div>
              </div>

              {/* Content */}
              <div className="p-4">
                <div className="flex items-center gap-2 mb-1">
                  <span style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>
                    {p.duration} · {p.steps} steps
                  </span>
                </div>
                <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>{p.label}</p>
                <p style={{ color: COFFEE, opacity: 0.6, fontSize: 12, marginTop: 2 }}>
                  {p.tagline}
                </p>
                {active && (
                  <div className="mt-2.5 space-y-1">
                    {p.features.map((f) => (
                      <div key={f} className="flex items-center gap-1.5">
                        <Check size={11} color={p.accent} />
                        <span style={{ color: COFFEE, opacity: 0.75, fontSize: 11 }}>{f}</span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </button>
          );
        })}
      </div>

      <div className="px-6 mt-6">
        <button
          onClick={() => onPick(selected)}
          className="w-full py-4 flex items-center justify-center gap-2"
          style={{
            backgroundColor: plan.accent,
            color: WHITE,
            borderRadius: 999,
            fontSize: 15,
            fontWeight: 600,
            boxShadow: `0 8px 24px ${plan.accent}55`,
          }}
        >
          继续使用 {plan.label}
          <ChevronRight size={18} color={WHITE} />
        </button>
      </div>
    </div>
  );
}

const TOOLS = [
  {
    id: "t1",
    name: "亚麻收纳盒",
    sub: "3个装 · 可堆叠",
    price: "¥89",
    img: "https://images.unsplash.com/photo-1772475385491-f3cf64d4131a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400",
    use: "用于整理搁板上的零散小物品",
    brand: "无印良品",
    size: "26×37×12cm",
    material: "亚麻布 + 纸板",
    link: "https://www.muji.com",
  },
  {
    id: "t2",
    name: "相思木置物架",
    sub: "双层 · 储藏室/搁板",
    price: "¥68",
    img: "https://images.unsplash.com/photo-1764588037085-a78240016f8b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400",
    use: "将书籍和装饰品分层摆放",
    brand: "宜家",
    size: "40×20×8cm",
    material: "相思木",
    link: "https://www.ikea.cn",
  },
  {
    id: "t3",
    name: "理线收纳套",
    sub: "1.5m · 魔术贴",
    price: "¥29",
    img: "https://images.unsplash.com/photo-1775029918191-32e44ee20d06?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400",
    use: "整理充电器和台灯线缆",
    brand: "绿联",
    size: "1.5m×3cm",
    material: "尼龙",
    link: "https://www.ugreen.com",
  },
];

function ToolsStep({ onBack, onNext }: { onBack: () => void; onNext: () => void }) {
  const [have, setHave] = useState<Record<string, boolean>>({});
  const [viewingTool, setViewingTool] = useState<string | null>(null);
  const toggle = (id: string) => setHave((h) => ({ ...h, [id]: !h[id] }));
  const haveCount = Object.values(have).filter(Boolean).length;

  const currentTool = TOOLS.find(t => t.id === viewingTool);

  if (currentTool) {
    return <ToolPurchaseDetail tool={currentTool} onBack={() => setViewingTool(null)} />;
  }

  return (
    <div className="h-full w-full overflow-y-auto pb-8" style={{ backgroundColor: LINEN }}>
      <div className="px-6 pt-14 pb-2 flex items-center justify-between">
        <button
          onClick={onBack}
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ArrowLeft size={20} color={COFFEE} />
        </button>
        <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>所需工具</p>
        <div className="w-11" />
      </div>

      <div className="px-6 mt-3">
        <div
          className="p-4 flex items-center gap-3"
          style={{
            background: `linear-gradient(135deg, ${COFFEE} 0%, #5d4334 100%)`,
            borderRadius: 20,
          }}
        >
          <div
            className="h-10 w-10 rounded-xl flex items-center justify-center flex-shrink-0"
            style={{ backgroundColor: "rgba(255,255,255,0.15)" }}
          >
            <Box size={18} color={WHITE} />
          </div>
          <div className="flex-1 min-w-0">
            <p style={{ color: WHITE, fontSize: 13, fontWeight: 600 }}>
              智能方案使用收纳工具
            </p>
            <p style={{ color: WHITE, opacity: 0.7, fontSize: 11, marginTop: 2 }}>
              标记你已有的工具，或查看购买推荐
            </p>
          </div>
        </div>
      </div>

      <div className="px-6 mt-5 space-y-3">
        {TOOLS.map((t) => {
          const owned = have[t.id];
          return (
            <div
              key={t.id}
              className="p-3 flex gap-3"
              style={{
                backgroundColor: WHITE,
                borderRadius: 20,
                boxShadow: "0 4px 14px rgba(123,92,72,0.05)",
              }}
            >
              <div
                className="w-20 h-20 rounded-2xl overflow-hidden flex-shrink-0"
                style={{ backgroundColor: LINEN }}
              >
                <ImageWithFallback src={t.img} alt={t.name} className="h-full w-full object-cover" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between">
                  <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{t.name}</p>
                  <span style={{ color: ORANGE, fontSize: 12, fontWeight: 600 }}>{t.price}</span>
                </div>
                <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginTop: 1 }}>{t.sub}</p>
                <div className="flex items-start gap-1 mt-2">
                  <Sparkles size={10} color={ORANGE} style={{ marginTop: 2 }} />
                  <p style={{ color: COFFEE, opacity: 0.7, fontSize: 11 }}>{t.use}</p>
                </div>
                <div className="flex gap-2 mt-2">
                  <button
                    onClick={() => toggle(t.id)}
                    className="px-2.5 py-1 flex items-center gap-1"
                    style={{
                      backgroundColor: owned ? "#7BB28F" : LINEN,
                      color: owned ? WHITE : COFFEE,
                      borderRadius: 999,
                      fontSize: 10,
                      fontWeight: 600,
                    }}
                  >
                    {owned && <Check size={11} />}
                    {owned ? "已拥有" : "标记已有"}
                  </button>
                  {!owned && (
                    <button
                      onClick={() => setViewingTool(t.id)}
                      className="px-2.5 py-1 flex items-center gap-1"
                      style={{
                        backgroundColor: ORANGE,
                        color: WHITE,
                        borderRadius: 999,
                        fontSize: 10,
                        fontWeight: 600,
                      }}
                    >
                      购买推荐
                    </button>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <div className="px-6 mt-5">
        <div
          className="p-3 flex items-center gap-2"
          style={{ backgroundColor: WHITE, borderRadius: 14 }}
        >
          <CheckCircle2 size={14} color={ORANGE} />
          <span style={{ color: COFFEE, opacity: 0.7, fontSize: 11 }}>
            已有 {haveCount}/{TOOLS.length} · 还需 {TOOLS.length - haveCount} 件
          </span>
        </div>
      </div>

      <div className="px-6 mt-5">
        <button
          onClick={onNext}
          className="w-full py-4 flex items-center justify-center gap-2"
          style={{
            backgroundColor: ORANGE,
            color: WHITE,
            borderRadius: 999,
            fontSize: 15,
            fontWeight: 600,
            boxShadow: "0 8px 24px rgba(250,136,58,0.35)",
          }}
        >
          知道了，告诉我如何使用
          <ChevronRight size={18} color={WHITE} />
        </button>
      </div>
    </div>
  );
}

function ToolPurchaseDetail({
  tool,
  onBack
}: {
  tool: typeof TOOLS[number];
  onBack: () => void;
}) {
  return (
    <div className="h-full w-full overflow-y-auto pb-8" style={{ backgroundColor: LINEN }}>
      <div className="px-6 pt-14 pb-2 flex items-center justify-between">
        <button
          onClick={onBack}
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ArrowLeft size={20} color={COFFEE} />
        </button>
        <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>购买推荐</p>
        <div className="w-11" />
      </div>

      {/* Product Image */}
      <div className="px-6 mt-4">
        <div
          className="w-full rounded-3xl overflow-hidden"
          style={{ height: 280, backgroundColor: WHITE }}
        >
          <ImageWithFallback
            src={tool.img}
            alt={tool.name}
            className="h-full w-full object-cover"
          />
        </div>
      </div>

      {/* Product Info */}
      <div className="px-6 mt-5">
        <div
          className="p-5"
          style={{
            backgroundColor: WHITE,
            borderRadius: 24,
            boxShadow: "0 4px 18px rgba(123,92,72,0.06)",
          }}
        >
          <div className="flex items-start justify-between mb-3">
            <div className="flex-1">
              <p style={{ color: COFFEE, fontSize: 18, fontWeight: 600 }}>{tool.name}</p>
              <p style={{ color: COFFEE, opacity: 0.55, fontSize: 12, marginTop: 4 }}>
                {tool.sub}
              </p>
            </div>
            <span
              className="px-3 py-1.5 ml-3"
              style={{
                backgroundColor: ORANGE,
                color: WHITE,
                borderRadius: 999,
                fontSize: 16,
                fontWeight: 600,
              }}
            >
              {tool.price}
            </span>
          </div>

          <div className="mt-4 space-y-2.5">
            <div className="flex items-start gap-2">
              <Box size={14} color={ORANGE} style={{ marginTop: 2 }} />
              <div className="flex-1">
                <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>品牌</p>
                <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{tool.brand}</p>
              </div>
            </div>

            <div className="flex items-start gap-2">
              <Move3d size={14} color={ORANGE} style={{ marginTop: 2 }} />
              <div className="flex-1">
                <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>尺寸</p>
                <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{tool.size}</p>
              </div>
            </div>

            <div className="flex items-start gap-2">
              <Layers size={14} color={ORANGE} style={{ marginTop: 2 }} />
              <div className="flex-1">
                <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>材质</p>
                <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{tool.material}</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Usage Description */}
      <div className="px-6 mt-4">
        <div
          className="p-4 flex items-start gap-3"
          style={{
            backgroundColor: "rgba(250,136,58,0.08)",
            border: `1px solid rgba(250,136,58,0.25)`,
            borderRadius: 18,
          }}
        >
          <Sparkles size={16} color={ORANGE} style={{ marginTop: 1 }} />
          <div className="flex-1">
            <p style={{ color: COFFEE, fontSize: 12, fontWeight: 600, marginBottom: 4 }}>
              推荐理由
            </p>
            <p style={{ color: COFFEE, fontSize: 12, lineHeight: 1.5 }}>{tool.use}</p>
          </div>
        </div>
      </div>

      {/* Purchase Button */}
      <div className="px-6 mt-6">
        <button
          onClick={() => window.open(tool.link, '_blank')}
          className="w-full py-4 flex items-center justify-center gap-2"
          style={{
            backgroundColor: ORANGE,
            color: WHITE,
            borderRadius: 999,
            fontSize: 15,
            fontWeight: 600,
            boxShadow: "0 8px 24px rgba(250,136,58,0.35)",
          }}
        >
          前往购买
          <ChevronRight size={18} color={WHITE} />
        </button>

        <button
          onClick={onBack}
          className="w-full py-3 mt-3"
          style={{
            backgroundColor: WHITE,
            color: COFFEE,
            borderRadius: 999,
            fontSize: 14,
            fontWeight: 600,
          }}
        >
          稍后再说
        </button>
      </div>
    </div>
  );
}

function PlanStep({ onBack, onNext }: { onBack: () => void; onNext: () => void }) {
  const [selected, setSelected] = useState("10min");

  return (
    <div className="h-full w-full">
      <div className="relative h-[55%] w-full overflow-hidden">
        <ImageWithFallback src={ROOM_IMG} alt="Room" className="h-full w-full object-cover" />
        <div
          className="absolute inset-0"
          style={{
            background:
              "linear-gradient(180deg, rgba(123,92,72,0.25) 0%, rgba(0,0,0,0) 30%, rgba(0,0,0,0) 70%, rgba(255,255,255,0.4) 100%)",
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
            className="px-4 py-2 flex items-center gap-2"
            style={{ backgroundColor: "rgba(255,255,255,0.9)", borderRadius: 999 }}
          >
            <Sparkles size={14} color={ORANGE} />
            <span style={{ color: COFFEE, fontSize: 12 }}>3 Zones Detected</span>
          </div>
        </div>

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
              borderRadius: 16,
              boxShadow: `0 0 0 4px rgba(250,136,58,0.15), 0 0 24px rgba(250,136,58,0.4)`,
              backgroundColor: "rgba(250,136,58,0.08)",
            }}
          >
            <div
              className="absolute -top-3 -left-3 h-8 w-8 rounded-full flex items-center justify-center"
              style={{
                backgroundColor: ORANGE,
                color: WHITE,
                fontSize: 13,
                fontWeight: 600,
                boxShadow: "0 4px 12px rgba(250,136,58,0.5)",
              }}
            >
              {z.n}
            </div>
            <div
              className="absolute -bottom-3 left-3 px-2 py-1"
              style={{
                backgroundColor: WHITE,
                color: COFFEE,
                fontSize: 10,
                borderRadius: 8,
                boxShadow: "0 2px 8px rgba(0,0,0,0.1)",
              }}
            >
              {z.label}
            </div>
          </div>
        ))}
      </div>

      <div
        className="absolute bottom-0 left-0 right-0 px-6 pt-6 pb-8"
        style={{
          backgroundColor: WHITE,
          borderTopLeftRadius: 32,
          borderTopRightRadius: 32,
          boxShadow: "0 -8px 30px rgba(123,92,72,0.08)",
        }}
      >
        <div className="flex items-center justify-center mb-4">
          <div className="h-1 w-10 rounded-full" style={{ backgroundColor: SOFT }} />
        </div>
        <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600, marginBottom: 14 }}>Plan Selection</p>

        <div className="grid grid-cols-3 gap-3 mb-5">
          {durations.map((d) => {
            const active = selected === d.id;
            return (
              <button
                key={d.id}
                onClick={() => setSelected(d.id)}
                className="py-3 px-2 flex flex-col items-center"
                style={{
                  backgroundColor: active ? ORANGE : LINEN,
                  color: active ? WHITE : COFFEE,
                  borderRadius: 16,
                  boxShadow: active ? "0 6px 16px rgba(250,136,58,0.3)" : "none",
                }}
              >
                <span style={{ fontSize: 15, fontWeight: 600 }}>{d.label}</span>
                <span style={{ fontSize: 10, opacity: active ? 0.9 : 0.6, marginTop: 2 }}>{d.sub}</span>
              </button>
            );
          })}
        </div>

        <div className="space-y-2 mb-5">
          {zones.map((z, i) => (
            <div
              key={z.n}
              className="flex items-center gap-3 px-4 py-3"
              style={{ backgroundColor: LINEN, borderRadius: 16 }}
            >
              <div
                className="h-7 w-7 rounded-full flex items-center justify-center"
                style={{ backgroundColor: i === 0 ? ORANGE : BLUE, color: WHITE, fontSize: 12 }}
              >
                {z.n}
              </div>
              <span style={{ color: COFFEE, fontSize: 13, flex: 1 }}>{z.label}</span>
              <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>~3 min</span>
            </div>
          ))}
        </div>

        <button
          onClick={onNext}
          className="w-full py-4"
          style={{
            backgroundColor: ORANGE,
            color: WHITE,
            borderRadius: 999,
            fontSize: 15,
            fontWeight: 600,
            boxShadow: "0 8px 24px rgba(250,136,58,0.35)",
          }}
        >
          Pick zones to tidy →
        </button>
      </div>
    </div>
  );
}

/* ---------- C. Task Progress ---------- */

function TaskStep({ onBack, onComplete }: { onBack: () => void; onComplete: () => void }) {
  const tasks = [
    "Stack books neatly",
    "Wipe coffee table",
    "Place mug in kitchen",
    "Fold throw blanket",
  ];

  return (
    <div className="h-full w-full flex flex-col" style={{ backgroundColor: LINEN }}>
      <div className="px-6 pt-14 pb-2 flex items-center justify-between">
        <button
          onClick={onBack}
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ArrowLeft size={20} color={COFFEE} />
        </button>
        <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>Cleaning Session</p>
        <div className="w-11" />
      </div>

      <div className="px-6 mt-4 flex items-center">
        {[1, 2, 3].map((n, i) => (
          <div key={n} className="flex items-center flex-1 last:flex-none">
            <div className="flex flex-col items-center">
              <div
                className="h-9 w-9 rounded-full flex items-center justify-center"
                style={{
                  backgroundColor: n === 1 ? ORANGE : SOFT,
                  color: n === 1 ? WHITE : COFFEE,
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                {n}
              </div>
              <span
                style={{
                  color: COFFEE,
                  fontSize: 10,
                  marginTop: 4,
                  opacity: n === 1 ? 1 : 0.5,
                }}
              >
                Zone {n}
              </span>
            </div>
            {i < 2 && (
              <div className="flex-1 h-[2px] mx-2 mb-4" style={{ backgroundColor: SOFT }} />
            )}
          </div>
        ))}
      </div>

      <div
        className="mx-6 mt-6 p-6"
        style={{
          backgroundColor: WHITE,
          borderRadius: 28,
          boxShadow: "0 4px 20px rgba(123,92,72,0.06)",
        }}
      >
        <div className="flex items-center justify-between mb-3">
          <span
            className="px-3 py-1"
            style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, fontSize: 11 }}
          >
            Current Zone
          </span>
          <span style={{ color: COFFEE, opacity: 0.55, fontSize: 12 }}>03:42</span>
        </div>
        <p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>Coffee Table</p>
        <p style={{ color: COFFEE, opacity: 0.6, fontSize: 12, marginTop: 4 }}>4 quick tasks</p>

        <div className="space-y-2 mt-5">
          {tasks.map((t, i) => (
            <div
              key={t}
              className="flex items-center gap-3 px-4 py-3"
              style={{ backgroundColor: LINEN, borderRadius: 14 }}
            >
              <div
                className="h-6 w-6 rounded-full flex items-center justify-center"
                style={{
                  backgroundColor: i < 2 ? ORANGE : WHITE,
                  border: i < 2 ? "none" : `2px solid ${SOFT}`,
                }}
              >
                {i < 2 && <Check size={14} color={WHITE} />}
              </div>
              <span
                style={{
                  color: COFFEE,
                  fontSize: 13,
                  textDecoration: i < 2 ? "line-through" : "none",
                  opacity: i < 2 ? 0.5 : 1,
                }}
              >
                {t}
              </span>
            </div>
          ))}
        </div>
      </div>

      <div className="mt-auto px-6 pb-8">
        <button
          onClick={onComplete}
          className="w-full py-4"
          style={{
            backgroundColor: ORANGE,
            color: WHITE,
            borderRadius: 999,
            fontSize: 15,
            fontWeight: 600,
            boxShadow: "0 8px 24px rgba(250,136,58,0.35)",
          }}
        >
          Complete Zone
        </button>
      </div>
    </div>
  );
}

/* ---------- Reward ---------- */

const AFTER_IMG =
  "https://images.unsplash.com/photo-1749705319317-f9a2bf24fe3d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080";

function RewardStep({ onClose }: { onClose: () => void }) {
  const [afterPhoto, setAfterPhoto] = useState<string | null>(null);
  const [showComparison, setShowComparison] = useState(false);
  const [slider, setSlider] = useState(50);
  const [flash, setFlash] = useState(false);

  // Camera capture view
  if (!afterPhoto) {
    return (
      <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: "#1a1411" }}>
        {/* Live camera feed */}
        <ImageWithFallback src={AFTER_IMG} alt="Camera" className="h-full w-full object-cover" />

        {/* Vignette */}
        <div
          className="absolute inset-0 pointer-events-none"
          style={{
            background:
              "radial-gradient(ellipse at center, rgba(0,0,0,0) 55%, rgba(0,0,0,0.35) 100%)",
          }}
        />

        {/* Flash overlay */}
        {flash && (
          <div
            className="absolute inset-0 pointer-events-none"
            style={{ backgroundColor: WHITE, opacity: 0.9 }}
          />
        )}

        {/* Top instruction */}
        <div className="absolute top-14 left-0 right-0 px-6">
          <div
            className="p-4 flex items-center gap-3"
            style={{
              backgroundColor: "rgba(255,255,255,0.95)",
              borderRadius: 20,
            }}
          >
            <div
              className="h-10 w-10 rounded-full flex items-center justify-center flex-shrink-0"
              style={{ backgroundColor: ORANGE }}
            >
              <Camera size={20} color={WHITE} />
            </div>
            <div className="flex-1">
              <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>拍摄完成后的照片</p>
              <p style={{ color: COFFEE, opacity: 0.6, fontSize: 11 }}>
                让我们记录你的整理成果 📸
              </p>
            </div>
          </div>
        </div>

        {/* Bottom controls */}
        <div className="absolute bottom-0 left-0 right-0 pb-10 pt-6 px-8 flex items-center justify-center">
          <button
            onClick={() => {
              setFlash(true);
              setTimeout(() => {
                setFlash(false);
                setAfterPhoto(AFTER_IMG);
              }, 220);
            }}
            className="h-20 w-20 rounded-full flex items-center justify-center"
            style={{
              backgroundColor: WHITE,
              boxShadow: "0 0 0 6px rgba(255,255,255,0.3)",
            }}
          >
            <div
              className="h-16 w-16 rounded-full"
              style={{ backgroundColor: ORANGE, boxShadow: "0 4px 20px rgba(250,136,58,0.4)" }}
            />
          </button>
        </div>
      </div>
    );
  }

  // Before/After comparison view
  if (!showComparison) {
    return (
      <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: LINEN }}>
        <div className="h-full w-full overflow-y-auto pb-10">
          {/* Top bar */}
          <div className="px-6 pt-14 pb-2">
            <span
              className="inline-block px-3 py-1"
              style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, fontSize: 10, fontWeight: 600 }}
            >
              整理完成
            </span>
          </div>

          {/* Title */}
          <div className="px-6 mt-2">
            <p style={{ color: COFFEE, fontSize: 24, fontWeight: 600 }}>对比整理前后</p>
            <p style={{ color: COFFEE, opacity: 0.6, fontSize: 13, marginTop: 4 }}>
              滑动查看你的整理成果
            </p>
          </div>

          {/* Before / After slider */}
          <div className="px-6 mt-6">
            <div className="flex items-center justify-between mb-3">
              <span style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>左右拖动对比</span>
            </div>
            <div
              className="relative w-full overflow-hidden"
              style={{
                height: 400,
                borderRadius: 24,
                backgroundColor: WHITE,
                boxShadow: "0 8px 28px rgba(123,92,72,0.12)",
              }}
            >
              {/* After image (base layer) */}
              <ImageWithFallback
                src={afterPhoto}
                alt="整理后"
                className="absolute inset-0 h-full w-full object-cover"
              />

              {/* Before image (clipped overlay) */}
              <div
                className="absolute inset-y-0 left-0 overflow-hidden"
                style={{ width: `${slider}%` }}
              >
                <ImageWithFallback
                  src={ROOM_IMG}
                  alt="整理前"
                  className="h-full object-cover"
                  style={{ width: `${(100 / slider) * 100}%`, minWidth: "100%" }}
                />
              </div>

              {/* Labels */}
              <span
                className="absolute top-4 left-4 px-3 py-1.5"
                style={{
                  backgroundColor: "rgba(123,92,72,0.9)",
                  color: WHITE,
                  borderRadius: 999,
                  fontSize: 11,
                  fontWeight: 600,
                }}
              >
                整理前
              </span>
              <span
                className="absolute top-4 right-4 px-3 py-1.5"
                style={{
                  backgroundColor: ORANGE,
                  color: WHITE,
                  borderRadius: 999,
                  fontSize: 11,
                  fontWeight: 600,
                }}
              >
                整理后
              </span>

              {/* Divider with handle */}
              <div
                className="absolute top-0 bottom-0"
                style={{
                  left: `${slider}%`,
                  width: 3,
                  backgroundColor: WHITE,
                  transform: "translateX(-50%)",
                  boxShadow: "0 0 16px rgba(0,0,0,0.3)",
                }}
              >
                <div
                  className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 h-11 w-11 rounded-full flex items-center justify-center"
                  style={{ backgroundColor: WHITE, boxShadow: "0 4px 16px rgba(0,0,0,0.25)" }}
                >
                  <MoveHorizontal size={18} color={COFFEE} />
                </div>
              </div>

              {/* Range input */}
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

          {/* Stats preview */}
          <div className="px-6 mt-6 flex gap-3">
            <div
              className="flex-1 py-3 text-center"
              style={{ backgroundColor: WHITE, borderRadius: 16, boxShadow: "0 4px 12px rgba(123,92,72,0.06)" }}
            >
              <p style={{ color: ORANGE, fontSize: 18, fontWeight: 600 }}>3</p>
              <p style={{ color: COFFEE, opacity: 0.6, fontSize: 10 }}>区域</p>
            </div>
            <div
              className="flex-1 py-3 text-center"
              style={{ backgroundColor: WHITE, borderRadius: 16, boxShadow: "0 4px 12px rgba(123,92,72,0.06)" }}
            >
              <p style={{ color: ORANGE, fontSize: 18, fontWeight: 600 }}>19</p>
              <p style={{ color: COFFEE, opacity: 0.6, fontSize: 10 }}>物品</p>
            </div>
            <div
              className="flex-1 py-3 text-center"
              style={{ backgroundColor: WHITE, borderRadius: 16, boxShadow: "0 4px 12px rgba(123,92,72,0.06)" }}
            >
              <p style={{ color: ORANGE, fontSize: 18, fontWeight: 600 }}>32</p>
              <p style={{ color: COFFEE, opacity: 0.6, fontSize: 10 }}>分钟</p>
            </div>
          </div>

          {/* Continue button */}
          <div className="px-6 mt-6">
            <button
              onClick={() => setShowComparison(true)}
              className="w-full py-4"
              style={{
                backgroundColor: ORANGE,
                color: WHITE,
                borderRadius: 999,
                fontSize: 15,
                fontWeight: 600,
                boxShadow: "0 8px 24px rgba(250,136,58,0.35)",
              }}
            >
              查看成就
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Final reward celebration view
  return (
    <div
      className="h-full w-full flex flex-col items-center justify-center px-8"
      style={{ backgroundColor: LINEN }}
    >
      <div
        className="p-8 flex flex-col items-center text-center"
        style={{
          backgroundColor: WHITE,
          borderRadius: 32,
          boxShadow: "0 20px 50px rgba(123,92,72,0.12)",
          width: "100%",
        }}
      >
        <div
          className="h-32 w-32 rounded-full flex items-center justify-center mb-5"
          style={{
            background: `radial-gradient(circle, ${LINEN} 0%, ${SOFT} 100%)`,
            boxShadow: `0 0 0 8px rgba(250,136,58,0.1)`,
          }}
        >
          <Raccoon size={104} />
        </div>
        <span
          className="px-3 py-1 mb-3"
          style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, fontSize: 11 }}
        >
          新徽章
        </span>
        <p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>整理浣熊</p>
        <p style={{ color: COFFEE, opacity: 0.6, fontSize: 13, marginTop: 6 }}>
          全部3个区域已整理 — 你的空间焕然一新 ✨
        </p>

        <div className="flex gap-3 mt-5 w-full">
          <div
            className="flex-1 py-3 text-center"
            style={{ backgroundColor: LINEN, borderRadius: 16 }}
          >
            <p style={{ color: ORANGE, fontSize: 18, fontWeight: 600 }}>3</p>
            <p style={{ color: COFFEE, opacity: 0.6, fontSize: 10 }}>区域</p>
          </div>
          <div
            className="flex-1 py-3 text-center"
            style={{ backgroundColor: LINEN, borderRadius: 16 }}
          >
            <p style={{ color: ORANGE, fontSize: 18, fontWeight: 600 }}>19</p>
            <p style={{ color: COFFEE, opacity: 0.6, fontSize: 10 }}>物品</p>
          </div>
          <div
            className="flex-1 py-3 text-center"
            style={{ backgroundColor: LINEN, borderRadius: 16 }}
          >
            <p style={{ color: ORANGE, fontSize: 18, fontWeight: 600 }}>+150</p>
            <p style={{ color: COFFEE, opacity: 0.6, fontSize: 10 }}>经验值</p>
          </div>
        </div>

        <button
          onClick={onClose}
          className="w-full py-4 mt-6"
          style={{
            backgroundColor: ORANGE,
            color: WHITE,
            borderRadius: 999,
            fontSize: 15,
            fontWeight: 600,
            boxShadow: "0 8px 24px rgba(250,136,58,0.35)",
          }}
        >
          返回空间
        </button>
      </div>
    </div>
  );
}

/* ---------- D. Zone Selection ---------- */

const SELECTABLE_ZONES = [
  { n: 1, label: "Coffee Table", color: ORANGE, left: "10%", top: "44%", w: "34%", h: "26%", items: 6, mins: 4 },
  { n: 2, label: "Sofa Area", color: BLUE, left: "44%", top: "30%", w: "40%", h: "42%", items: 9, mins: 7 },
  { n: 3, label: "Shelf Corner", color: "#A88370", left: "6%", top: "8%", w: "30%", h: "26%", items: 4, mins: 3 },
];

function ZoneSelectStep({ onBack, onNext }: { onBack: () => void; onNext: () => void }) {
  const [selected, setSelected] = useState<number[]>([1, 2]);

  const toggle = (n: number) =>
    setSelected((arr) => (arr.includes(n) ? arr.filter((x) => x !== n) : [...arr, n]));
  const selectAll = () => setSelected(SELECTABLE_ZONES.map((z) => z.n));
  const clearAll = () => setSelected([]);
  const totalItems = SELECTABLE_ZONES.filter((z) => selected.includes(z.n)).reduce((s, z) => s + z.items, 0);
  const totalMins = SELECTABLE_ZONES.filter((z) => selected.includes(z.n)).reduce((s, z) => s + z.mins, 0);

  return (
    <div className="h-full w-full flex flex-col" style={{ backgroundColor: LINEN }}>
      <div className="px-5 pt-14 pb-2 flex items-center justify-between">
        <button
          onClick={onBack}
          className="h-10 w-10 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ArrowLeft size={18} color={COFFEE} />
        </button>
        <div className="text-center">
          <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>Select Zones</p>
          <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>Multi-select supported</p>
        </div>
        <div className="w-10" />
      </div>

      {/* Photo with zone overlays */}
      <div className="mx-5 mt-3 relative overflow-hidden" style={{ borderRadius: 22, aspectRatio: "3/4" }}>
        <ImageWithFallback src={ROOM_IMG} alt="Scene" className="h-full w-full object-cover" />
        <div className="absolute inset-0" style={{ backgroundColor: "rgba(26,20,17,0.18)" }} />

        {SELECTABLE_ZONES.map((z) => {
          const isSel = selected.includes(z.n);
          return (
            <button
              key={z.n}
              onClick={() => toggle(z.n)}
              className="absolute flex items-start justify-between p-2"
              style={{
                left: z.left,
                top: z.top,
                width: z.w,
                height: z.h,
                border: `2px solid ${z.color}`,
                backgroundColor: isSel ? `${z.color}55` : `${z.color}1f`,
                borderRadius: 14,
                boxShadow: isSel ? `0 0 0 4px ${z.color}33, 0 0 24px ${z.color}55` : "none",
                transition: "all 0.18s",
              }}
            >
              <div
                className="h-7 w-7 rounded-full flex items-center justify-center"
                style={{
                  backgroundColor: z.color,
                  color: WHITE,
                  fontSize: 12,
                  fontWeight: 700,
                  boxShadow: "0 3px 10px rgba(0,0,0,0.25)",
                }}
              >
                {z.n}
              </div>
              <div
                className="h-6 w-6 rounded-full flex items-center justify-center"
                style={{
                  backgroundColor: isSel ? z.color : "rgba(255,255,255,0.92)",
                  border: isSel ? "none" : `2px solid ${WHITE}`,
                }}
              >
                {isSel && <Check size={13} color={WHITE} strokeWidth={3} />}
              </div>
            </button>
          );
        })}
      </div>

      {/* Zone summary list */}
      <div className="px-5 mt-4 space-y-2">
        {SELECTABLE_ZONES.map((z) => {
          const isSel = selected.includes(z.n);
          return (
            <button
              key={z.n}
              onClick={() => toggle(z.n)}
              className="w-full flex items-center gap-3 px-3 py-2.5"
              style={{
                backgroundColor: WHITE,
                borderRadius: 14,
                border: isSel ? `1.5px solid ${z.color}` : `1.5px solid transparent`,
                opacity: isSel ? 1 : 0.6,
              }}
            >
              <div
                className="h-7 w-7 rounded-full flex items-center justify-center"
                style={{ backgroundColor: z.color, color: WHITE, fontSize: 12, fontWeight: 600 }}
              >
                {z.n}
              </div>
              <span style={{ color: COFFEE, fontSize: 12, fontWeight: 600, flex: 1, textAlign: "left" }}>
                {z.label}
              </span>
              <span style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>
                {z.items} items · {z.mins}m
              </span>
              <div
                className="h-5 w-5 rounded-full flex items-center justify-center"
                style={{ backgroundColor: isSel ? z.color : LINEN }}
              >
                {isSel && <Check size={11} color={WHITE} strokeWidth={3} />}
              </div>
            </button>
          );
        })}
      </div>

      {/* Bottom action bar */}
      <div
        className="mt-auto px-5 pt-3 pb-6"
        style={{ backgroundColor: WHITE, borderTop: `1px solid ${SOFT}` }}
      >
        {selected.length > 0 && (
          <p style={{ color: COFFEE, opacity: 0.65, fontSize: 11, marginBottom: 8, textAlign: "center" }}>
            {selected.length} zones · {totalItems} items · ~{totalMins} min
          </p>
        )}
        <div className="flex gap-2">
          <button
            onClick={selectAll}
            className="flex-1 py-3"
            style={{
              backgroundColor: WHITE,
              color: COFFEE,
              border: `1.5px solid ${SOFT}`,
              borderRadius: 999,
              fontSize: 12,
              fontWeight: 600,
            }}
          >
            Select all
          </button>
          <button
            onClick={clearAll}
            className="flex-1 py-3"
            style={{
              backgroundColor: WHITE,
              color: COFFEE,
              border: `1.5px solid ${SOFT}`,
              borderRadius: 999,
              fontSize: 12,
              fontWeight: 600,
            }}
          >
            Clear
          </button>
          <button
            onClick={onNext}
            disabled={selected.length === 0}
            className="flex-[1.4] py-3"
            style={{
              backgroundColor: selected.length > 0 ? ORANGE : SOFT,
              color: WHITE,
              borderRadius: 999,
              fontSize: 13,
              fontWeight: 600,
              boxShadow: selected.length > 0 ? "0 6px 18px rgba(250,136,58,0.32)" : "none",
              opacity: selected.length > 0 ? 1 : 0.6,
            }}
          >
            Start →
          </button>
        </div>
      </div>
    </div>
  );
}

/* ---------- E. AR 3D Preview ---------- */

const AR_ARROWS = [
  { from: "30%,55%", to: "12%,72%", label: "Charger cable" },
  { from: "55%,40%", to: "78%,30%", label: "Mug" },
  { from: "45%,68%", to: "22%,82%", label: "Books" },
];

function ARPreviewStep({ onBack, onNext }: { onBack: () => void; onNext: () => void }) {
  const [demo, setDemo] = useState(false);
  const [warn, setWarn] = useState(true);
  const arSupported = true; // toggle for demo

  return (
    <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: "#13110f" }}>
      {/* 3D mesh background */}
      <div className="absolute inset-0">
        <ImageWithFallback src={ROOM_IMG} alt="Scene" className="h-full w-full object-cover" />
        <div
          className="absolute inset-0"
          style={{
            background:
              "linear-gradient(180deg, rgba(19,17,15,0.55) 0%, rgba(19,17,15,0.15) 40%, rgba(19,17,15,0.7) 100%)",
          }}
        />
        {/* mesh grid */}
        <svg className="absolute inset-0 w-full h-full opacity-25" preserveAspectRatio="none">
          <defs>
            <pattern id="mesh" width="32" height="32" patternUnits="userSpaceOnUse">
              <path d="M 32 0 L 0 0 0 32" fill="none" stroke={BLUE} strokeWidth="0.6" />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#mesh)" />
        </svg>
      </div>

      {/* Top bar */}
      <div className="absolute top-0 left-0 right-0 px-5 pt-14 pb-3 flex items-center justify-between z-20">
        <button
          onClick={onBack}
          className="h-10 w-10 rounded-full flex items-center justify-center"
          style={{ backgroundColor: "rgba(255,255,255,0.92)" }}
        >
          <ArrowLeft size={18} color={COFFEE} />
        </button>
        <div
          className="px-3.5 py-2 flex items-center gap-2"
          style={{ backgroundColor: "rgba(255,255,255,0.92)", borderRadius: 999 }}
        >
          <Box size={13} color={ORANGE} />
          <span style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>
            {demo ? "AR Live" : "3D Preview"}
          </span>
        </div>
        <button
          onClick={() => setDemo((d) => !d)}
          className="h-10 px-3 rounded-full flex items-center gap-1.5"
          style={{ backgroundColor: demo ? ORANGE : "rgba(255,255,255,0.92)" }}
        >
          <Move3d size={14} color={demo ? WHITE : COFFEE} />
          <span style={{ color: demo ? WHITE : COFFEE, fontSize: 11, fontWeight: 600 }}>
            {demo ? "Close" : "AR"}
          </span>
        </button>
      </div>

      {/* Unsupported notice */}
      {!arSupported && (
        <div
          className="absolute top-28 left-5 right-5 px-3 py-2 z-20"
          style={{ backgroundColor: "rgba(250,136,58,0.92)", borderRadius: 12 }}
        >
          <p style={{ color: WHITE, fontSize: 11, fontWeight: 500 }}>
            AR live unavailable on this device — rotate the 3D model instead.
          </p>
        </div>
      )}

      {/* Zone slabs */}
      {SELECTABLE_ZONES.slice(0, 2).map((z) => (
        <div
          key={z.n}
          className="absolute"
          style={{
            left: z.left,
            top: z.top,
            width: z.w,
            height: z.h,
            border: `2px solid ${z.color}`,
            backgroundColor: `${z.color}33`,
            borderRadius: 14,
            boxShadow: `0 0 30px ${z.color}66`,
            transform: "perspective(800px) rotateX(8deg)",
          }}
        >
          <div
            className="absolute -top-3 -left-3 h-7 w-7 rounded-full flex items-center justify-center"
            style={{ backgroundColor: z.color, color: WHITE, fontSize: 12, fontWeight: 700 }}
          >
            {z.n}
          </div>
        </div>
      ))}

      {/* Item ghost outlines + arrows */}
      <svg className="absolute inset-0 w-full h-full z-10 pointer-events-none">
        <defs>
          <marker id="arrow" markerWidth="6" markerHeight="6" refX="5" refY="3" orient="auto">
            <polygon points="0 0, 6 3, 0 6" fill={ORANGE} />
          </marker>
        </defs>
        {AR_ARROWS.map((a, i) => {
          const [fx, fy] = a.from.split(",");
          const [tx, ty] = a.to.split(",");
          return (
            <line
              key={i}
              x1={fx}
              y1={fy}
              x2={tx}
              y2={ty}
              stroke={ORANGE}
              strokeWidth="2"
              strokeDasharray="5 4"
              markerEnd="url(#arrow)"
              opacity="0.85"
            />
          );
        })}
      </svg>

      {AR_ARROWS.map((a, i) => {
        const [tx, ty] = a.to.split(",");
        return (
          <div
            key={i}
            className="absolute px-2 py-0.5"
            style={{
              left: tx,
              top: ty,
              backgroundColor: "rgba(255,255,255,0.92)",
              borderRadius: 8,
              fontSize: 9,
              fontWeight: 600,
              color: COFFEE,
              transform: "translate(-50%, 4px)",
            }}
          >
            {a.label}
          </div>
        );
      })}

      {/* Conflict warning during AR demo */}
      {demo && warn && (
        <div
          className="absolute left-5 right-5 px-4 py-3 z-20 flex items-start gap-2"
          style={{
            top: 110,
            backgroundColor: "rgba(255,255,255,0.96)",
            borderRadius: 14,
            border: `1px solid ${ORANGE}`,
            boxShadow: "0 8px 24px rgba(0,0,0,0.25)",
          }}
        >
          <AlertTriangle size={14} color={ORANGE} style={{ marginTop: 2 }} />
          <div className="flex-1">
            <p style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>Space conflict detected</p>
            <p style={{ color: COFFEE, opacity: 0.65, fontSize: 11, marginTop: 2 }}>
              Some items don't fit — adjust the real area or revise the plan.
            </p>
          </div>
          <button
            onClick={() => {
              setWarn(false);
              setDemo(false);
            }}
            style={{ color: ORANGE, fontSize: 11, fontWeight: 600 }}
          >
            Revise
          </button>
        </div>
      )}

      {/* Bottom glass dock */}
      <div
        className="absolute bottom-6 left-5 right-5 px-2 py-2 flex items-center gap-2 z-20"
        style={{
          backgroundColor: "rgba(255,255,255,0.18)",
          backdropFilter: "blur(18px)",
          WebkitBackdropFilter: "blur(18px)",
          border: "1px solid rgba(255,255,255,0.25)",
          borderRadius: 999,
        }}
      >
        <button
          onClick={() => setDemo(true)}
          className="flex-1 py-2.5 flex items-center justify-center gap-1.5"
          style={{
            backgroundColor: "rgba(255,255,255,0.18)",
            color: WHITE,
            borderRadius: 999,
            fontSize: 11,
            fontWeight: 600,
          }}
        >
          <Camera size={13} /> AR Demo
        </button>
        <button
          onClick={onBack}
          className="flex-1 py-2.5 flex items-center justify-center gap-1.5"
          style={{
            backgroundColor: "rgba(255,255,255,0.18)",
            color: WHITE,
            borderRadius: 999,
            fontSize: 11,
            fontWeight: 600,
          }}
        >
          Revise
        </button>
        <button
          onClick={onNext}
          className="flex-1 py-2.5 flex items-center justify-center gap-1.5"
          style={{
            backgroundColor: ORANGE,
            color: WHITE,
            borderRadius: 999,
            fontSize: 12,
            fontWeight: 600,
            boxShadow: "0 6px 16px rgba(250,136,58,0.4)",
          }}
        >
          Start →
        </button>
      </div>

      {/* Gesture hint */}
      <div
        className="absolute bottom-20 left-1/2 -translate-x-1/2 px-3 py-1 z-10"
        style={{
          backgroundColor: "rgba(19,17,15,0.55)",
          borderRadius: 999,
          fontSize: 10,
          color: "rgba(255,255,255,0.85)",
        }}
      >
        Drag · Pinch · 2-finger pan
      </div>
    </div>
  );
}

/* ---------- F. AR Linear Guidance ---------- */

type SubTask = { id: string; text: string; done?: boolean; skipped?: boolean };

const AR_ZONE_TASKS: { zone: number; label: string; color: string; tasks: SubTask[] }[] = [
  {
    zone: 1,
    label: "Coffee Table",
    color: ORANGE,
    tasks: [
      { id: "z1t1", text: "Coil the charger cable into the blue storage box" },
      { id: "z1t2", text: "Move the mug to the kitchen counter" },
      { id: "z1t3", text: "Stack the books vertically on the right side" },
      { id: "z1t4", text: "Wipe the surface with a microfiber cloth" },
    ],
  },
  {
    zone: 2,
    label: "Sofa Area",
    color: BLUE,
    tasks: [
      { id: "z2t1", text: "Fold the throw blanket on the sofa arm" },
      { id: "z2t2", text: "Fluff and align the cushions" },
      { id: "z2t3", text: "Tuck the remote into the side basket" },
    ],
  },
  {
    zone: 3,
    label: "Shelf Corner",
    color: "#A88370",
    tasks: [
      { id: "z3t1", text: "Group books by height on the top shelf" },
      { id: "z3t2", text: "Wipe down the decorative bowl" },
      { id: "z3t3", text: "Move the lamp cable behind the shelf" },
    ],
  },
];

function ARGuideStep({
  tier = "smart",
  onBack,
  onComplete,
}: {
  tier?: PlanTier;
  onBack: () => void;
  onComplete: () => void;
}) {
  const [zoneIdx, setZoneIdx] = useState(0);
  const [tasks, setTasks] = useState<SubTask[]>(AR_ZONE_TASKS[0].tasks);
  const [zoneTransition, setZoneTransition] = useState(false);
  const totalZones = AR_ZONE_TASKS.length;
  const zoneInfo = AR_ZONE_TASKS[zoneIdx];
  const [compare, setCompare] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [skipping, setSkipping] = useState(false);
  const [longPress, setLongPress] = useState(false);
  const longPressTimer = useRef<any>(null);

  const currentIdx = tasks.findIndex((t) => !t.done && !t.skipped);
  const current = tasks[currentIdx];
  const doneCount = tasks.filter((t) => t.done).length;
  const total = tasks.length;
  const progress = (doneCount / total) * 100;

  const complete = () => {
    if (!current) return;
    const updated = tasks.map((t) => (t.id === current.id ? { ...t, done: true } : t));
    setTasks(updated);
    const all完成InZone = updated.every((t) => t.done || t.skipped);
    if (all完成InZone) {
      if (zoneIdx + 1 < totalZones) {
        setZoneTransition(true);
        setTimeout(() => {
          setZoneIdx((i) => i + 1);
          setTasks(AR_ZONE_TASKS[zoneIdx + 1].tasks);
          setZoneTransition(false);
        }, 1400);
      } else {
        setTimeout(onComplete, 500);
      }
    }
  };

  const skipReason = (reason: string) => {
    if (!current) return;
    setTasks((arr) => arr.map((t) => (t.id === current.id ? { ...t, skipped: true } : t)));
    setSkipping(false);
  };

  const toggleTask = (id: string) =>
    setTasks((arr) =>
      arr.map((t) => (t.id === id ? { ...t, done: !t.done, skipped: false } : t)),
    );

  const onPressStart = () => {
    longPressTimer.current = setTimeout(() => setLongPress(true), 350);
  };
  const onPressEnd = () => {
    clearTimeout(longPressTimer.current);
    setLongPress(false);
  };

  return (
    <div className="h-full w-full flex flex-col" style={{ backgroundColor: "#13110f" }}>
      {/* Upper 70% — camera + AR overlay */}
      <div
        className="relative flex-1 overflow-hidden"
        onMouseDown={onPressStart}
        onMouseUp={onPressEnd}
        onMouseLeave={onPressEnd}
        onTouchStart={onPressStart}
        onTouchEnd={onPressEnd}
      >
        {compare ? (
          <div className="flex h-full w-full">
            <div className="flex-1 relative overflow-hidden border-r" style={{ borderColor: "rgba(255,255,255,0.2)" }}>
              <ImageWithFallback src={ROOM_IMG} alt="Before" className="h-full w-full object-cover" />
              <span
                className="absolute top-20 left-3 px-2 py-0.5"
                style={{ backgroundColor: "rgba(0,0,0,0.55)", color: WHITE, borderRadius: 6, fontSize: 10, fontWeight: 600 }}
              >
                BEFORE
              </span>
            </div>
            <div className="flex-1 relative overflow-hidden">
              <ImageWithFallback src={ROOM_IMG} alt="Target" className="h-full w-full object-cover" />
              <div className="absolute inset-0" style={{ backgroundColor: "rgba(250,136,58,0.18)" }} />
              <span
                className="absolute top-20 left-3 px-2 py-0.5"
                style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 6, fontSize: 10, fontWeight: 600 }}
              >
                TARGET
              </span>
            </div>
          </div>
        ) : (
          <>
            <ImageWithFallback src={ROOM_IMG} alt="Live" className="h-full w-full object-cover" />
            {!longPress && (
              <>
                {/* Highlight slab */}
                <div
                  className="absolute"
                  style={{
                    left: "18%",
                    top: "42%",
                    width: "44%",
                    height: "32%",
                    border: `2px solid ${ORANGE}`,
                    backgroundColor: "rgba(250,136,58,0.22)",
                    borderRadius: 14,
                    boxShadow: "0 0 30px rgba(250,136,58,0.5)",
                  }}
                />
                {/* Animated arrow */}
                <svg className="absolute inset-0 w-full h-full pointer-events-none">
                  <defs>
                    <marker id="arrow2" markerWidth="6" markerHeight="6" refX="5" refY="3" orient="auto">
                      <polygon points="0 0, 6 3, 0 6" fill={ORANGE} />
                    </marker>
                  </defs>
                  <line
                    x1="62%"
                    y1="50%"
                    x2="22%"
                    y2="74%"
                    stroke={ORANGE}
                    strokeWidth="3"
                    strokeDasharray="6 4"
                    markerEnd="url(#arrow2)"
                  />
                </svg>
                {/* Ghost outline target */}
                <div
                  className="absolute flex items-center justify-center"
                  style={{
                    left: "14%",
                    top: "68%",
                    width: 70,
                    height: 50,
                    border: `2px dashed ${BLUE}`,
                    backgroundColor: "rgba(180,199,220,0.18)",
                    borderRadius: 10,
                  }}
                >
                  <span style={{ color: WHITE, fontSize: 10, fontWeight: 600, textShadow: "0 1px 2px rgba(0,0,0,0.7)" }}>
                    Box
                  </span>
                </div>
              </>
            )}
            {longPress && (
              <div
                className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 px-3 py-1.5"
                style={{ backgroundColor: "rgba(0,0,0,0.55)", borderRadius: 999 }}
              >
                <span style={{ color: WHITE, fontSize: 11 }}>Showing original — release to resume</span>
              </div>
            )}
          </>
        )}

        {/* Top bar */}
        <div className="absolute top-0 left-0 right-0 px-5 pt-14 flex items-center justify-between">
          <button
            onClick={onBack}
            className="h-10 w-10 rounded-full flex items-center justify-center"
            style={{ backgroundColor: "rgba(255,255,255,0.92)" }}
          >
            <ArrowLeft size={18} color={COFFEE} />
          </button>
          <div
            className="px-3.5 py-2 flex items-center gap-2"
            style={{ backgroundColor: "rgba(255,255,255,0.92)", borderRadius: 999 }}
          >
            <Sparkles size={13} color={ORANGE} />
            <span style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>
              Zone {zoneInfo.zone}/{totalZones} · {Math.min(doneCount + 1, total)}/{total}
            </span>
          </div>
          <div className="w-10" />
        </div>
      </div>

      {/* Lower 30% — glass instruction card */}
      <div
        className="relative px-5 pt-3 pb-6"
        style={{
          backgroundColor: "rgba(255,255,255,0.92)",
          backdropFilter: "blur(20px)",
          WebkitBackdropFilter: "blur(20px)",
          borderTopLeftRadius: 26,
          borderTopRightRadius: 26,
          minHeight: expanded ? "62%" : "32%",
          transition: "min-height 0.25s",
          overflowY: "auto",
        }}
      >
        <button
          onClick={() => setExpanded((e) => !e)}
          className="w-full flex items-center justify-center mb-2"
        >
          <ChevronUp
            size={20}
            color={COFFEE}
            style={{ opacity: 0.5, transform: expanded ? "rotate(180deg)" : "none", transition: "transform 0.2s" }}
          />
        </button>

        {/* Progress */}
        <div className="flex items-center gap-2 mb-2">
          <span style={{ color: COFFEE, opacity: 0.6, fontSize: 11, fontWeight: 600 }}>
            {zoneInfo.label} · Step {Math.min(doneCount + 1, total)}/{total}
          </span>
          <div className="flex-1 h-1.5 rounded-full overflow-hidden" style={{ backgroundColor: LINEN }}>
            <div
              className="h-full rounded-full"
              style={{
                width: `${progress}%`,
                background: `linear-gradient(90deg, ${ORANGE} 0%, #FFAA66 100%)`,
                transition: "width 0.3s",
              }}
            />
          </div>
        </div>

        {!expanded ? (
          <>
            <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600, lineHeight: 1.4, marginBottom: 14 }}>
              {current?.text || "All steps complete!"}
            </p>

            <div className="flex gap-2">
              <button
                onClick={() => setCompare((c) => !c)}
                className="flex-1 py-2.5 flex items-center justify-center gap-1.5"
                style={{
                  backgroundColor: compare ? COFFEE : LINEN,
                  color: compare ? WHITE : COFFEE,
                  borderRadius: 999,
                  fontSize: 11,
                  fontWeight: 600,
                }}
              >
                <GitCompare size={13} /> Compare
              </button>
              <button
                onClick={() => setSkipping(true)}
                className="flex-1 py-2.5 flex items-center justify-center gap-1.5"
                style={{
                  backgroundColor: LINEN,
                  color: COFFEE,
                  borderRadius: 999,
                  fontSize: 11,
                  fontWeight: 600,
                }}
              >
                <SkipForward size={13} /> Skip
              </button>
              <button
                onClick={complete}
                className="flex-[1.4] py-2.5 flex items-center justify-center gap-1.5"
                style={{
                  backgroundColor: "#5fb37e",
                  color: WHITE,
                  borderRadius: 999,
                  fontSize: 12,
                  fontWeight: 700,
                  boxShadow: "0 6px 16px rgba(95,179,126,0.35)",
                }}
              >
                <CheckCircle2 size={14} /> 完成
              </button>
            </div>

            <p
              className="text-center mt-3"
              style={{ color: COFFEE, opacity: 0.45, fontSize: 10 }}
            >
              Tap & hold the camera to peek the original
            </p>
          </>
        ) : (
          <div className="space-y-2 pb-4">
            <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600, marginBottom: 4 }}>
              All subtasks · {doneCount}/{total}
            </p>
            {tasks.map((t, i) => (
              <button
                key={t.id}
                onClick={() => toggleTask(t.id)}
                className="w-full flex items-center gap-3 px-3 py-2.5"
                style={{
                  backgroundColor: t.skipped ? "transparent" : LINEN,
                  border: t.skipped ? `1px dashed ${SOFT}` : "none",
                  borderRadius: 14,
                  opacity: t.skipped ? 0.5 : 1,
                }}
              >
                <div
                  className="h-6 w-6 rounded-full flex items-center justify-center"
                  style={{
                    backgroundColor: t.done ? "#5fb37e" : WHITE,
                    border: t.done ? "none" : `2px solid ${SOFT}`,
                  }}
                >
                  {t.done && <Check size={13} color={WHITE} strokeWidth={3} />}
                </div>
                <span
                  className="flex-1 text-left"
                  style={{
                    color: COFFEE,
                    fontSize: 12.5,
                    textDecoration: t.done ? "line-through" : "none",
                    opacity: t.done ? 0.55 : 1,
                  }}
                >
                  {i + 1}. {t.text}
                </span>
                {t.skipped && (
                  <span style={{ color: COFFEE, opacity: 0.5, fontSize: 10 }}>skipped</span>
                )}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Zone transition splash */}
      {zoneTransition && (
        <div
          className="absolute inset-0 z-50 flex flex-col items-center justify-center px-8"
          style={{ backgroundColor: "rgba(19,17,15,0.85)", backdropFilter: "blur(10px)" }}
        >
          <div
            className="h-16 w-16 rounded-full flex items-center justify-center mb-4"
            style={{ backgroundColor: "#5fb37e", boxShadow: "0 8px 24px rgba(95,179,126,0.4)" }}
          >
            <Check size={28} color={WHITE} strokeWidth={3} />
          </div>
          <p style={{ color: WHITE, fontSize: 18, fontWeight: 700 }}>Zone {zoneIdx + 1} complete!</p>
          <p style={{ color: WHITE, opacity: 0.75, fontSize: 13, marginTop: 6, textAlign: "center" }}>
            Heading to {AR_ZONE_TASKS[zoneIdx + 1]?.label}…
          </p>
        </div>
      )}

      {/* Skip sheet */}
      {skipping && (
        <div
          className="absolute inset-0 z-40 flex items-end"
          style={{ backgroundColor: "rgba(26,20,17,0.45)" }}
          onClick={() => setSkipping(false)}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="w-full px-5 pt-5 pb-8"
            style={{
              backgroundColor: WHITE,
              borderTopLeftRadius: 26,
              borderTopRightRadius: 26,
            }}
          >
            <div className="flex items-center justify-center mb-3">
              <div className="h-1 w-10 rounded-full" style={{ backgroundColor: SOFT }} />
            </div>
            <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600, marginBottom: 4 }}>
              Why skip?
            </p>
            <p style={{ color: COFFEE, opacity: 0.55, fontSize: 12, marginBottom: 14 }}>
              We'll remember this for next time.
            </p>
            {["Item missing", "Don't want to tidy", "Maybe later"].map((r) => (
              <button
                key={r}
                onClick={() => skipReason(r)}
                className="w-full text-left px-4 py-3 mb-2"
                style={{ backgroundColor: LINEN, borderRadius: 14, color: COFFEE, fontSize: 13 }}
              >
                {r}
              </button>
            ))}
            <button
              onClick={() => setSkipping(false)}
              className="w-full py-3 mt-1"
              style={{ backgroundColor: WHITE, border: `1px solid ${SOFT}`, color: COFFEE, borderRadius: 999, fontSize: 13, fontWeight: 500 }}
            >
              取消
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function CornerBracket({ pos }: { pos: "tl" | "tr" | "bl" | "br" }) {
  const top = pos.startsWith("t");
  const left = pos.endsWith("l");
  const border = "2px solid rgba(255,255,255,0.85)";
  return (
    <div
      className="absolute"
      style={{
        top: top ? 0 : undefined,
        bottom: !top ? 0 : undefined,
        left: left ? 0 : undefined,
        right: !left ? 0 : undefined,
        width: 26,
        height: 26,
        borderTop: top ? border : undefined,
        borderBottom: !top ? border : undefined,
        borderLeft: left ? border : undefined,
        borderRight: !left ? border : undefined,
        borderRadius:
          pos === "tl" ? "8px 0 0 0"
          : pos === "tr" ? "0 8px 0 0"
          : pos === "bl" ? "0 0 0 8px"
          : "0 0 8px 0",
      }}
    />
  );
}
