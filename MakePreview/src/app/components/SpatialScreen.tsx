import { useRef, useState, useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Plus, Sparkles, X, RotateCw, Pencil, ChevronRight, Play, Check, Camera } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { InProgressDetail } from "./InProgressDetail";

/* ------------------------------------------------------------------ *
 *  Shape catalog — organic, hand-cut silhouettes that share one edge
 *  language so a varied collage still reads as a single map.
 * ------------------------------------------------------------------ */
type ShapeKey = "capsule" | "arch" | "leaf" | "slab" | "petal" | "pebble" | "bone";

// hand-cut silhouettes as normalized (0..1) paths, used via clip-path so
// edges read like torn / watercolour cut-outs rather than CSS rounding.
const SHAPES: Record<ShapeKey, { w: number; h: number; path: string }> = {
  capsule: {
    w: 142, h: 74,
    path: "M0.17,0.07 C0.05,0.12 0.0,0.32 0.01,0.52 C0.02,0.74 0.07,0.92 0.21,0.94 L0.82,0.93 C0.95,0.9 1.0,0.68 0.99,0.47 C0.98,0.26 0.93,0.08 0.79,0.07 Z",
  },
  arch: {
    w: 100, h: 118,
    path: "M0.5,0.02 C0.21,0.03 0.03,0.24 0.05,0.52 L0.06,0.87 C0.06,0.95 0.12,0.98 0.2,0.98 L0.81,0.97 C0.9,0.97 0.95,0.93 0.95,0.85 L0.96,0.5 C0.98,0.23 0.79,0.02 0.5,0.02 Z",
  },
  leaf: {
    w: 120, h: 100,
    path: "M0.05,0.08 C0.42,0.0 0.72,0.06 0.95,0.27 C1.01,0.35 0.99,0.52 0.9,0.64 C0.66,0.96 0.34,1.01 0.07,0.93 C0.0,0.68 0.0,0.38 0.05,0.08 Z",
  },
  slab: {
    w: 128, h: 94,
    path: "M0.11,0.07 C0.04,0.11 0.02,0.24 0.04,0.42 L0.02,0.75 C0.02,0.9 0.1,0.96 0.25,0.96 L0.78,0.98 C0.93,0.97 0.98,0.86 0.97,0.72 L0.98,0.27 C0.98,0.11 0.9,0.05 0.75,0.05 Z",
  },
  petal: {
    w: 98, h: 116,
    path: "M0.5,0.02 C0.75,0.03 0.93,0.19 0.92,0.41 C0.91,0.67 0.79,0.98 0.5,0.98 C0.22,0.98 0.09,0.65 0.09,0.4 C0.09,0.19 0.26,0.03 0.5,0.02 Z",
  },
  pebble: {
    w: 124, h: 98,
    path: "M0.52,0.03 C0.77,0.02 0.98,0.21 0.97,0.47 C0.97,0.77 0.79,0.98 0.5,0.97 C0.21,0.97 0.02,0.76 0.03,0.47 C0.04,0.2 0.27,0.04 0.52,0.03 Z",
  },
  bone: {
    w: 134, h: 80,
    path: "M0.15,0.5 C0.14,0.26 0.29,0.13 0.43,0.2 C0.5,0.24 0.5,0.24 0.57,0.2 C0.71,0.12 0.87,0.27 0.86,0.5 C0.86,0.73 0.71,0.87 0.57,0.8 C0.5,0.76 0.5,0.76 0.43,0.8 C0.29,0.87 0.15,0.74 0.15,0.5 Z",
  },
};

function ShapeDefs() {
  return (
    <svg width="0" height="0" style={{ position: "absolute" }} aria-hidden>
      <defs>
        {(Object.keys(SHAPES) as ShapeKey[]).map((k) => (
          <clipPath key={k} id={`clip-${k}`} clipPathUnits="objectBoundingBox">
            <path d={SHAPES[k].path} />
          </clipPath>
        ))}
      </defs>
    </svg>
  );
}

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
// 0 = vivid & fresh, ~1 = washed-out grey. Eased so a space starts
// visibly losing colour once it has been left for a while.
function fade(days: number) {
  const t = Math.min(days / 42, 1);
  return Math.min(Math.pow(t, 0.72) * 1.03, 0.96);
}

