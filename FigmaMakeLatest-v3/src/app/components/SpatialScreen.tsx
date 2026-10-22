import { useRef, useState, useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Sparkles, X, RotateCw, Pencil, ChevronRight, Play, Check, Camera, Trash2, CircleAlert, SlidersHorizontal, Undo2 } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { InProgressDetail } from "./InProgressDetail";
import { nativeRequest, type NativeSpace, type NativeState } from "../nativeBridge";
import { SpaceArtwork, SPACE_TEMPLATES, type SpaceKind, type SpaceShape } from "./SpaceArtwork";
import { inferSpaceKind, normalizeSpaceLayout, parseSpaceLayouts, pointerDelta, spaceFootprint, SPACE_KINDS, type SpaceLayout } from "../spaceLayout";

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
// 连续渐变（天数越多越暗沉，每天都有差别）：
// 0~14 天 —— 轻微走色（0 → 0.38），8 天时已能看出一点发旧
// 14 天起 —— 明显暗沉（0.62 起步），到 42 天灰透（0.96）
function fade(days: number) {
  if (days < 14) return 0.38 * Math.pow(days / 14, 1.35);
  const t = Math.min((days - 14) / 28, 1);
  return 0.62 + 0.34 * Math.pow(t, 0.72);
}

/* ------------------------------------------------------------------ *
 *  Data model
 * ------------------------------------------------------------------ */
type Piece = SpaceLayout & {
  id: string;
  name: string;
  items: number;
  lastDays: number;
  organized?: boolean;
};

// 初始摆位照设计稿：床左上、茶几右中、厨房左下。
// “桌面”不作为首次进入空间地图时的默认区域；它仍保留在 NEW_TEMPLATES 中，
// 因此用户后续通过重新收集/新增区域时仍可生成桌面区域。
const initialPieces: Piece[] = [
  { id: "p1", name: "床", vivid: SPACE_TEMPLATES.bed.color, skin: "bed", shape: "original", width: 138, height: 138, items: 24, lastDays: 2, x: 40, y: 60, rot: 0, scale: 1 },
  { id: "p3", name: "厨房", vivid: SPACE_TEMPLATES.kitchen.color, skin: "kitchen", shape: "original", width: 138, height: 138, items: 9, lastDays: 30, x: 40, y: 194, rot: 0, scale: 1 },
  { id: "p4", name: "茶几", vivid: SPACE_TEMPLATES.teatable.color, skin: "teatable", shape: "original", width: 139, height: 74, items: 31, lastDays: 15, x: 178, y: 144, rot: 0, scale: 1 },
];

const LAYOUT_KEY = "smartpaw-space-map-layout-v1";

function savedLayouts(storageKey: string): Record<string, Record<string, unknown>> {
  try {
    return parseSpaceLayouts(localStorage.getItem(storageKey));
  } catch { return {}; }
}

function previewPieces(storageKey: string): Piece[] {
  const layouts = savedLayouts(storageKey);
  return initialPieces.map((piece) => ({ ...piece, ...normalizeSpaceLayout(layouts[piece.id], piece) }));
}

function nativePieces(spaces: NativeSpace[], previous: Piece[] = [], storageKey = LAYOUT_KEY): Piece[] {
  const layouts = savedLayouts(storageKey);
  return spaces.map((space, index) => {
    const old = previous.find((piece) => piece.id === space.id);
    const slot = initialPieces[index % initialPieces.length];
    const skin = inferSpaceKind(space.name);
    const template = SPACE_TEMPLATES[skin];
    const layout = normalizeSpaceLayout(old || layouts[space.id], {
      skin, shape: "original", width: template.w, height: template.h,
      x: slot.x, y: slot.y, rot: 0, scale: 1, vivid: template.color,
    });
    const organizedAt = space.lastOrganizedAt ? Date.parse(space.lastOrganizedAt) : NaN;
    return {
      ...layout,
      id: space.id, name: space.name, items: space.detectedItems.length,
      lastDays: Number.isFinite(organizedAt) ? Math.max(0, Math.floor((Date.now() - organizedAt) / 86400000)) : 0,
      organized: Number.isFinite(organizedAt),
    };
  });
}

const LONG_PRESS = 420;

function effSize(p: Piece) {
  return { w: p.width * p.scale, h: p.height * p.scale };
}

