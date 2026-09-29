import { useRef, useState, useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Plus, Sparkles, X, RotateCw, Pencil, ChevronRight, Play, Check, Camera, TriangleAlert } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { InProgressDetail } from "./InProgressDetail";
import { nativeRequest, type NativeSpace } from "../nativeBridge";
import bedArt from "../../assets/spaces/bed.png";
import deskArt from "../../assets/spaces/desk.png";
import kitchenArt from "../../assets/spaces/kitchen.png";
import teatableArt from "../../assets/spaces/teatable.png";

/* ------------------------------------------------------------------ *
 *  Space card artwork — hand-drawn room illustrations, one per kind.
 *  Card size keeps each artwork's aspect ratio; scale multiplies it.
 * ------------------------------------------------------------------ */
type SkinKey = "bed" | "desk" | "kitchen" | "teatable";

const SKINS: Record<SkinKey, { src: string; w: number; h: number }> = {
  bed: { src: bedArt, w: 138, h: 138 },
  desk: { src: deskArt, w: 143, h: 78 },
  kitchen: { src: kitchenArt, w: 138, h: 138 },
  teatable: { src: teatableArt, w: 139, h: 74 },
};

// curated, airy "premium" palette the user can recolour spaces with
const PALETTE = ["#E29B7B", "#7FB0AA", "#A9B486", "#DFA6B0", "#ECC079", "#A6B2D6", "#C3AAD4", "#9DBBC9"];

/* ------------------------------------------------------------------ *
 *  Colour + texture. Fresh = saturated riso wash; time washes it out
 *  toward a pale, quiet paper-grey (Bright → Muted → Faded → Grey).
 * ------------------------------------------------------------------ */
const GREY = "#C7C0B4";
const PAPER = "#F6F1E8";

// riso / watercolour grain — one tileable matte noise
const GRAIN =
  "data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20width='160'%20height='160'%3E%3Cfilter%20id='n'%3E%3CfeTurbulence%20type='fractalNoise'%20baseFrequency='0.85'%20numOctaves='2'%20stitchTiles='stitch'/%3E%3CfeColorMatrix%20type='saturate'%20values='0'/%3E%3C/filter%3E%3Crect%20width='100%25'%20height='100%25'%20filter='url(%23n)'/%3E%3C/svg%3E";

function toRgb(c: string): [number, number, number] {
  if (!c) return [199, 192, 180];
  if (c[0] === "#") {
    return [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16)];
  }
  const m = c.match(/\d+/g);
  if (m && m.length >= 3) return [Number(m[0]), Number(m[1]), Number(m[2])];
  return [199, 192, 180];
}
function mix(a: string, b: string, t: number) {
  const A = toRgb(a);
  const B = toRgb(b);
  const c = A.map((v, i) => Math.round(v + (B[i] - v) * t));
  return `rgb(${c[0]}, ${c[1]}, ${c[2]})`;
}
function rgba(c: string, a: number) {
  const [r, g, b] = toRgb(c);
  return `rgba(${r}, ${g}, ${b}, ${a})`;
}
// 两段式（照设计稿）：14 天内卡片保持鲜亮，14 天起开始变灰，42 天灰透。
// 7~14 天只挂橙色徽章预警，卡片本体不动。
function fade(days: number) {
  if (days < 14) return 0;
  const t = Math.min((days - 14) / 28, 1);
  // 一到 14 天就明显暗下来（0.62），之后 42 天灰透（0.96）
  return 0.62 + 0.34 * Math.pow(t, 0.72);
}

/* ------------------------------------------------------------------ *
 *  Data model
 * ------------------------------------------------------------------ */
type Piece = {
  id: string;
  name: string;
  vivid: string;
  skin: SkinKey;
  items: number;
  lastDays: number;
  x: number;
  y: number;
  rot: number;
  scale: number;
};

// 初始摆位照设计稿 Group 433：床左上、桌面右上、茶几右中、厨房左下（画板 358×408，组稿 282×276 居中偏移 ≈38,60）
const initialPieces: Piece[] = [
  { id: "p1", name: "床", vivid: "#A6B2D6", skin: "bed", items: 24, lastDays: 2, x: 40, y: 60, rot: 0, scale: 1 },
  { id: "p2", name: "桌面", vivid: "#ECC079", skin: "desk", items: 18, lastDays: 8, x: 178, y: 60, rot: 0, scale: 1 },
  { id: "p3", name: "厨房", vivid: "#A9B486", skin: "kitchen", items: 9, lastDays: 5, x: 40, y: 194, rot: 0, scale: 1 },
  { id: "p4", name: "茶几", vivid: "#DFA6B0", skin: "teatable", items: 31, lastDays: 15, x: 178, y: 144, rot: 0, scale: 1 },
];

const NEW_TEMPLATES: { name: string; vivid: string; skin: SkinKey }[] = [
  { name: "厨房", vivid: "#A9B486", skin: "kitchen" },
  { name: "衣柜", vivid: "#C3AAD4", skin: "bed" },
  { name: "玄关", vivid: "#9DBBC9", skin: "teatable" },
  { name: "工作角落", vivid: "#E29B7B", skin: "desk" },
  { name: "储物间", vivid: "#A6B2D6", skin: "desk" },
];

const LONG_PRESS = 420;