/* ------------------------------------------------------------------ *
 *  Data model
 * ------------------------------------------------------------------ */
type Piece = {
  id: string;
  name: string;
  emoji: string;
  vivid: string;
  shape: ShapeKey;
  items: number;
  lastDays: number;
  x: number;
  y: number;
  rot: number;
  scale: number;
};

const initialPieces: Piece[] = [
  { id: "p1", name: "懒人沙发区", emoji: "🛋️", vivid: "#E29B7B", shape: "slab", items: 24, lastDays: 2, x: 24, y: 34, rot: -4, scale: 1.06 },
  { id: "p2", name: "我的书桌", emoji: "🖥️", vivid: "#7FB0AA", shape: "capsule", items: 18, lastDays: 8, x: 160, y: 24, rot: 5, scale: 1 },
  { id: "p3", name: "晒太阳的阳台", emoji: "🪴", vivid: "#A9B486", shape: "arch", items: 9, lastDays: 26, x: 192, y: 122, rot: -3, scale: 0.9 },
  { id: "p4", name: "小卧室", emoji: "🛏️", vivid: "#DFA6B0", shape: "petal", items: 31, lastDays: 48, x: 44, y: 172, rot: 6, scale: 1 },
];

const NEW_TEMPLATES: { name: string; emoji: string; vivid: string; shape: ShapeKey }[] = [
  { name: "厨房", emoji: "🍳", vivid: "#ECC079", shape: "leaf" },
  { name: "衣柜", emoji: "👗", vivid: "#C3AAD4", shape: "petal" },
  { name: "玄关", emoji: "🔑", vivid: "#9DBBC9", shape: "bone" },
  { name: "工作角落", emoji: "💡", vivid: "#E29B7B", shape: "pebble" },
  { name: "储物间", emoji: "📦", vivid: "#A6B2D6", shape: "slab" },
];

const LONG_PRESS = 420;