function ArtworkThumbnail({ piece, size }: { piece: Piece; size: number }) {
  const bounds = spaceFootprint(piece);
  const fit = size / Math.max(bounds.width, bounds.height);
  const { w, h } = effSize(piece);
  return (
    <div className="relative flex-shrink-0" style={{ width: bounds.width * fit, height: bounds.height * fit }}>
      <SpaceArtwork
        kind={piece.skin} shape={piece.shape} color={piece.vivid}
        width={piece.width} height={piece.height}
        style={{ position: "absolute", width: w * fit, height: h * fit, left: (bounds.width - w) * fit / 2, top: (bounds.height - h) * fit / 2, transform: `rotate(${piece.rot}deg)` }}
      />
    </div>
  );
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
  const bounds = spaceFootprint(piece);

  const f = fade(piece.lastDays);

  // 插画与叠字共用同一套褪色滤镜，保证两者视觉同步
  const fadeFilter = `brightness(${1 - 0.18 * f}) saturate(${1 - 0.8 * f}) grayscale(${0.85 * f})`;
  const fadeAlpha = 1 - f * 0.4;

  // urgency → faintness; fresh reads full & textured, stale washes out
  const tileOpacity = 1 - f * 0.4;

  function clearPress() {
    if (pressTimer.current) {
      clearTimeout(pressTimer.current);
      pressTimer.current = null;
    }
  }
  useEffect(() => () => clearPress(), []);
  function down(ev: React.PointerEvent) {
    ev.stopPropagation();
    dragging.current = true;
    moved.current = false;
    start.current = { px: ev.clientX, py: ev.clientY, x: piece.x, y: piece.y };
    ev.currentTarget.setPointerCapture(ev.pointerId);
    if (!editing) {
      clearPress();
      pressTimer.current = setTimeout(() => {
        if (!moved.current) {
          moved.current = true;
          onEnterEdit();
        }
      }, LONG_PRESS);
    }
  }
  function move(ev: React.PointerEvent) {
    if (!dragging.current) return;
    const board = boardRef.current;
    const rect = board?.getBoundingClientRect();
    const delta = pointerDelta(ev.clientX, ev.clientY, start.current.px, start.current.py, board?.clientWidth ?? 358, board?.clientHeight ?? 408, rect?.width ?? 358, rect?.height ?? 408);
    const dx = delta.x;
    const dy = delta.y;
    if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
      moved.current = true;
      clearPress();
    }
    const maxX = board ? board.clientWidth - bounds.width - 6 : 999;
    const maxY = board ? board.clientHeight - bounds.height - 6 : 999;
    onMove(
      Math.max(6, Math.min(maxX, start.current.x + dx)),
      Math.max(6, Math.min(maxY, start.current.y + dy)),
    );
  }
  function up() {
    dragging.current = false;
    clearPress();
  }
  function cancel() {
    dragging.current = false;
    clearPress();
  }

  function rDown(ev: React.PointerEvent) {
    ev.stopPropagation();
    resizing.current = true;
    rStart.current = { px: ev.clientX, py: ev.clientY, s: piece.scale };
    ev.currentTarget.setPointerCapture(ev.pointerId);
  }
  function rMove(ev: React.PointerEvent) {
    if (!resizing.current) return;
    ev.stopPropagation();
    const board = boardRef.current;
    const rect = board?.getBoundingClientRect();
    const delta = pointerDelta(ev.clientX, ev.clientY, rStart.current.px, rStart.current.py, board?.clientWidth ?? 358, board?.clientHeight ?? 408, rect?.width ?? 358, rect?.height ?? 408);
    const d = (delta.x + delta.y) / 2;
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
      onPointerCancel={cancel}
      onClick={(event) => {
        event.stopPropagation();
        if (!moved.current && !editing) onOpen();
      }}
      className="absolute touch-none select-none"
      role="button"
      tabIndex={0}
      aria-label={`${piece.name}，${piece.items} 件物品`}
      onKeyDown={(event) => { if (event.target === event.currentTarget && (event.key === "Enter" || event.key === " ")) { event.preventDefault(); onOpen(); } }}
      style={{ left: piece.x, top: piece.y, width: bounds.width, height: bounds.height, zIndex: editing ? 30 : 1, cursor: editing ? "grab" : "pointer" }}
    >
      <motion.div
        className="absolute"
        style={{ width: w, height: h, left: (bounds.width - w) / 2, top: (bounds.height - h) / 2 }}
        initial={born ? { scale: 0, opacity: 0, y: 28 } : false}
        animate={{
          scale: editing ? 1.05 : 1,
          opacity: tileOpacity,
          rotate: editing ? [piece.rot - 1.4, piece.rot + 1.4] : piece.rot,
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
          <SpaceArtwork
            kind={piece.skin}
            shape={piece.shape}
            color={piece.vivid}
            width={piece.width}
            height={piece.height}
            className="absolute inset-0 w-full h-full pointer-events-none"
            style={{
              // 变暗 + 去饱和 + 转灰 + 略微透明（照设计稿"暗沉下去"的效果）
              filter: `${fadeFilter} opacity(${fadeAlpha})`,
            }}
          />
          {/* 名称 + 徽章：代码层渲染（插画里不烤字）。照设计稿：名称与徽章保持深色清晰，不随插画褪色 */}
          <div
            className="absolute flex items-center"
            style={{
              left: 11 * Math.min(piece.scale, 1.15),
              top: 6 * Math.min(piece.scale, 1.15),
              gap: 5,
              maxWidth: w - 18,
            }}
          >
            <span
              style={{
                color: COFFEE,
                fontSize: 11,
                fontWeight: 400,
                letterSpacing: 0,
                whiteSpace: "nowrap",
                minWidth: 0,
                overflow: "hidden",
                textOverflow: "ellipsis",
              }}
            >
              {piece.name}
            </span>
            {piece.lastDays >= 14 && w >= 130 && h >= 70 && (() => {
              // 照设计稿：15天档 = 浅底橙字，30天档 = 粉底红字
              const bad = piece.lastDays >= 30;
              const tone = bad ? "#D9534C" : "#E08A3C";
              return (
              <span
                className="flex items-center"
                style={{
                  gap: 3,
                  backgroundColor: rgba(tone, bad ? 0.18 : 0.15),
                  borderRadius: 999,
                  padding: `${2.5 * piece.scale}px ${6 * piece.scale}px`,
                  fontSize: 10.5 * Math.min(piece.scale, 1.15),
                  fontWeight: 600,
                  color: tone,
                  whiteSpace: "nowrap",
                  flexShrink: 0,
                }}
              >
                <Trash2 size={9.5} color={tone} strokeWidth={2.2} />
                {piece.lastDays}天未维护
              </span>
              );
            })()}
          </div>
          {/* 30 天以上：卡面中央盖大号红色感叹号（照设计稿） */}
          {piece.lastDays >= 30 && (
            <div
              className="absolute flex items-center justify-center pointer-events-none"
              style={{
                left: "50%",
                top: "52%",
                transform: "translate(-50%, -50%)",
                width: Math.min(46 * Math.min(piece.scale, 1.15), Math.min(w, h) * 0.55),
                height: Math.min(46 * Math.min(piece.scale, 1.15), Math.min(w, h) * 0.55),
                borderRadius: "50%",
                backgroundColor: "rgba(255,255,255,0.92)",
                boxShadow: "0 2px 10px rgba(120,30,20,0.18)",
              }}
            >
              <CircleAlert size={Math.min(34 * Math.min(piece.scale, 1.15), Math.min(w, h) * 0.4)} color="#A83226" strokeWidth={2.1} />
            </div>
          )}
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
              onPointerCancel={rUp}
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
  isPresentationMode,
  selectedSpaceID,
  onNativeChange,
}: {
  onReshoot?: (mode: "compare" | "same" | "new", space?: { id: string; name: string; vivid: string }) => void;
  scanDone?: boolean;
  onScanAck?: () => void;
  onRelightRequest?: (id: string, name: string, vivid: string) => void;
  relitSpaceId?: string | null;
  onRelitAck?: () => void;
  nativeSpaces?: NativeSpace[];
  isPresentationMode?: boolean;
  selectedSpaceID?: string;
  onNativeChange?: () => void;
} = {}) {
  const layoutKey = isPresentationMode ? `${LAYOUT_KEY}:presentation` : LAYOUT_KEY;
  const [pieces, setPieces] = useState<Piece[]>(() => nativeSpaces ? nativePieces(nativeSpaces, [], layoutKey) : window.webkit?.messageHandlers?.smartpaw ? [] : previewPieces(layoutKey));
  const [localSpaces, setLocalSpaces] = useState(nativeSpaces);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const mutating = useRef(false);
  const [selected, setSelected] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);
  const [renaming, setRenaming] = useState(false);
  const [draft, setDraft] = useState("");
  const [reward, setReward] = useState<Piece | null>(null);
  const [bornId, setBornId] = useState<string | null>(null);
  const [bornPos, setBornPos] = useState<{ cx: number; cy: number } | null>(null);
  const [openProgress, setOpenProgress] = useState<string | null>(null);
  const [retidy, setRetidy] = useState(false);
  const [artDraft, setArtDraft] = useState<Piece | null>(null);
  const [relitId, setRelitId] = useState<string | null>(null);
  const boardRef = useRef<HTMLDivElement>(null);

  useEffect(() => { setArtDraft(null); }, [selected]);

  useEffect(() => {
    setLocalSpaces(nativeSpaces);
    if (nativeSpaces) setPieces((previous) => nativePieces(nativeSpaces, previous, layoutKey));
  }, [nativeSpaces, layoutKey]);

  useEffect(() => {
    const board = boardRef.current;
    if (!board) return;
    const fitPieces = () => {
      if (!board.clientWidth || !board.clientHeight) return;
      setPieces((previous) => {
        let changed = false;
        const fitted = previous.map((piece) => {
          const layout = normalizeSpaceLayout(piece, piece, { width: board.clientWidth, height: board.clientHeight });
          if (!(Object.keys(layout) as (keyof SpaceLayout)[]).some((key) => layout[key] !== piece[key])) return piece;
          changed = true;
          return { ...piece, ...layout };
        });
        return changed ? fitted : previous;
      });
    };
    // Restored coordinates were created on a 358px board. Fit them to the
    // actual board when spaces arrive and whenever the viewport changes.
    fitPieces();
    const observer = new ResizeObserver(fitPieces);
    observer.observe(board);
    return () => observer.disconnect();
  }, [nativeSpaces, layoutKey, openProgress]);

  useEffect(() => {
    try {
      const layouts = savedLayouts(layoutKey);
      pieces.forEach(({ id, x, y, rot, scale, vivid, skin, shape, width, height }) => { layouts[id] = { x, y, rot, scale, vivid, skin, shape, width, height }; });
      localStorage.setItem(layoutKey, JSON.stringify(layouts));
    } catch { /* A full or unavailable web store must not block native spaces. */ }
  }, [pieces, layoutKey]);

  // The native completion already saved this space. Reuse it for the reward
  // rather than creating an unrelated, randomly named second space.
  useEffect(() => {
    if (!scanDone) return;
    let cancelled = false;
    void nativeRequest<NativeState>("state.get").then((state) => {
      if (cancelled) return;
      const updatedPieces = nativePieces(state.spaces, pieces, layoutKey);
      setLocalSpaces(state.spaces);
      setPieces(updatedPieces);
      const completed = state.spaces.find((space) => space.id === state.selectedSpaceID);
      if (completed?.completedPlans.length) setReward(updatedPieces.find((piece) => piece.id === completed.id) ?? null);
    }).catch((cause) => {
      if (!cancelled) setError(cause instanceof Error ? cause.message : "无法读取刚完成的空间，请重试。");
    }).finally(() => { if (!cancelled) onScanAck?.(); });
    return () => { cancelled = true; };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scanDone]);

  const updateNativeState = (state: NativeState) => {
    setLocalSpaces(state.spaces);
    setPieces((previous) => nativePieces(state.spaces, previous, layoutKey));
    onNativeChange?.();
  };

  const mutate = async (operation: () => Promise<void>) => {
    if (mutating.current) return;
    mutating.current = true; setBusy(true); setError("");
    try { await operation(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : "操作保存失败，请重试。"); }
    finally { mutating.current = false; setBusy(false); }
  };

  const selectSpace = async (id: string) => {
    if (!localSpaces) return;
    updateNativeState(await nativeRequest<NativeState>("space.select", { id }));
  };

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
    void mutate(async () => {
      const target = current ?? pieces.find((piece) => piece.id === selectedSpaceID);
      if (target) await selectSpace(target.id);
      setRetidy(false); setSelected(null);
      onReshoot?.(mode, target ? { id: target.id, name: target.name, vivid: target.vivid } : undefined);
    });
  }

  const current = pieces.find((p) => p.id === selected) ?? null;
  const currentNative = localSpaces?.find((space) => space.id === selected);
  const toDelete = pieces.find((p) => p.id === confirmDelete) ?? null;
  const progressSpaces = (localSpaces ?? []).filter((space) => space.activePlan);
  const hasCompletedOrganization = (localSpaces ?? []).some((space) => space.completedPlans.length > 0 || Number.isFinite(Date.parse(space.lastOrganizedAt ?? "")));
  const progressSpace = progressSpaces.find((space) => space.id === selectedSpaceID) ?? progressSpaces[0];
  const progressPlan = progressSpace?.activePlan;
  const progress = progressPlan?.steps.length ? Math.round(progressPlan.steps.filter((step) => step.status === "done").length / progressPlan.steps.length * 100) : 0;
  const detailSpace = localSpaces?.find((space) => space.id === openProgress);

  function handleRelight() {
    if (!current) return;
    void mutate(async () => {
      await selectSpace(current.id);
      setSelected(null); setRetidy(false);
      onRelightRequest?.(current.id, current.name, current.vivid);
    });
  }

  if (detailSpace) {
    return <InProgressDetail onBack={() => setOpenProgress(null)} space={detailSpace} onNativeChange={updateNativeState} />;
  }

  function claimReward() {
    if (!reward) return;
    const { width: w, height: h } = spaceFootprint(reward);
    setBornPos({ cx: reward.x + w / 2, cy: reward.y + h / 2 });
    setBornId(reward.id);
    setReward(null);
    setTimeout(() => setBornPos(null), 2200);
  }

  function patch(id: string, d: Partial<Piece>) {
    const board = boardRef.current;
    setPieces((prev) => prev.map((p) => (p.id === id ? {
      ...p, ...d,
      ...normalizeSpaceLayout({ ...p, ...d }, p, board ? { width: board.clientWidth, height: board.clientHeight } : undefined),
    } : p)));
  }

  function editArtwork(piece: Piece) {
    setRenaming(false);
    setArtDraft({ ...piece });
  }

  function draftArtwork(change: Partial<Piece>) {
    setArtDraft((previous) => previous ? { ...previous, ...change } : previous);
  }

  function chooseTemplate(skin: SpaceKind) {
    const template = SPACE_TEMPLATES[skin];
    draftArtwork({ skin, shape: "original", width: template.w, height: template.h, vivid: template.color, scale: 1 });
  }

  function resetArtwork() {
    if (!artDraft) return;
    const template = SPACE_TEMPLATES[artDraft.skin];
    draftArtwork({ shape: "original", width: template.w, height: template.h, vivid: template.color, rot: 0, scale: 1 });
  }

  function saveArtwork() {
    if (!artDraft) return;
    const board = boardRef.current;
    const layout = normalizeSpaceLayout(artDraft, artDraft, board ? { width: board.clientWidth, height: board.clientHeight } : undefined);
    try {
      const layouts = savedLayouts(layoutKey);
      layouts[artDraft.id] = layout;
      localStorage.setItem(layoutKey, JSON.stringify(layouts));
    } catch {
      setError("图案暂时无法保存，请腾出存储空间后重试。");
      return;
    }
    setError("");
    patch(artDraft.id, layout);
    setArtDraft(null);
  }

  function saveName() {
    const name = draft.trim();
    setRenaming(false);
    if (!current || !name || name === current.name) return;
    void mutate(async () => {
      if (!localSpaces) { patch(current.id, { name }); return; }
      updateNativeState(await nativeRequest<NativeState>("space.rename", { id: current.id, name }));
    });
  }

  function reviewNow() {
    if (!current) return;
    void mutate(async () => {
      await selectSpace(current.id);
      setSelected(null);
      if (currentNative?.activePlan) setOpenProgress(current.id);
      else onReshoot?.("same");
    });
  }

  function doDelete() {
    if (!confirmDelete) return;
    const id = confirmDelete;
    void mutate(async () => {
      if (localSpaces) updateNativeState(await nativeRequest<NativeState>("space.delete", { id }));
      else setPieces((previous) => previous.filter((piece) => piece.id !== id));
      setConfirmDelete(null); setEditingId(null);
      if (selected === id) setSelected(null);
    });
  }

  return (
    <div className="h-full w-full overflow-y-auto pb-32" style={{ backgroundColor: LINEN }}>
      {/* header — quiet */}
      <div className="px-6 pt-14 pb-1 flex items-end justify-between">
        <div>
          <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>我的家</p>
          <h1 style={{ color: COFFEE, fontSize: 25, fontWeight: 700, letterSpacing: 0 }}>空间地图</h1>
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

      {error && <p role="alert" className="mx-6 mt-3" style={{ color: "#9A4230", fontSize: 12 }}>{error}</p>}

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
              key={`${p.id}:${bornId === p.id ? "born" : "settled"}`}
              piece={p}
              boardRef={boardRef}
              editing={editingId === p.id}
              born={bornId === p.id}
              relit={relitId === p.id}
              onOpen={() => { setSelected(p.id); setRenaming(false); void mutate(() => selectSpace(p.id)); }}
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
              onClick={() => reshoot("compare")}
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
              onClick={() => reshoot("new")}
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
          onClick={() => progressSpace ? void mutate(async () => { await selectSpace(progressSpace.id); setOpenProgress(progressSpace.id); }) : reshoot("new")}
          className="w-full flex items-center gap-3.5 p-3 text-left active:scale-[0.99] transition-transform"
          style={{ backgroundColor: WHITE, borderRadius: 22, boxShadow: "0 2px 12px rgba(90,70,55,0.05)" }}
        >
          <div className="h-12 w-12 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ backgroundColor: BLUE }}>
            <Play size={18} color={WHITE} fill={WHITE} />
          </div>
          <div className="flex-1">
            <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>{progressSpace ? `${progressSpace.name} · ${progressPlan?.isPaused ? "已暂停" : progress === 100 ? "待保存完成照" : "正在进行中"}` : hasCompletedOrganization ? "开始下一次整理" : "开始第一次整理"}</p>
            <div className="flex items-center gap-2 mt-1.5">
              <div className="flex-1 h-1.5 rounded-full" style={{ backgroundColor: LINEN }}>
                <div style={{ width: `${progress}%`, height: "100%", backgroundColor: ORANGE, borderRadius: 999 }} />
              </div>
              <span style={{ color: COFFEE, opacity: 0.6, fontSize: 11 }}>{progress}%</span>
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
              className="absolute inset-0 z-[55]" style={{ backgroundColor: "rgba(42,32,26,0.32)" }}
            />
            <motion.div
              initial={{ y: "100%" }} animate={{ y: 0 }} exit={{ y: "100%" }}
              transition={{ type: "spring", stiffness: 320, damping: 32 }}
              className="absolute left-0 right-0 bottom-0 z-[60] max-h-[90%] overflow-y-auto px-6 pt-3 pb-8"
              style={{ backgroundColor: WHITE, borderTopLeftRadius: 30, borderTopRightRadius: 30 }}
            >
              <div className="mx-auto mb-4 rounded-full" style={{ width: 40, height: 4, backgroundColor: SOFT }} />
              {error && <p role="alert" className="mb-3" style={{ color: "#9A4230", fontSize: 12 }}>{error}</p>}
              <div className="flex items-center gap-3.5">
                <ArtworkThumbnail piece={current} size={56} />
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
                    {current.items} 件物品 · {current.organized === false ? "等待首次整理" : current.lastDays === 0 ? "刚刚整理" : `${current.lastDays} 天前整理`}
                  </p>
                </div>
                <button onClick={() => setSelected(null)} className="h-9 w-9 rounded-full flex items-center justify-center flex-shrink-0" style={{ backgroundColor: LINEN }}>
                  <X size={18} color={COFFEE} />
                </button>
              </div>

              <button
                onClick={() => editArtwork(current)}
                className="w-full mt-4 flex items-center gap-2.5 py-3 text-left"
                style={{ color: COFFEE, borderBottom: `1px solid ${SOFT}`, fontSize: 13 }}
              >
                <SlidersHorizontal size={17} strokeWidth={1.8} />
                <span className="flex-1">调整图案</span>
                <span style={{ opacity: 0.5, fontSize: 12 }}>{SPACE_TEMPLATES[current.skin].label}</span>
                <ChevronRight size={16} style={{ opacity: 0.4 }} />
              </button>

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
                {(current.organized === false ? [{ t: "等待整理", s: currentNative?.activePlan ? "整理计划已保存，可继续上次进度" : "拍摄这个空间，开始首次整理" }] : [
                  { t: current.lastDays === 0 ? "今天" : current.lastDays + " 天前", s: "完成整理,收纳 " + current.items + " 件物品" },
                  { t: "获得拼图", s: `“${current.name}”加入了空间地图` },
                ]).map((r, i) => (
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

      <AnimatePresence>
        {artDraft && current?.id === artDraft.id && (
          <>
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => setArtDraft(null)} className="absolute inset-0 z-[85]" style={{ backgroundColor: "rgba(42,32,26,0.4)" }} />
            <motion.div
              role="dialog" aria-modal="true" aria-label={`调整${current.name}的图案`}
              initial={{ y: "100%" }} animate={{ y: 0 }} exit={{ y: "100%" }}
              transition={{ type: "spring", stiffness: 320, damping: 32 }}
              className="absolute left-0 right-0 bottom-0 z-[90] max-h-[92%] flex flex-col"
              style={{ backgroundColor: WHITE, borderTopLeftRadius: 26, borderTopRightRadius: 26 }}
            >
              <div className="px-5 pt-3 pb-2 flex-shrink-0">
                <div className="mx-auto mb-3 rounded-full" style={{ width: 40, height: 4, backgroundColor: SOFT }} />
                <div className="flex items-center justify-between">
                  <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>调整图案</p>
                  <button aria-label="取消调整" title="取消调整" onClick={() => setArtDraft(null)} className="h-8 w-8 flex items-center justify-center" style={{ color: COFFEE }}><X size={19} /></button>
                </div>
              </div>
              <div className="overflow-y-auto px-5 pb-4" style={{ color: COFFEE }}>
                {error && <p role="alert" className="mb-3" style={{ color: "#9A4230", fontSize: 12 }}>{error}</p>}
                <div className="flex items-center justify-center mb-3" style={{ height: 112, backgroundColor: LINEN, borderRadius: 8 }}>
                  <ArtworkThumbnail piece={artDraft} size={96} />
                </div>
                <p className="mb-2" style={{ fontSize: 12, opacity: 0.65 }}>空间类型</p>
                <div className="grid grid-cols-4 gap-2">
                  {SPACE_KINDS.map((kind) => {
                    const template = SPACE_TEMPLATES[kind];
                    const active = artDraft.skin === kind;
                    return (
                      <button key={kind} onClick={() => chooseTemplate(kind)} aria-pressed={active}
                        className="flex flex-col items-center justify-center gap-1"
                        style={{ height: 68, borderRadius: 8, border: `1.5px solid ${active ? ORANGE : SOFT}`, backgroundColor: active ? "#FFF5EC" : WHITE }}>
                        <SpaceArtwork kind={kind} width={template.w} height={template.h} style={{ width: 44, height: 36 }} />
                        <span style={{ fontSize: 11.5, lineHeight: 1.2 }}>{template.label}</span>
                      </button>
                    );
                  })}
                </div>
                <div className="flex items-center justify-between mt-4 mb-2">
                  <label htmlFor="space-art-shape" style={{ fontSize: 12, opacity: 0.65 }}>外形</label>
                  <select id="space-art-shape" value={artDraft.shape} onChange={(event) => draftArtwork({ shape: event.target.value as SpaceShape })}
                    style={{ color: COFFEE, fontSize: 13, backgroundColor: LINEN, borderRadius: 6, padding: "7px 28px 7px 10px", border: `1px solid ${SOFT}` }}>
                    <option value="original">原始形状</option><option value="rectangle">矩形</option><option value="rounded">圆角矩形</option><option value="circle">椭圆形</option><option value="lshape">L 形</option>
                  </select>
                </div>
                {([{ key: "width", label: "宽度", base: SPACE_TEMPLATES[artDraft.skin].w }, { key: "height", label: "高度", base: SPACE_TEMPLATES[artDraft.skin].h }] as const).map(({ key, label, base }) => (
                  <label key={key} className="flex items-center gap-3 py-2.5" style={{ fontSize: 12 }}>
                    <span style={{ width: 28, opacity: 0.65 }}>{label}</span>
                    <input type="range" aria-label={`图案${label}`} min={56} max={240} step={1} value={artDraft[key]}
                      onChange={(event) => draftArtwork({ [key]: Number(event.target.value) })} className="flex-1 min-w-0" style={{ accentColor: ORANGE }} />
                    <output style={{ width: 38, textAlign: "right", fontVariantNumeric: "tabular-nums" }}>{Math.round(artDraft[key] / base * 100)}%</output>
                  </label>
                ))}
                <div className="flex items-center justify-between mt-2">
                  <span style={{ fontSize: 12, opacity: 0.65 }}>方向</span>
                  <div className="flex gap-1" role="group" aria-label="图案方向">
                    {[0, 90, 180, 270].map((rot) => (
                      <button key={rot} onClick={() => draftArtwork({ rot })} aria-label={`旋转${rot}度`} aria-pressed={artDraft.rot === rot}
                        className="flex flex-col items-center justify-center gap-0.5"
                        style={{ width: 48, height: 42, borderRadius: 6, backgroundColor: artDraft.rot === rot ? LINEN : "transparent", color: COFFEE }}>
                        <RotateCw size={15} style={{ transform: `rotate(${rot}deg)` }} /><span style={{ fontSize: 10.5 }}>{rot}°</span>
                      </button>
                    ))}
                  </div>
                </div>
                <div className="flex items-center gap-1.5 mt-4">
                  <span className="flex-shrink-0" style={{ color: COFFEE, opacity: 0.65, fontSize: 12, width: 24 }}>配色</span>
                  {[SPACE_TEMPLATES[artDraft.skin].color, ...PALETTE].map((color, index) => (
                    <button key={`${color}:${index}`} onClick={() => draftArtwork({ vivid: color })} aria-label={index === 0 ? "原始配色" : `配色 ${color}`} title={index === 0 ? "原始配色" : `配色 ${index}`}
                      className="rounded-full flex-shrink-0" style={{ width: 22, height: 22, backgroundColor: color, boxShadow: artDraft.vivid.toLowerCase() === color.toLowerCase() ? `0 0 0 2px ${WHITE}, 0 0 0 3px ${COFFEE}` : "inset 0 0 0 1px rgba(90,70,55,0.1)" }} />
                  ))}
                </div>
                <button onClick={resetArtwork} className="mt-4 flex items-center gap-1.5 py-1" style={{ color: COFFEE, opacity: 0.65, fontSize: 12 }}><Undo2 size={14} />重置当前图案</button>
              </div>
              <div className="px-5 py-4 flex gap-3 flex-shrink-0" style={{ borderTop: `1px solid ${SOFT}` }}>
                <button onClick={() => setArtDraft(null)} className="flex-1 py-3" style={{ color: COFFEE, backgroundColor: LINEN, borderRadius: 8, fontSize: 14 }}>取消</button>
                <button onClick={saveArtwork} className="flex-1 py-3 flex items-center justify-center gap-1.5" style={{ color: WHITE, backgroundColor: ORANGE, borderRadius: 8, fontSize: 14, fontWeight: 600 }}><Check size={16} />保存</button>
              </div>
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
                {error && <p role="alert" className="mt-3" style={{ color: "#9A4230", fontSize: 12 }}>{error}</p>}
              </div>
              <div className="grid grid-cols-2" style={{ borderTop: "1px solid rgba(90,70,55,0.12)" }}>
                <button
                  onClick={() => setConfirmDelete(null)}
                  className="py-3.5 active:bg-black/5"
                  style={{ color: COFFEE, fontSize: 15, fontWeight: 600, borderRight: "1px solid rgba(90,70,55,0.12)" }}
                >
                  取消
                </button>
                <button disabled={busy} onClick={doDelete} className="py-3.5 active:bg-black/5" style={{ color: "#C25C43", fontSize: 15, fontWeight: 700 }}>
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
                  className="absolute inset-0 flex items-center justify-center overflow-hidden"
                  style={{
                    width: 96, height: 96, margin: "auto",
                    filter: "drop-shadow(0 8px 16px rgba(90,70,55,0.2))",
                  }}
                >
                  <ArtworkThumbnail piece={reward} size={96} />
                </motion.div>
              </div>

              <p style={{ color: ORANGE, fontSize: 12, fontWeight: 700, letterSpacing: 0 }}>点亮了一块新空间</p>
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