function effSize(p: Piece) {
  const s = SKINS[p.skin];
  return { w: s.w * p.scale, h: s.h * p.scale };
}

/* ------------------------------------------------------------------ *
 *  One space tile — matte painted collage piece, draggable.
 * ------------------------------------------------------------------ */
function SpaceTile({
  piece,
  boardRef,
  editing,
  onOpen,
  onMove,
  onResize,
  onEnterEdit,
  onDelete,
  born,
  relit,
}: {
  piece: Piece;
  boardRef: React.RefObject<HTMLDivElement | null>;
  editing: boolean;
  onOpen: () => void;
  onMove: (x: number, y: number) => void;
  onResize: (scale: number) => void;
  onEnterEdit: () => void;
  onDelete: () => void;
  born: boolean;
  relit?: boolean;
}) {
  const dragging = useRef(false);
  const moved = useRef(false);
  const start = useRef({ px: 0, py: 0, x: 0, y: 0 });
  const pressTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const resizing = useRef(false);
  const rStart = useRef({ px: 0, py: 0, s: 1 });

  const { w, h } = effSize(piece);

  const f = fade(piece.lastDays);

  // urgency → faintness; fresh reads full & textured, stale washes out
  const tileOpacity = 1 - f * 0.4;

  function clearPress() {
    if (pressTimer.current) {
      clearTimeout(pressTimer.current);
      pressTimer.current = null;
    }
  }
  function down(ev: React.PointerEvent) {
    dragging.current = true;
    moved.current = false;
    start.current = { px: ev.clientX, py: ev.clientY, x: piece.x, y: piece.y };
    (ev.target as HTMLElement).setPointerCapture(ev.pointerId);
    if (!editing) {
      clearPress();
      pressTimer.current = setTimeout(() => {
        if (!moved.current) onEnterEdit();
      }, LONG_PRESS);
    }
  }
  function move(ev: React.PointerEvent) {
    if (!dragging.current) return;
    const dx = ev.clientX - start.current.px;
    const dy = ev.clientY - start.current.py;
    if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
      moved.current = true;
      clearPress();
    }
    const board = boardRef.current;
    const maxX = board ? board.clientWidth - w - 6 : 999;
    const maxY = board ? board.clientHeight - h - 6 : 999;
    onMove(
      Math.max(6, Math.min(maxX, start.current.x + dx)),
      Math.max(6, Math.min(maxY, start.current.y + dy)),
    );
  }
  function up() {
    dragging.current = false;
    clearPress();
    if (!moved.current && !editing) onOpen();
  }

  function rDown(ev: React.PointerEvent) {
    ev.stopPropagation();
    resizing.current = true;
    rStart.current = { px: ev.clientX, py: ev.clientY, s: piece.scale };
    (ev.target as HTMLElement).setPointerCapture(ev.pointerId);
  }
  function rMove(ev: React.PointerEvent) {
    if (!resizing.current) return;
    ev.stopPropagation();
    const d = (ev.clientX - rStart.current.px + (ev.clientY - rStart.current.py)) / 2;
    onResize(Math.max(0.72, Math.min(1.45, rStart.current.s + d / 130)));
  }
  function rUp(ev: React.PointerEvent) {
    ev.stopPropagation();
    resizing.current = false;
  }

  return (
    <div
      onPointerDown={down}
      onPointerMove={move}
      onPointerUp={up}
      onPointerCancel={up}
      className="absolute touch-none select-none"
      style={{ left: piece.x, top: piece.y, width: w, height: h, zIndex: editing ? 30 : 1, cursor: editing ? "grab" : "pointer" }}
    >
      <motion.div
        className="relative w-full h-full"
        initial={born ? { scale: 0, opacity: 0, y: 28 } : false}
        animate={{
          scale: editing ? 1.05 : 1,
          opacity: tileOpacity,
          rotate: editing ? [-1.4, 1.4] : piece.rot,
          y: 0,
        }}
        transition={{
          scale: born
            ? { type: "spring", stiffness: 190, damping: 9 }
            : { type: "spring", stiffness: 260, damping: 20 },
          y: { type: "spring", stiffness: 200, damping: 16 },
          opacity: { duration: 0.38 },
          rotate: editing
            ? { repeat: Infinity, repeatType: "mirror", duration: 0.24, ease: "easeInOut" }
            : { type: "spring", stiffness: 200, damping: 18 },
        }}
      >
        {/* illustrated card body — artwork fills the tile, fades with days */}
        <div
          className="relative w-full h-full"
          style={{
            filter: editing
              ? "drop-shadow(0 10px 18px rgba(90,70,55,0.18))"
              : `drop-shadow(0 5px 12px rgba(90,70,55,${0.13 - f * 0.06}))`,
          }}
        >
          <img
            src={SKINS[piece.skin].src}
            alt=""
            draggable={false}
            className="absolute inset-0 w-full h-full pointer-events-none"
            style={{
              // 变暗 + 去饱和 + 转灰 + 略微透明（照设计稿"暗沉下去"的效果）
              filter: `brightness(${1 - 0.18 * f}) saturate(${1 - 0.8 * f}) grayscale(${0.85 * f}) opacity(${1 - f * 0.4})`,
            }}
          />
          {/* 名称 + 徽章：代码层渲染（插画里不烤字），跟图标同一套 fade 节奏分层 */}
          <div
            className="absolute flex items-center"
            style={{
              left: 11 * Math.min(piece.scale, 1.15),
              top: 6 * Math.min(piece.scale, 1.15),
              gap: 5,
              maxWidth: w - 14,
              // 与插画 filter opacity 同步，字跟着图一起变淡
              opacity: 1 - f * 0.4,
            }}
          >
            <span
              style={{
                color: mix("#4A3B2A", "#9A9086", f),
                fontSize: 13 * Math.min(piece.scale, 1.15),
                fontWeight: 700,
                letterSpacing: "0.02em",
                whiteSpace: "nowrap",
                overflow: "hidden",
                textOverflow: "ellipsis",
                textShadow: "0 1px 2px rgba(255,255,255,0.4)",
              }}
            >
              {piece.name}
            </span>
            {piece.lastDays >= 7 && (() => {
              // 预警橙 → 变灰后转红（照设计稿两段式）
              const bad = piece.lastDays >= 14;
              const tone = bad ? "#D9534C" : "#E08A3C";
              const shown = bad ? mix(tone, "#B0A89D", f) : tone;
              return (
              <span
                className="flex items-center"
                style={{
                  gap: 3,
                  backgroundColor: rgba(tone, bad ? 0.16 - 0.06 * f : 0.16),
                  borderRadius: 999,
                  padding: `${2.5 * piece.scale}px ${6 * piece.scale}px`,
                  fontSize: 10.5 * Math.min(piece.scale, 1.15),
                  fontWeight: 600,
                  color: shown,
                  whiteSpace: "nowrap",
                  flexShrink: 0,
                }}
              >
                <TriangleAlert size={9} color={shown} strokeWidth={2.4} />
                {piece.lastDays}天未维护
              </span>
              );
            })()}
          </div>
          {/* born flash — warm bloom from within when a space joins */}
          {born && (
            <>
              <motion.div
                className="absolute inset-0 pointer-events-none"
                initial={{ opacity: 1 }}
                animate={{ opacity: 0 }}
                transition={{ duration: 1.4, ease: "easeOut" }}
                style={{ background: `radial-gradient(circle at 50% 42%, rgba(255,255,255,0.95), rgba(255,255,255,0) 68%)` }}
              />
              <motion.div
                className="absolute inset-0 pointer-events-none"
                initial={{ opacity: 0.55 }}
                animate={{ opacity: 0 }}
                transition={{ duration: 1.8, ease: "easeOut", delay: 0.12 }}
                style={{ background: `radial-gradient(circle at 50% 42%, rgba(250,136,58,0.45), transparent 72%)` }}
              />
            </>
          )}
          {/* relit bloom — colour restore glow when space is re-lit */}
          {relit && (
            <>
              <motion.div
                className="absolute inset-0 pointer-events-none"
                initial={{ opacity: 0.9 }}
                animate={{ opacity: 0 }}
                transition={{ duration: 2.0, ease: "easeOut" }}
                style={{ background: "radial-gradient(circle at 50% 44%, rgba(255,255,255,0.96), rgba(255,255,255,0) 68%)" }}
              />
              <motion.div
                className="absolute inset-0 pointer-events-none"
                initial={{ opacity: 0.6 }}
                animate={{ opacity: 0 }}
                transition={{ duration: 2.6, ease: "easeOut", delay: 0.2 }}
                style={{ background: `radial-gradient(circle at 50% 44%, ${piece.vivid}99, transparent 70%)` }}
              />
            </>
          )}
        </div>
      </motion.div>

      {/* ---- edit affordances : iOS-jiggle, quiet ---- */}
      <AnimatePresence>
        {editing && (
          <>
            <motion.button
              initial={{ opacity: 0, scale: 0.4 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.4 }}
              onPointerDown={(e) => e.stopPropagation()}
              onClick={(e) => { e.stopPropagation(); onDelete(); }}
              className="absolute flex items-center justify-center"
              style={{
                left: -8, top: -8, width: 24, height: 24, borderRadius: 999, zIndex: 5,
                backgroundColor: "rgba(255,255,255,0.96)",
                boxShadow: "0 2px 8px rgba(90,70,55,0.22)",
              }}
            >
              <X size={14} color="#C25C43" strokeWidth={2.6} />
            </motion.button>

            <motion.div
              initial={{ opacity: 0, scale: 0.6 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.6 }}
              onPointerDown={rDown}
              onPointerMove={rMove}
              onPointerUp={rUp}
              className="absolute flex items-center justify-center"
              style={{
                right: -9, bottom: -9, width: 24, height: 24, borderRadius: 999, zIndex: 5,
                backgroundColor: "rgba(255,255,255,0.96)",
                boxShadow: "0 2px 8px rgba(90,70,55,0.22)",
                cursor: "nwse-resize",
              }}
            >
              <svg width="11" height="11" viewBox="0 0 12 12" fill="none">
                <path d="M11 5V11H5M11 11L5.5 5.5" stroke={COFFEE} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  );
}

/* ------------------------------------------------------------------ *
 *  Spatial screen
 * ------------------------------------------------------------------ */
export function SpatialScreen({
  onReshoot,
  scanDone,
  onScanAck,
  onRelightRequest,
  relitSpaceId,
  onRelitAck,
  nativeSpaces,
  onNativeChange,
}: {
  onReshoot?: (mode: "compare" | "same" | "new") => void;
  scanDone?: boolean;
  onScanAck?: () => void;
  onRelightRequest?: (id: string, name: string, vivid: string) => void;
  relitSpaceId?: string | null;
  onRelitAck?: () => void;
  nativeSpaces?: NativeSpace[];
  onNativeChange?: () => void;
} = {}) {
  const [pieces, setPieces] = useState<Piece[]>(initialPieces);
  const [selected, setSelected] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);
  const [renaming, setRenaming] = useState(false);
  const [draft, setDraft] = useState("");
  const [reward, setReward] = useState<Piece | null>(null);
  const [bornId, setBornId] = useState<string | null>(null);
  const [bornPos, setBornPos] = useState<{ cx: number; cy: number } | null>(null);
  const [openProgress, setOpenProgress] = useState(false);
  const [retidy, setRetidy] = useState(false);
  const [relitId, setRelitId] = useState<string | null>(null);
  const boardRef = useRef<HTMLDivElement>(null);

  // When ShootFlow finishes, auto-trigger the new-space reward flow
  useEffect(() => {
    if (scanDone) {
      addSpace();
      onScanAck?.();
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scanDone]);

  // When RelightFlow completes, reset lastDays and play colour-restore animation
  useEffect(() => {
    if (relitSpaceId) {
      patch(relitSpaceId, { lastDays: 0 });
      setRelitId(relitSpaceId);
      onRelitAck?.();
      setTimeout(() => setRelitId(null), 2800);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [relitSpaceId]);

  function reshoot(mode: "compare" | "same" | "new") {
    setRetidy(false);
    setSelected(null);
    onReshoot?.(mode);
  }

  const current = pieces.find((p) => p.id === selected) ?? null;
  const toDelete = pieces.find((p) => p.id === confirmDelete) ?? null;

  function handleRelight() {
    if (!current) return;
    setSelected(null);
    setRetidy(false);
    onRelightRequest?.(current.id, current.name, current.vivid);
  }

  if (openProgress) {
    return <InProgressDetail onBack={() => setOpenProgress(false)} />;
  }

  function addSpace() {
    const tpl = NEW_TEMPLATES[pieces.length % NEW_TEMPLATES.length];
    const p: Piece = {
      id: "p" + Date.now(),
      name: tpl.name,
      vivid: tpl.vivid,
      skin: tpl.skin,
      items: 6 + Math.floor(Math.random() * 20),
      lastDays: 0,
      x: 60 + Math.random() * 110,
      y: 70 + Math.random() * 120,
      rot: Math.round((Math.random() - 0.5) * 12),
      scale: 1,
    };
    setReward(p);
  }

  function claimReward() {
    if (!reward) return;
    const s = SKINS[reward.skin];
    const w = Math.round(s.w * reward.scale);
    const h = Math.round(s.h * reward.scale);
    setBornPos({ cx: reward.x + w / 2, cy: reward.y + h / 2 });
    setPieces((prev) => [...prev, reward]);
    void nativeRequest("space.add", { name: reward.name }).then(onNativeChange);
    setBornId(reward.id);
    setReward(null);
    setTimeout(() => setBornPos(null), 2200);
  }

  const patch = (id: string, d: Partial<Piece>) =>
    setPieces((prev) => prev.map((p) => (p.id === id ? { ...p, ...d } : p)));

  function saveName() {
    if (current && draft.trim()) {
      patch(current.id, { name: draft.trim() });
      void nativeRequest("space.rename", { id: current.id, name: draft.trim() }).then(onNativeChange);
    }
    setRenaming(false);
  }

  function reviewNow() {
    if (!current) return;
    patch(current.id, { lastDays: 0 });
    setSelected(null);
  }

  function doDelete() {
    if (confirmDelete) {
      setPieces((prev) => prev.filter((p) => p.id !== confirmDelete));
      void nativeRequest("space.delete", { id: confirmDelete }).then(onNativeChange);
    }
    setConfirmDelete(null);
    setEditingId(null);
  }

  return (
    <div className="h-full w-full overflow-y-auto pb-32" style={{ backgroundColor: LINEN }}>
      {/* header — quiet */}
      <div className="px-6 pt-14 pb-1 flex items-end justify-between">
        <div>
          <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>我的家</p>
          <h1 style={{ color: COFFEE, fontSize: 25, fontWeight: 700, letterSpacing: "-0.01em" }}>空间地图</h1>
        </div>
        <AnimatePresence>
          {editingId && (
            <motion.button
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.9 }}
              onClick={() => setEditingId(null)}
              className="mb-1 flex items-center gap-1 px-3 py-1.5"
              style={{ backgroundColor: COFFEE, color: WHITE, borderRadius: 999, fontSize: 12, fontWeight: 600 }}
            >
              <Check size={13} /> 完成
            </motion.button>
          )}
        </AnimatePresence>
      </div>

      {/* ================  HERO : the growing collage  ================ */}
      <div className="px-4 mt-3">
        <div
          ref={boardRef}
          onPointerDown={() => editingId && setEditingId(null)}
          className="relative overflow-hidden"
          style={{
            height: 408,
            borderRadius: 30,
            background: `radial-gradient(140% 110% at 50% 0%, #FCFAF5 0%, ${PAPER} 68%, #EFE7DA 100%)`,
            boxShadow: "inset 0 1px 3px rgba(90,70,55,0.05)",
            touchAction: "none",
          }}
        >
          {/* paper grain over the whole board */}
          <div
            className="absolute inset-0 pointer-events-none"
            style={{
              backgroundImage: `url("${GRAIN}")`,
              backgroundSize: "200px 200px",
              mixBlendMode: "multiply",
              opacity: 0.05,
            }}
          />
          {pieces.map((p) => (
            <SpaceTile
              key={p.id}
              piece={p}
              boardRef={boardRef}
              editing={editingId === p.id}
              born={bornId === p.id}
              relit={relitId === p.id}
              onOpen={() => { setSelected(p.id); setRenaming(false); void nativeRequest("space.select", { id: p.id }); }}
              onMove={(x, y) => patch(p.id, { x, y })}
              onResize={(scale) => patch(p.id, { scale })}
              onEnterEdit={() => setEditingId(p.id)}
              onDelete={() => setConfirmDelete(p.id)}
            />
          ))}

          {/* ── Born ripple rings + toast ── */}
          <AnimatePresence>
            {bornPos && (
              <>
                {/* Concentric orange rings expanding from piece center */}
                {[0, 1, 2].map((i) => (
                  <motion.div
                    key={i}
                    initial={{ opacity: 0.7, scale: 0 }}
                    animate={{ opacity: 0, scale: 1 }}
                    exit={{}}
                    transition={{ duration: 1.0, delay: i * 0.22, ease: [0.22, 1, 0.36, 1] }}
                    style={{
                      position: "absolute",
                      left: bornPos.cx,
                      top: bornPos.cy,
                      width: 72 + i * 28,
                      height: 72 + i * 28,
                      marginLeft: -(72 + i * 28) / 2,
                      marginTop: -(72 + i * 28) / 2,
                      borderRadius: "50%",
                      border: `${2 - i * 0.4}px solid ${ORANGE}`,
                      pointerEvents: "none",
                      zIndex: 25,
                    }}
                  />
                ))}

                {/* Toast: "✨ 新空间碎片已落入" */}
                <motion.div
                  initial={{ opacity: 0, y: -10, scale: 0.9 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -8, scale: 0.95 }}
                  transition={{ type: "spring", stiffness: 340, damping: 26, delay: 0.3 }}
                  style={{
                    position: "absolute",
                    top: 14,
                    left: "50%",
                    transform: "translateX(-50%)",
                    zIndex: 26,
                    pointerEvents: "none",
                  }}
                >
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: 6,
                      backgroundColor: "rgba(26,20,17,0.82)",
                      backdropFilter: "blur(8px)",
                      color: "rgba(255,255,255,0.93)",
                      borderRadius: 999,
                      padding: "6px 14px 6px 10px",
                      fontSize: 12,
                      fontWeight: 600,
                      whiteSpace: "nowrap",
                    }}
                  >
                    <Sparkles size={12} color={ORANGE} />
                    新空间碎片已落入地图
                  </div>
                </motion.div>
              </>
            )}
          </AnimatePresence>

          {/* management FABs — space created via scan, not from here */}
          <div className="absolute flex items-center gap-2" style={{ right: 14, bottom: 14 }}>

            {/* Re-scan / readjust an existing space */}
            <motion.button
              whileTap={{ scale: 0.88 }}
              transition={{ type: "spring", stiffness: 440, damping: 26 }}
              onClick={() => onReshoot?.("compare")}
              className="h-10 w-10 flex items-center justify-center"
              style={{
                backgroundColor: WHITE,
                borderRadius: 999,
                boxShadow: "0 4px 12px rgba(90,70,55,0.13)",
                border: "none",
                cursor: "pointer",
              }}
            >
              <RotateCw size={15} color={COFFEE} strokeWidth={2.2} style={{ opacity: 0.65 }} />
            </motion.button>

            {/* 整理助手 — starts a new scan/organisation session */}
            <motion.button
              whileTap={{ scale: 0.95 }}
              transition={{ type: "spring", stiffness: 400, damping: 28 }}
              onClick={() => onReshoot?.("new")}
              className="flex items-center gap-1.5 pl-2.5 pr-3.5 py-2.5"
              style={{
                backgroundColor: WHITE,
                color: COFFEE,
                borderRadius: 999,
                boxShadow: "0 4px 14px rgba(90,70,55,0.16)",
                fontSize: 13,
                fontWeight: 600,
                border: "none",
                cursor: "pointer",
              }}
            >
              <span
                className="h-6 w-6 rounded-full flex items-center justify-center"
                style={{ backgroundColor: "rgba(250,136,58,0.12)" }}
              >
                <Sparkles size={13} color={ORANGE} />
              </span>
              整理助手
            </motion.button>

          </div>
        </div>
      </div>

      {/* third-level : quiet collection line */}
      <div className="px-6 mt-4 flex items-center gap-2.5">
        <div className="flex -space-x-1.5">
          {pieces.slice(0, 5).map((p) => (
            <span
              key={p.id}
              className="w-3.5 h-3.5 rounded-full"
              style={{ backgroundColor: mix(p.vivid, GREY, fade(p.lastDays)), border: `1.5px solid ${LINEN}` }}
            />
          ))}
        </div>
        <p style={{ color: COFFEE, fontSize: 13 }}>
          <span style={{ fontWeight: 700 }}>已收集 {pieces.length} 个空间</span>
          <span style={{ opacity: 0.5 }}> · 我的家正在慢慢成形</span>
        </p>
      </div>

      {/* fourth-level : continue current tidy-up (secondary) */}
      <div className="px-6 mt-7 mb-2">
        <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12, fontWeight: 600 }}>继续整理</p>
      </div>
      <div className="px-6">
        <button
          onClick={() => setOpenProgress(true)}
          className="w-full flex items-center gap-3.5 p-3 text-left active:scale-[0.99] transition-transform"
          style={{ backgroundColor: WHITE, borderRadius: 22, boxShadow: "0 2px 12px rgba(90,70,55,0.05)" }}
        >
          <div className="h-12 w-12 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ backgroundColor: BLUE }}>
            <Play size={18} color={WHITE} fill={WHITE} />
          </div>
          <div className="flex-1">
            <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>浴室 · 正在进行中</p>
            <div className="flex items-center gap-2 mt-1.5">
              <div className="flex-1 h-1.5 rounded-full" style={{ backgroundColor: LINEN }}>
                <div style={{ width: "35%", height: "100%", backgroundColor: ORANGE, borderRadius: 999 }} />
              </div>
              <span style={{ color: COFFEE, opacity: 0.6, fontSize: 11 }}>35%</span>
            </div>
          </div>
          <ChevronRight size={18} color={COFFEE} style={{ opacity: 0.4 }} />
        </button>
      </div>

      {/* ----------------  space detail sheet  ---------------- */}
      <AnimatePresence>
        {current && (
          <>
            <motion.div
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => setSelected(null)}
              className="absolute inset-0 z-40" style={{ backgroundColor: "rgba(42,32,26,0.32)" }}
            />
            <motion.div
              initial={{ y: "100%" }} animate={{ y: 0 }} exit={{ y: "100%" }}
              transition={{ type: "spring", stiffness: 320, damping: 32 }}
              className="absolute left-0 right-0 bottom-0 z-50 px-6 pt-3 pb-8"
              style={{ backgroundColor: WHITE, borderTopLeftRadius: 30, borderTopRightRadius: 30 }}
            >
              <div className="mx-auto mb-4 rounded-full" style={{ width: 40, height: 4, backgroundColor: SOFT }} />
              <div className="flex items-center gap-3.5">
                <div
                  className="h-14 w-14 flex items-center justify-center flex-shrink-0 overflow-hidden"
                  style={{ borderRadius: 16, boxShadow: "0 2px 8px rgba(90,70,55,0.12)" }}
                >
                  <img
                    src={SKINS[current.skin].src}
                    alt=""
                    className="w-full h-full"
                    style={{ objectFit: "cover" }}
                    draggable={false}
                  />
                </div>
                <div className="flex-1 min-w-0">
                  {renaming ? (
                    <input
                      autoFocus value={draft}
                      onChange={(e) => setDraft(e.target.value)}
                      onBlur={saveName}
                      onKeyDown={(e) => e.key === "Enter" && saveName()}
                      className="w-full outline-none pb-1"
                      style={{ color: COFFEE, fontSize: 18, fontWeight: 700, borderBottom: `2px solid ${ORANGE}`, backgroundColor: "transparent" }}
                    />
                  ) : (
                    <button onClick={() => { setDraft(current.name); setRenaming(true); }} className="flex items-center gap-1.5">
                      <span style={{ color: COFFEE, fontSize: 18, fontWeight: 700 }}>{current.name}</span>
                      <Pencil size={14} color={COFFEE} style={{ opacity: 0.45 }} />
                    </button>
                  )}
                  <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12, marginTop: 2 }}>
                    {current.items} 件物品 · {current.lastDays === 0 ? "刚刚整理" : `${current.lastDays} 天前整理`}
                  </p>
                </div>
                <button onClick={() => setSelected(null)} className="h-9 w-9 rounded-full flex items-center justify-center flex-shrink-0" style={{ backgroundColor: LINEN }}>
                  <X size={18} color={COFFEE} />
                </button>
              </div>

              {/* recolour — user picks the space's hue */}
              <div className="mt-5 flex items-center gap-2">
                <span style={{ color: COFFEE, opacity: 0.5, fontSize: 12, fontWeight: 600, marginRight: 2 }}>配色</span>
                {PALETTE.map((c) => {
                  const on = current.vivid.toLowerCase() === c.toLowerCase();
                  return (
                    <button
                      key={c}
                      onClick={() => patch(current.id, { vivid: c })}
                      className="rounded-full transition-transform active:scale-90"
                      style={{
                        width: 24, height: 24, backgroundColor: c,
                        boxShadow: on ? `0 0 0 2px ${WHITE}, 0 0 0 4px ${COFFEE}` : "inset 0 0 0 1px rgba(90,70,55,0.08)",
                      }}
                      aria-label={`配色 ${c}`}
                    />
                  );
                })}
              </div>

              {current.lastDays >= 14 && (
                <motion.button
                  whileTap={{ scale: 0.985 }}
                  onClick={handleRelight}
                  className="mt-4 p-3.5 flex items-center gap-3 text-left w-full"
                  style={{ backgroundColor: "#FBEBDB", borderRadius: 18, border: "none", cursor: "pointer" }}
                >
                  <div className="h-9 w-9 rounded-full flex items-center justify-center flex-shrink-0" style={{ backgroundColor: ORANGE }}>
                    <Sparkles size={15} color={WHITE} />
                  </div>
                  <p style={{ color: "#8A5A34", fontSize: 12.5, flex: 1, lineHeight: 1.5 }}>
                    这块空间的颜色已经变淡了——{current.lastDays} 天没照顾它，回去点亮它吧。
                  </p>
                </motion.button>
              )}

              <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12, fontWeight: 600, marginTop: 20, marginBottom: 10 }}>整理记录</p>
              <div className="space-y-2.5">
                {[
                  { t: current.lastDays === 0 ? "今天" : current.lastDays + " 天前", s: "完成整理,收纳 " + current.items + " 件物品" },
                  { t: "获得拼图", s: `“${current.name}”加入了空间地图` },
                ].map((r, i) => (
                  <div key={i} className="flex gap-3">
                    <div className="flex flex-col items-center pt-1">
                      <span className="w-2 h-2 rounded-full" style={{ backgroundColor: i === 0 ? ORANGE : BLUE }} />
                      {i === 0 && <span className="w-px flex-1 mt-1" style={{ backgroundColor: SOFT }} />}
                    </div>
                    <div className="pb-1">
                      <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{r.s}</p>
                      <p style={{ color: COFFEE, opacity: 0.45, fontSize: 11 }}>{r.t}</p>
                    </div>
                  </div>
                ))}
              </div>

              {current.lastDays >= 14 ? (
                <div className="mt-5 flex gap-2.5">
                  <button
                    onClick={handleRelight}
                    className="flex-1 py-3.5 flex items-center justify-center gap-1.5 active:scale-[0.98] transition-transform"
                    style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 18, fontSize: 14, fontWeight: 600 }}
                  >
                    <Camera size={16} color={COFFEE} /> 重新拍照比对
                  </button>
                  <button
                    onClick={() => setRetidy(true)}
                    className="flex-1 py-3.5 flex items-center justify-center gap-1.5 active:scale-[0.98] transition-transform"
                    style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 18, fontSize: 14, fontWeight: 600, boxShadow: "0 6px 18px rgba(250,136,58,0.3)" }}
                  >
                    <RotateCw size={16} color={WHITE} /> 再次整理
                  </button>
                </div>
              ) : (
                <button
                  onClick={reviewNow}
                  className="w-full mt-5 py-3.5 active:scale-[0.98] transition-transform"
                  style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 18, fontSize: 15, fontWeight: 600 }}
                >
                  进入这个空间
                </button>
              )}
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* ----------------  re-tidy choice (原方案 / 新方案)  ---------------- */}
      <AnimatePresence>
        {retidy && current && (
          <>
            <motion.div
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => setRetidy(false)}
              className="absolute inset-0 z-[75]" style={{ backgroundColor: "rgba(42,32,26,0.4)" }}
            />
            <motion.div
              initial={{ y: "100%" }} animate={{ y: 0 }} exit={{ y: "100%" }}
              transition={{ type: "spring", stiffness: 320, damping: 32 }}
              className="absolute left-0 right-0 bottom-0 z-[80] px-6 pt-3 pb-8"
              style={{ backgroundColor: WHITE, borderTopLeftRadius: 30, borderTopRightRadius: 30 }}
            >
              <div className="mx-auto mb-4 rounded-full" style={{ width: 40, height: 4, backgroundColor: SOFT }} />
              <p style={{ color: COFFEE, fontSize: 17, fontWeight: 700 }}>再次整理「{current.name}」</p>
              <p style={{ color: COFFEE, opacity: 0.55, fontSize: 12.5, marginTop: 4, lineHeight: 1.5 }}>
                重新拍摄这个空间，选择沿用原来的方案，或让小助手生成新的方案。整理完这块碎片会重新点亮，无需新增拼图。
              </p>

              <button
                onClick={() => reshoot("same")}
                className="w-full mt-5 p-3.5 flex items-center gap-3 text-left active:scale-[0.99] transition-transform"
                style={{ backgroundColor: LINEN, borderRadius: 18 }}
              >
                <div className="h-10 w-10 rounded-xl flex items-center justify-center flex-shrink-0" style={{ backgroundColor: current.vivid }}>
                  <RotateCw size={18} color={WHITE} />
                </div>
                <div className="flex-1">
                  <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>沿用原方案</p>
                  <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11.5 }}>按上次的方案快速复位</p>
                </div>
                <ChevronRight size={18} color={COFFEE} style={{ opacity: 0.4 }} />
              </button>

              <button
                onClick={() => reshoot("new")}
                className="w-full mt-2.5 p-3.5 flex items-center gap-3 text-left active:scale-[0.99] transition-transform"
                style={{ backgroundColor: LINEN, borderRadius: 18 }}
              >
                <div className="h-10 w-10 rounded-xl flex items-center justify-center flex-shrink-0" style={{ backgroundColor: BLUE }}>
                  <Sparkles size={18} color={WHITE} />
                </div>
                <div className="flex-1">
                  <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>生成新方案</p>
                  <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11.5 }}>重新拍摄，探索新的整理风格</p>
                </div>
                <ChevronRight size={18} color={COFFEE} style={{ opacity: 0.4 }} />
              </button>

              <button
                onClick={() => setRetidy(false)}
                className="w-full mt-4 py-3"
                style={{ color: COFFEE, opacity: 0.6, fontSize: 13, fontWeight: 500 }}
              >
                取消
              </button>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* ----------------  iOS-style delete confirm  ---------------- */}
      <AnimatePresence>
        {toDelete && (
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            className="absolute inset-0 z-[70] flex items-center justify-center px-10"
            style={{ backgroundColor: "rgba(42,32,26,0.4)" }}
            onClick={() => setConfirmDelete(null)}
          >
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.95, opacity: 0 }}
              transition={{ type: "spring", stiffness: 340, damping: 26 }}
              className="w-full max-w-[280px] overflow-hidden"
              style={{ backgroundColor: "rgba(255,255,255,0.98)", backdropFilter: "blur(20px)", borderRadius: 22 }}
              onClick={(e) => e.stopPropagation()}
            >
              <div className="px-5 pt-5 pb-4 text-center">
                <p style={{ color: COFFEE, fontSize: 16, fontWeight: 700 }}>删除这个空间?</p>
                <p style={{ color: COFFEE, opacity: 0.55, fontSize: 12.5, marginTop: 6, lineHeight: 1.5 }}>
                  删除后,“{toDelete.name}”及其整理记录将从空间地图中移除。
                </p>
              </div>
              <div className="grid grid-cols-2" style={{ borderTop: "1px solid rgba(90,70,55,0.12)" }}>
                <button
                  onClick={() => setConfirmDelete(null)}
                  className="py-3.5 active:bg-black/5"
                  style={{ color: COFFEE, fontSize: 15, fontWeight: 600, borderRight: "1px solid rgba(90,70,55,0.12)" }}
                >
                  取消
                </button>
                <button onClick={doDelete} className="py-3.5 active:bg-black/5" style={{ color: "#C25C43", fontSize: 15, fontWeight: 700 }}>
                  删除
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ----------------  "获得新空间" reward  ---------------- */}
      <AnimatePresence>
        {reward && (
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            className="absolute inset-0 z-[60] flex items-center justify-center px-8"
            style={{ backgroundColor: "rgba(42,32,26,0.45)" }}
            onClick={claimReward}
          >
            <motion.div
              initial={{ scale: 0.85, y: 16, opacity: 0 }} animate={{ scale: 1, y: 0, opacity: 1 }} exit={{ scale: 0.92, opacity: 0 }}
              transition={{ type: "spring", stiffness: 300, damping: 24 }}
              className="w-full text-center px-7 py-9"
              style={{ backgroundColor: WHITE, borderRadius: 30 }}
              onClick={(e) => e.stopPropagation()}
            >
              <div className="relative mx-auto mb-5" style={{ width: 128, height: 128 }}>
                <motion.div
                  animate={{ rotate: 360 }} transition={{ duration: 16, repeat: Infinity, ease: "linear" }}
                  className="absolute inset-0 flex items-center justify-center"
                >
                  {[0, 1, 2, 3, 4, 5].map((i) => (
                    <span key={i} className="absolute" style={{ transform: `rotate(${i * 60}deg) translateY(-62px)`, color: i % 2 ? BLUE : ORANGE, opacity: 0.7 }}>
                      <Sparkles size={13} />
                    </span>
                  ))}
                </motion.div>
                <motion.div
                  initial={{ scale: 0, rotate: -18 }} animate={{ scale: 1, rotate: 0 }}
                  transition={{ type: "spring", stiffness: 250, damping: 15, delay: 0.12 }}
                  className="absolute inset-0 flex flex-col items-center justify-center overflow-hidden"
                  style={{
                    width: 96, height: 96, margin: "auto",
                    borderRadius: 18,
                    filter: "drop-shadow(0 8px 16px rgba(90,70,55,0.2))",
                  }}
                >
                  <img
                    src={SKINS[reward.skin].src}
                    alt=""
                    className="absolute inset-0 w-full h-full"
                    style={{ objectFit: "cover" }}
                    draggable={false}
                  />
                </motion.div>
              </div>

              <p style={{ color: ORANGE, fontSize: 12, fontWeight: 700, letterSpacing: "0.08em" }}>点亮了一块新空间</p>
              <h2 style={{ color: COFFEE, fontSize: 22, fontWeight: 700, marginTop: 6 }}>“{reward.name}”</h2>
              <p style={{ color: COFFEE, opacity: 0.55, fontSize: 13, marginTop: 8, lineHeight: 1.5 }}>
                它已经拼进了你的家。长按任意空间即可移动、缩放<br />或删除,慢慢拼出属于你的地图。
              </p>

              <button
                onClick={claimReward}
                className="w-full mt-6 py-3.5 active:scale-[0.98] transition-transform"
                style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 18, fontSize: 15, fontWeight: 600 }}
              >
                加入我的家
              </button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