function effSize(p: Piece) {
  const s = SHAPES[p.shape];
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
  const fill = mix(piece.vivid, GREY, f);

  // urgency → faintness; fresh reads full & textured, stale washes out
  const tileOpacity = 1 - f * 0.4;
  const fillAlpha = 0.95 - f * 0.22;
  const grainOpacity = 0.55 - f * 0.32;

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
        {/* hand-cut painted body (silhouette via clip-path) */}
        <div
          className="relative w-full h-full flex flex-col items-center justify-center text-center"
          style={{
            clipPath: `url(#clip-${piece.shape})`,
            WebkitClipPath: `url(#clip-${piece.shape})`,
            backgroundColor: rgba(fill, fillAlpha),
            filter: editing
              ? "drop-shadow(0 10px 18px rgba(90,70,55,0.18))"
              : `drop-shadow(0 5px 12px rgba(90,70,55,${0.13 - f * 0.06}))`,
          }}
        >
          {/* riso grain texture — matte, strongest when fresh */}
          <div
            className="absolute inset-0 pointer-events-none"
            style={{
              backgroundImage: `url("${GRAIN}")`,
              backgroundSize: "150px 150px",
              mixBlendMode: "soft-light",
              opacity: grainOpacity,
            }}
          />
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
          <span
            className="relative"
            style={{ fontSize: 24 * piece.scale, lineHeight: 1, filter: `grayscale(${f * 0.75}) opacity(${1 - f * 0.18})` }}
          >
            {piece.emoji}
          </span>
          <span
            className="truncate px-2 relative"
            style={{
              color: mix("#463222", "#8C8378", f),
              fontSize: 11 * Math.min(piece.scale, 1.15),
              fontWeight: 600,
              marginTop: 4,
              maxWidth: w - 12,
            }}
          >
            {piece.name}
          </span>
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
}: {
  onReshoot?: (mode: "compare" | "same" | "new") => void;
  scanDone?: boolean;
  onScanAck?: () => void;
  onRelightRequest?: (id: string, name: string, vivid: string) => void;
  relitSpaceId?: string | null;
  onRelitAck?: () => void;
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
      emoji: tpl.emoji,
      vivid: tpl.vivid,
      shape: tpl.shape,
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
    const shape = SHAPES[reward.shape];
    const w = Math.round(shape.w * reward.scale);
    const h = Math.round(shape.h * reward.scale);
    setBornPos({ cx: reward.x + w / 2, cy: reward.y + h / 2 });
    setPieces((prev) => [...prev, reward]);
    setBornId(reward.id);
    setReward(null);
    setTimeout(() => setBornPos(null), 2200);
  }

  const patch = (id: string, d: Partial<Piece>) =>
    setPieces((prev) => prev.map((p) => (p.id === id ? { ...p, ...d } : p)));

  function saveName() {
    if (current && draft.trim()) patch(current.id, { name: draft.trim() });
    setRenaming(false);
  }

  function reviewNow() {
    if (!current) return;
    patch(current.id, { lastDays: 0 });
    setSelected(null);
  }

  function doDelete() {
    if (confirmDelete) setPieces((prev) => prev.filter((p) => p.id !== confirmDelete));
    setConfirmDelete(null);
    setEditingId(null);
  }

  return (
    <div className="h-full w-full overflow-y-auto pb-32" style={{ backgroundColor: LINEN }}>
      <ShapeDefs />
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
              onOpen={() => { setSelected(p.id); setRenaming(false); }}
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
                  className="h-14 w-14 flex items-center justify-center flex-shrink-0"
                  style={{
                    backgroundColor: mix(current.vivid, GREY, fade(current.lastDays)),
                    clipPath: `url(#clip-${current.shape})`,
                    WebkitClipPath: `url(#clip-${current.shape})`,
                    fontSize: 26,
                  }}
                >
                  {current.emoji}
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
                <div className="mt-4 p-3.5 flex items-center gap-3" style={{ backgroundColor: "#F4EDE4", borderRadius: 18 }}>
                  <div className="relative flex-shrink-0">
                    {/* Pulse ring to draw attention */}
                    <motion.div
                      className="absolute inset-0 rounded-full"
                      style={{ backgroundColor: ORANGE }}
                      animate={{ scale: [1, 1.55], opacity: [0.35, 0] }}
                      transition={{ duration: 1.4, repeat: Infinity, ease: "easeOut" }}
                    />
                    <motion.button
                      whileTap={{ scale: 0.88 }}
                      transition={{ type: "spring", stiffness: 440, damping: 22 }}
                      onClick={handleRelight}
                      className="relative h-9 w-9 rounded-full flex items-center justify-center"
                      style={{
                        backgroundColor: ORANGE,
                        boxShadow: "0 4px 14px rgba(250,136,58,0.42)",
                        border: "none",
                        cursor: "pointer",
                      }}
                    >
                      <Sparkles size={15} color={WHITE} />
                    </motion.button>
                  </div>
                  <p style={{ color: COFFEE, opacity: 0.7, fontSize: 12.5, flex: 1 }}>
                    这块空间的颜色已经变淡了——{current.lastDays} 天没照顾它,回去点亮它吧。
                  </p>
                </div>
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
                  className="absolute inset-0 flex flex-col items-center justify-center"
                  style={{
                    width: 96, height: 96, margin: "auto",
                    clipPath: `url(#clip-${reward.shape})`,
                    WebkitClipPath: `url(#clip-${reward.shape})`,
                    backgroundColor: reward.vivid,
                    filter: "drop-shadow(0 8px 16px rgba(90,70,55,0.2))",
                  }}
                >
                  <div
                    className="absolute inset-0 pointer-events-none"
                    style={{ backgroundImage: `url("${GRAIN}")`, backgroundSize: "120px 120px", mixBlendMode: "soft-light", opacity: 0.5 }}
                  />
                  <span className="relative" style={{ fontSize: 32 }}>{reward.emoji}</span>
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
