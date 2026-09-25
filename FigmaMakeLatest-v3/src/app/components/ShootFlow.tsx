import { useState, useRef, useEffect } from "react";
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
import { motion, AnimatePresence } from "motion/react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { Raccoon } from "./Raccoon";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { nativeRequest, type NativeState, type NativeItem } from "../nativeBridge";

const ROOM_IMG =
  "https://images.unsplash.com/photo-1768548273848-ebab6f26b48c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080";
const THUMB_IMG =
  "https://images.unsplash.com/photo-1764588037085-a78240016f8b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400";

type Step =
  | "capture"
  | "review"
  | "confirm"
  | "generating"
  | "plandeck"
  | "tune"
  | "zones"
  | "arPreview"
  | "tools"
  | "arGuide"
  | "task"
  | "reward";

type PlanTier = "basic" | "smart" | "pro";

export type CapturedAsset =
  | { id: string; kind: "photo"; src: string; label: string }
  | { id: string; kind: "video"; src: string; label: string; duration: number };

// A finished-room concept the AI proposes right after the shoot.
export type GenPlan = {
  id: string;
  name: string;
  vibe: string;
  image: string;
  accent: string;
  tags: string[];
  changes: string[];
  minutes: number;
  tier: PlanTier;
};

const GEN_PLANS: GenPlan[] = [
  {
    id: "breathe",
    name: "舒适留白",
    vibe: "减少视觉杂乱，让常用物品保持易取",
    image:
      "https://images.unsplash.com/photo-1586023492125-27b2c045efd7?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    accent: "#E29B7B",
    tags: ["易上手", "清爽", "舒适"],
    changes: [
      "台面只保留每天使用的 3 件物品",
      "闲置物品分类归入储物区",
      "开放区域适量留白，减少视觉压迫",
    ],
    minutes: 25,
    tier: "basic",
  },
  {
    id: "efficient",
    name: "高效收纳",
    vibe: "最大化利用垂直与隐藏空间",
    image:
      "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    accent: "#7FB0AA",
    tags: ["高效", "分区", "最大化"],
    changes: [
      "垂直空间安装层架，释放地面面积",
      "按使用频率分三区收纳，常用物触手可及",
      "抽屉加装分隔件，建立固定归位习惯",
    ],
    minutes: 40,
    tier: "smart",
  },
  {
    id: "living",
    name: "生活感",
    vibe: "保留日常物品的可见性，让空间更有生活痕迹",
    image:
      "https://images.unsplash.com/photo-1556912998-c57cc6b63cd7?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    accent: "#A6B2D6",
    tags: ["随性", "温馨", "有机"],
    changes: [
      "常用物品保持开放可见，方便随手取放",
      "软装与绿植点缀增加生活气息",
      "以区域功能为主，不强求分类精确",
    ],
    minutes: 20,
    tier: "basic",
  },
];

// 每个分类给三条风格不同的建议，用来替换方案卡里的文案。
// 只换文字和时长，卡片的名字、配色、标签、配图一律保持设计稿原样。
const PLAN_CATEGORY_ADVICE: Record<string, { breathe: string; efficient: string; living: string }> = {
  "书籍": {
    breathe: "台面只留下正在读的几本，其余收进书架",
    efficient: "按开本高度分层，常翻的一层与视线齐平",
    living: "常翻的书摊开摆放，让阅读痕迹留在手边",
  },
  "电子产品": {
    breathe: "线缆收进理线盒，台面只留一块充电位",
    efficient: "设备统一进充电站，线材贴标签固定走位",
    living: "常用设备留在桌面顺手处，不必刻意藏起来",
  },
  "文具": {
    breathe: "笔筒只留常写的三支，其余进抽屉",
    efficient: "抽屉加分隔件，按用途分成固定格位",
    living: "好看的文具摆在桌面上，就当桌面风景",
  },
  "衣物": {
    breathe: "当季外穿的挂起来，换季的压缩收进柜顶",
    efficient: "按穿着频率分三区，常穿的挂最外层",
    living: "常穿的外套搭在挂钩上，随手就能拿",
  },
  "玩偶杂物": {
    breathe: "只展示最喜欢的两三个，其余收进箱子",
    efficient: "按尺寸分层收纳，小件统一进透明盒",
    living: "玩偶留在床头或沙发上，保留生活气息",
  },
  "待丢弃": {
    breathe: "先清出明确不要的，空间立刻轻一截",
    efficient: "设一个暂存箱，攒满一批再一次性处理",
    living: "有感情的小物件留一件，其余放手",
  },
  "收纳工具": {
    breathe: "收纳盒本身也要精简，别为收纳再买收纳",
    efficient: "统一盒型与标签，堆叠时不会东倒西歪",
    living: "用顺眼的篮子装，随手一放也算整齐",
  },
};

function personalizePlans(items: NativeItem[]): GenPlan[] {
  if (!items || items.length === 0) return GEN_PLANS;

  const byCategory = new Map<string, number>();
  for (const item of items) {
    const key = item.category || "收纳工具";
    byCategory.set(key, (byCategory.get(key) ?? 0) + 1);
  }
  const ranked = [...byCategory.entries()].sort((a, b) => b[1] - a[1]);
  const top = ranked[0]?.[0] ?? "收纳工具";
  const second = ranked[1]?.[0] ?? top;
  const advice = (key: string) => PLAN_CATEGORY_ADVICE[key] ?? PLAN_CATEGORY_ADVICE["收纳工具"];
  const a1 = advice(top);
  const a2 = ranked.length > 1 ? advice(second) : null;
  // 时长跟着物品量走：东西越多越久，但不低于 15 分钟、不超过一小时。
  const scale = (base: number) => Math.min(60, Math.max(15, Math.round((base + items.length * 2) / 5) * 5));

  return GEN_PLANS.map((plan) => {
    const minutes = scale(plan.minutes);
    if (plan.id === "breathe") {
      return {
        ...plan,
        changes: [
          a1.breathe,
          a2 ? `其次是${second}：${a2.breathe}` : "闲置物品分类归入储物区",
          "开放区域留出空白，减少视觉压迫",
        ],
        minutes,
      };
    }
    if (plan.id === "efficient") {
      return {
        ...plan,
        changes: [
          "垂直空间加层架，把地面面积让出来",
          a1.efficient,
          a2 ? a2.efficient : "抽屉加装分隔件，建立固定归位习惯",
        ],
        minutes,
      };
    }
    return {
      ...plan,
      changes: [
        a1.living,
        "软装与绿植点缀，让空间有生活痕迹",
        a2 ? a2.living : "以区域功能为主，不强求分类精确",
      ],
      minutes,
    };
  });
}

export function ShootFlow({
  onClose,
  onFinish,
}: {
  onClose: () => void;
  onFinish?: () => void;
}) {
  const [step, setStep] = useState<Step>("capture");
  const [assets, setAssets] = useState<CapturedAsset[]>([]);
  const [plans, setPlans] = useState<GenPlan[]>(GEN_PLANS);
  const [chosen, setChosen] = useState<GenPlan>(GEN_PLANS[0]);
  // where the generating animation should land when it finishes
  const [genReturn, setGenReturn] = useState<Step>("plandeck");

  // 生成方案前重新拉一次识别结果，让方案卡里的建议跟着这次拍到的物品走。
  const refreshPlans = async () => {
    try {
      const state = await nativeRequest<NativeState>("state.get");
      setPlans(personalizePlans(state?.scannedItems ?? []));
    } catch {
      setPlans(GEN_PLANS);
    }
  };

  const tier = chosen.tier;

  return (
    <div className="absolute inset-0 z-50" style={{ backgroundColor: LINEN }}>
      {step === "capture" && (
        <CaptureStep
          onClose={onClose}
          on完成={(captured) => {
            setAssets(captured);
            setGenReturn("plandeck");
            // 设计稿流程：拍完先看照片，再确认识别出的物品，最后才生成方案。
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
        <ConfirmStep
          assets={assets}
          onBack={() => setStep("review")}
          onNext={() => {
            void refreshPlans().finally(() => {
              setGenReturn("plandeck");
              setStep("generating");
            });
          }}
        />
      )}
      {step === "generating" && (
        <GeneratingStep onDone={() => setStep(genReturn)} />
      )}
      {step === "plandeck" && (
        <PlanDeckStep
          plans={plans}
          onClose={onClose}
          onStart={async (p) => {
            setChosen(p);
            try {
              await nativeRequest("plan.generate", {
                style: p.id === "efficient" ? "隐藏清爽" : p.id === "living" ? "温暖可见" : "快速复原",
                minutes: p.minutes <= 5 ? 5 : p.minutes >= 60 ? 60 : 10,
                goal: p.vibe,
                focusZone: "",
              });
            } catch { /* The local UI remains usable and shows native errors at capture time. */ }
            setStep("zones");
          }}
          onTune={(p) => {
            setChosen(p);
            setStep("tune");
          }}
        />
      )}
      {step === "tune" && (
        <TuneChatStep
          plan={chosen}
          onBack={() => setStep("plandeck")}
          onConfirm={(refined) => {
            setChosen(refined);
            setStep("zones");
          }}
        />
      )}
      {step === "zones" && (
        <ZoneSelectStep
          onBack={() => setStep("plandeck")}
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
          onComplete={() => {
            void completeNativePlan().finally(() => setStep("reward"));
          }}
        />
      )}
      {step === "reward" && <RewardStep onClose={onFinish || onClose} />}
    </div>
  );
}

/* ---------- 1.5 AI space-analysis transition ---------- */

const GEN_FURN = [
  { cx: 100, cy: 176, hw: 40, hh: 19, h: 17, label: "沙发" },
  { cx: 202, cy: 150, hw: 23, hh: 13, h: 27, label: "书架" },
  { cx: 152, cy: 202, hw: 16, hh: 9,  h: 9,  label: "茶几" },
];

function isoBox(f: { cx: number; cy: number; hw: number; hh: number; h: number }) {
  const { cx, cy, hw, hh, h } = f;
  const top = `M${cx},${cy - hh - h} L${cx + hw},${cy - h} L${cx},${cy + hh - h} L${cx - hw},${cy - h} Z`;
  const verts = `M${cx - hw},${cy} L${cx - hw},${cy - h} M${cx},${cy + hh} L${cx},${cy + hh - h} M${cx + hw},${cy} L${cx + hw},${cy - h}`;
  const base = `M${cx - hw},${cy} L${cx},${cy + hh} L${cx + hw},${cy}`;
  return { top, verts, base };
}

const GEN_PHASES = [
  { main: "正在理解你的空间", sub: "" },
  { main: "识别家具与物品", sub: "发现 3 件家具 · 5 个物品" },
  { main: "正在规划整理方式", sub: "为你生成专属方案" },
];

// Warm line colors for the generating screen
const W_LINE = "rgba(123,92,72,0.44)";
const W_SOFT = "rgba(123,92,72,0.24)";
const W_GHOST = "rgba(123,92,72,0.07)";

async function completeNativePlan() {
  let state = await nativeRequest<NativeState>("state.get");
  let selected = state.spaces.find((space) => space.id === state.selectedSpaceID);
  for (let guard = 0; guard < 100; guard += 1) {
    const active = selected?.activePlan?.steps.find((step) => step.status === "active");
    if (!active) break;
    state = await nativeRequest<NativeState>("plan.step.complete", { id: active.id });
    selected = state.spaces.find((space) => space.id === state.selectedSpaceID);
  }
}

function GeneratingStep({ onDone }: { refining?: boolean; onDone: () => void }) {
  const [phase, setPhase] = useState(0);

  useEffect(() => {
    const t1 = setTimeout(() => setPhase(1), 1550);
    const t2 = setTimeout(() => setPhase(2), 2950);
    const done = setTimeout(onDone, 4600);
    return () => {
      clearTimeout(t1);
      clearTimeout(t2);
      clearTimeout(done);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const current = GEN_PHASES[phase];

  return (
    <div
      className="h-full w-full flex flex-col items-center justify-center relative overflow-hidden"
      style={{ background: "radial-gradient(140% 110% at 50% 30%, #FDFCFA 0%, #F0E9DF 100%)" }}
    >
      {/* Soft ambient blobs in background */}
      {([
        { x: 55,  y: 620, r: 90,  c: "rgba(250,136,58,0.07)" },
        { x: 340, y: 180, r: 70,  c: "rgba(180,199,220,0.10)" },
        { x: 200, y: 700, r: 110, c: "rgba(250,136,58,0.05)" },
      ] as { x:number; y:number; r:number; c:string }[]).map((b, i) => (
        <motion.div
          key={i}
          className="absolute rounded-full pointer-events-none"
          style={{ left: b.x - b.r, top: b.y - b.r, width: b.r * 2, height: b.r * 2, backgroundColor: b.c }}
          animate={{ scale: [1, 1.14, 1], opacity: [0.6, 1, 0.6] }}
          transition={{ duration: 4 + i * 1.2, repeat: Infinity, ease: "easeInOut", delay: i * 0.5 }}
        />
      ))}

      {/* Isometric room SVG — warm & cozy */}
      <motion.div
        initial={{ opacity: 0, y: 10, scale: 0.97 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ duration: 0.9, ease: [0.22, 1, 0.36, 1] }}
        style={{ width: 300, height: 274, position: "relative", zIndex: 1 }}
      >
        <svg width={300} height={274} viewBox="0 0 300 274" style={{ overflow: "visible" }}>
          <defs>
            <filter id="gen-bloom" x="-55%" y="-55%" width="210%" height="210%">
              <feGaussianBlur stdDeviation="9" />
            </filter>
            <linearGradient id="gen-scan" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%"   stopColor={ORANGE} stopOpacity="0" />
              <stop offset="42%"  stopColor={ORANGE} stopOpacity="0.10" />
              <stop offset="58%"  stopColor={ORANGE} stopOpacity="0.10" />
              <stop offset="100%" stopColor={ORANGE} stopOpacity="0" />
            </linearGradient>
            <linearGradient id="gen-scanline" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%"   stopColor={ORANGE} stopOpacity="0" />
              <stop offset="28%"  stopColor={ORANGE} stopOpacity="0.58" />
              <stop offset="72%"  stopColor={ORANGE} stopOpacity="0.58" />
              <stop offset="100%" stopColor={ORANGE} stopOpacity="0" />
            </linearGradient>
          </defs>

          {/* Zone bloom halos — phase 2, warm soft glow */}
          <g filter="url(#gen-bloom)">
            <motion.ellipse
              cx={100} cy={180} rx={52} ry={23} fill={ORANGE}
              initial={{ opacity: 0 }}
              animate={{ opacity: phase >= 2 ? 0.22 : 0 }}
              transition={{ duration: 1.1, ease: "easeOut" }}
            />
            <motion.ellipse
              cx={200} cy={152} rx={33} ry={15} fill={BLUE}
              initial={{ opacity: 0 }}
              animate={{ opacity: phase >= 2 ? 0.26 : 0 }}
              transition={{ duration: 1.1, delay: 0.28, ease: "easeOut" }}
            />
          </g>

          {/* Soft rug under table */}
          <motion.ellipse
            cx={152} cy={212} rx={32} ry={13}
            fill="rgba(180,199,220,0.28)"
            initial={{ opacity: 0 }}
            animate={{ opacity: phase >= 1 ? 1 : 0 }}
            transition={{ delay: 1.9, duration: 0.6, ease: "easeOut" }}
          />

          {/* Floor diamond */}
          <motion.path
            d="M150,92 L262,154 L150,216 L38,154 Z"
            fill={W_GHOST}
            stroke={W_LINE}
            strokeWidth={1.3}
            strokeLinejoin="round"
            initial={{ pathLength: 0, opacity: 0 }}
            animate={{ pathLength: 1, opacity: 1 }}
            transition={{ duration: 1.05, ease: "easeInOut" }}
          />
          {/* Left wall */}
          <motion.path
            d="M38,154 L38,76 L150,14 L150,92"
            fill="rgba(252,248,244,0.55)"
            stroke={W_SOFT}
            strokeWidth={1.3}
            strokeLinejoin="round"
            initial={{ pathLength: 0, opacity: 0 }}
            animate={{ pathLength: 1, opacity: 1 }}
            transition={{ duration: 0.78, delay: 0.58, ease: "easeInOut" }}
          />
          {/* Right wall */}
          <motion.path
            d="M262,154 L262,76 L150,14"
            fill="rgba(252,248,244,0.32)"
            stroke={W_SOFT}
            strokeWidth={1.3}
            strokeLinejoin="round"
            initial={{ pathLength: 0, opacity: 0 }}
            animate={{ pathLength: 1, opacity: 1 }}
            transition={{ duration: 0.62, delay: 0.80, ease: "easeInOut" }}
          />

          {/* Small window on left wall — warm sunlight tint */}
          <motion.g
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 1.05, duration: 0.55 }}
          >
            <rect x={74} y={44} width={28} height={22} rx={2.5}
              fill="rgba(220,235,248,0.60)"
              stroke={W_SOFT} strokeWidth={0.8}
            />
            <line x1={88} y1={44} x2={88} y2={66} stroke={W_SOFT} strokeWidth={0.6} />
            <line x1={74} y1={55} x2={102} y2={55} stroke={W_SOFT} strokeWidth={0.6} />
            {/* Warm glow pulse */}
            <motion.rect x={74} y={44} width={28} height={22} rx={2.5}
              fill="rgba(255,220,140,0.22)"
              initial={{ opacity: 0.22 }}
              animate={{ opacity: [0.22, 0.42, 0.22] }}
              transition={{ duration: 2.8, repeat: Infinity, ease: "easeInOut" }}
            />
          </motion.g>

          {/* Small plant in left corner */}
          <motion.g
            initial={{ opacity: 0, y: 5 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 1.12, duration: 0.5, ease: "easeOut" }}
          >
            <path d="M56,207 L64,207 L62.5,216 L57.5,216 Z"
              fill="rgba(175,125,95,0.72)" />
            <line x1={60} y1={207} x2={60} y2={197}
              stroke="rgba(100,145,75,0.65)" strokeWidth={1.5} strokeLinecap="round" />
            <ellipse cx={60} cy={195} rx={7} ry={5}
              fill="rgba(128,172,96,0.72)" />
            <ellipse cx={66} cy={199} rx={5.5} ry={4}
              fill="rgba(110,160,82,0.62)"
              style={{ transform: "rotate(22deg)", transformOrigin: "66px 199px" }}
            />
            <ellipse cx={54} cy={200} rx={5} ry={3.5}
              fill="rgba(118,168,90,0.62)"
              style={{ transform: "rotate(-18deg)", transformOrigin: "54px 200px" }}
            />
          </motion.g>

          {/* Furniture — spring bounce in during phase 1 */}
          {GEN_FURN.map((f, i) => {
            const p = isoBox(f);
            const showDelay = 1.38 + i * 0.30;
            const labelTop = f.cy - f.h - f.hh - 17;
            const sparkX = f.cx;
            const sparkY = labelTop - 9;
            return (
              <motion.g key={i}>
                {/* Body springs in */}
                <motion.g
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: phase >= 1 ? 1 : 0, y: phase >= 1 ? 0 : 8 }}
                  transition={{
                    delay: showDelay, duration: 0.6,
                    type: "spring", stiffness: 300, damping: 22,
                  }}
                >
                  <path d={p.top}   fill="rgba(255,255,255,0.82)" stroke={W_LINE}  strokeWidth={1.15} strokeLinejoin="round" />
                  <path d={p.verts} fill="none"                    stroke={W_SOFT}  strokeWidth={0.95} />
                  <path d={p.base}  fill="none"                    stroke={W_SOFT}  strokeWidth={0.95} strokeLinejoin="round" />
                </motion.g>

                {/* ✦ Sparkle pop above furniture */}
                <motion.g
                  initial={{ opacity: 0 }}
                  animate={{ opacity: phase >= 1 ? [0, 1, 0.7, 0] : 0 }}
                  transition={{ delay: showDelay + 0.18, duration: 1.1, ease: "easeOut" }}
                  style={{ transformOrigin: `${sparkX}px ${sparkY}px` }}
                >
                  <motion.g
                    initial={{ scale: 0 }}
                    animate={{ scale: phase >= 1 ? [0, 1.3, 1, 0] : 0 }}
                    transition={{ delay: showDelay + 0.18, duration: 1.1, ease: "easeOut" }}
                    style={{ transformOrigin: `${sparkX}px ${sparkY}px` }}
                  >
                    <path
                      d={`M${sparkX},${sparkY-5.5} L${sparkX+1.3},${sparkY-1.3} L${sparkX+5.5},${sparkY} L${sparkX+1.3},${sparkY+1.3} L${sparkX},${sparkY+5.5} L${sparkX-1.3},${sparkY+1.3} L${sparkX-5.5},${sparkY} L${sparkX-1.3},${sparkY-1.3} Z`}
                      fill={ORANGE}
                    />
                  </motion.g>
                </motion.g>

                {/* Label badge — white pill with spring */}
                <motion.g
                  initial={{ opacity: 0 }}
                  animate={{ opacity: phase >= 1 ? 1 : 0 }}
                  transition={{ delay: showDelay + 0.46, duration: 0.36, type: "spring", stiffness: 380, damping: 26 }}
                  style={{ transformOrigin: `${f.cx}px ${labelTop + 7}px` }}
                >
                  <rect
                    x={f.cx - 16} y={labelTop} width={32} height={14} rx={7}
                    fill="rgba(255,255,255,0.94)"
                    stroke="rgba(250,136,58,0.30)"
                    strokeWidth={0.8}
                  />
                  <text
                    x={f.cx} y={labelTop + 10}
                    textAnchor="middle" fill={COFFEE}
                    fontSize={7.5} fontWeight={600} opacity={0.84}
                    style={{ fontFamily: "system-ui,-apple-system" }}
                  >{f.label}</text>
                </motion.g>
              </motion.g>
            );
          })}

          {/* Scan sweep — soft single pass */}
          <motion.g
            initial={{ y: -88, opacity: 0 }}
            animate={{ y: [-88, 188], opacity: [0, 0.9, 0.9, 0] }}
            transition={{ delay: 1.78, duration: 1.0, ease: "easeInOut", times: [0, 0.07, 0.88, 1] }}
          >
            <rect x={22} y={0} width={256} height={52} fill="url(#gen-scan)" />
            <rect x={38} y={50} width={224} height={1.2} fill="url(#gen-scanline)" />
          </motion.g>

          {/* Tiny drifting warmth particles (like steam / dust motes) */}
          {([
            [66,212,0],[238,124,0.42],[150,54,0.78],[104,248,0.18],
            [212,208,0.56],[52,140,0.90],
          ] as [number,number,number][]).map(([x,y,d],i)=>(
            <motion.circle
              key={i} cx={x} cy={y} r={1.4} fill={ORANGE}
              initial={{ opacity: 0 }}
              animate={{ opacity: [0, 0.26, 0], y: [0, -12, -22] }}
              transition={{
                delay: 1.5 + d,
                duration: 2.7,
                repeat: Infinity,
                repeatDelay: 0.28 + i * 0.3,
                ease: "easeOut",
              }}
            />
          ))}
        </svg>
      </motion.div>

      {/* Phase text */}
      <div
        style={{ height: 52, marginTop: 30, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", position: "relative", zIndex: 1 }}
      >
        <AnimatePresence mode="wait">
          <motion.div
            key={phase}
            initial={{ opacity: 0, y: 9 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -9 }}
            transition={{ duration: 0.38, ease: "easeOut" }}
            style={{ textAlign: "center" }}
          >
            <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600, letterSpacing: "-0.01em" }}>
              {current.main}
            </p>
            {current.sub && (
              <p style={{ color: COFFEE, opacity: 0.46, fontSize: 11.5, marginTop: 5, letterSpacing: "0.015em" }}>
                {current.sub}
              </p>
            )}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Breathing dots */}
      <div className="flex items-center gap-2" style={{ marginTop: 14, position: "relative", zIndex: 1 }}>
        {[0, 1, 2].map((i) => (
          <motion.span
            key={i}
            style={{
              width: i === 1 ? 6 : 4,
              height: i === 1 ? 6 : 4,
              borderRadius: 999,
              display: "block",
              backgroundColor: ORANGE,
            }}
            animate={{ opacity: [0.28, 0.88, 0.28] }}
            transition={{ duration: 1.4, repeat: Infinity, delay: i * 0.22, ease: "easeInOut" }}
          />
        ))}
      </div>
    </div>
  );
}

/* ---------- 1.6 Plan carousel (horizontal peek, Apple-style) ---------- */

// Card is 312px wide; 39px peek on each side within a 390px viewport
const CARD_W = 312;
const CARD_GAP = 12;
const CARD_STEP = CARD_W + CARD_GAP; // 324px between card centres
const PEEK = (390 - CARD_W) / 2;     // 39px each side

function PlanDeckStep({
  plans,
  onClose,
  onStart,
  onTune,
}: {
  plans: GenPlan[];
  onClose: () => void;
  onStart: (p: GenPlan) => void;
  onTune: (p: GenPlan) => void;
}) {
  const [idx, setIdx] = useState(0);
  const active = plans[idx];

  const go = (next: number) => {
    if (next >= 0 && next < plans.length) setIdx(next);
  };

  return (
    <div className="h-full w-full flex flex-col" style={{ backgroundColor: LINEN }}>

      {/* ── Header ── */}
      <div style={{ paddingTop: 60, paddingLeft: 24, paddingRight: 24, paddingBottom: 14 }}>
        <div className="flex items-start gap-3">
          <div className="flex-1">
            <p
              style={{
                color: COFFEE,
                fontSize: 27,
                fontWeight: 700,
                letterSpacing: "-0.032em",
                lineHeight: 1.2,
              }}
            >
              你的空间，
              <br />
              可以这样整理
            </p>
            <p
              style={{
                color: COFFEE,
                opacity: 0.44,
                fontSize: 11.5,
                marginTop: 8,
                lineHeight: 1.6,
              }}
            >
              AI 根据空间结构与物品分布，为你生成了 {plans.length} 种整理方案
            </p>
          </div>
          <button
            onClick={onClose}
            className="h-9 w-9 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5"
            style={{ backgroundColor: WHITE, boxShadow: "0 2px 8px rgba(123,92,72,0.10)" }}
          >
            <X size={16} color={COFFEE} />
          </button>
        </div>
      </div>

      {/* ── Carousel ── */}
      <div className="relative flex-1 overflow-hidden" style={{ minHeight: 0 }}>
        {plans.map((p, i) => {
          const isActive = i === idx;
          const dist = Math.abs(i - idx);
          const xPos = PEEK + (i - idx) * CARD_STEP;
          const scale = isActive ? 1.0 : dist === 1 ? 0.91 : 0.83;
          const opacity = isActive ? 1.0 : dist === 1 ? 0.68 : 0.38;

          return (
            <motion.div
              key={p.id}
              className="absolute top-2 bottom-0"
              style={{ width: CARD_W, left: 0 }}
              animate={{ x: xPos, scale, opacity }}
              transition={{ type: "spring", stiffness: 360, damping: 36 }}
              drag={isActive ? "x" : false}
              dragConstraints={{ left: 0, right: 0 }}
              dragElastic={0.2}
              onDragEnd={(_, info) => {
                if (info.offset.x < -58) go(idx + 1);
                else if (info.offset.x > 58) go(idx - 1);
              }}
              onTap={() => { if (!isActive) setIdx(i); }}
            >
              <div
                className="h-full w-full overflow-hidden flex flex-col"
                style={{
                  backgroundColor: WHITE,
                  borderRadius: 28,
                  boxShadow: isActive
                    ? "0 24px 64px rgba(123,92,72,0.22), 0 4px 18px rgba(123,92,72,0.10)"
                    : "0 6px 24px rgba(123,92,72,0.08)",
                }}
              >
                {/* ── Hero image ── */}
                <div className="relative flex-shrink-0" style={{ height: "57%" }}>
                  <ImageWithFallback
                    src={p.image}
                    alt={p.name}
                    className="h-full w-full object-cover"
                  />
                  <div
                    className="absolute inset-0 pointer-events-none"
                    style={{
                      background:
                        "linear-gradient(180deg, rgba(0,0,0,0.22) 0%, rgba(0,0,0,0) 44%)",
                    }}
                  />
                  {/* plan number pill */}
                  <span
                    className="absolute top-4 left-4"
                    style={{
                      backgroundColor: "rgba(255,255,255,0.92)",
                      backdropFilter: "blur(8px)",
                      borderRadius: 999,
                      fontSize: 9.5,
                      fontWeight: 700,
                      color: COFFEE,
                      letterSpacing: "0.06em",
                      padding: "4px 10px",
                    }}
                  >
                    方案 0{i + 1}
                  </span>
                  {/* time pill */}
                  <span
                    className="absolute top-4 right-4 flex items-center gap-1"
                    style={{
                      backgroundColor: p.accent,
                      borderRadius: 999,
                      fontSize: 9.5,
                      fontWeight: 600,
                      color: WHITE,
                      padding: "4px 10px",
                    }}
                  >
                    约 {p.minutes} 分钟
                  </span>
                </div>

                {/* ── Plan info ── */}
                <div
                  className="flex-1 flex flex-col justify-between overflow-hidden"
                  style={{ padding: "17px 20px 20px" }}
                >
                  {/* name + vibe */}
                  <div>
                    <div className="flex items-center gap-2 mb-1.5">
                      <span
                        style={{
                          width: 8,
                          height: 8,
                          borderRadius: 999,
                          backgroundColor: p.accent,
                          flexShrink: 0,
                          display: "inline-block",
                        }}
                      />
                      <p
                        style={{
                          color: COFFEE,
                          fontSize: 22,
                          fontWeight: 700,
                          letterSpacing: "-0.025em",
                          lineHeight: 1.15,
                        }}
                      >
                        {p.name}
                      </p>
                    </div>
                    <p
                      style={{
                        color: COFFEE,
                        opacity: 0.5,
                        fontSize: 12,
                        lineHeight: 1.6,
                        paddingLeft: 16,
                      }}
                    >
                      {p.vibe}
                    </p>
                  </div>

                  {/* strategy bullets */}
                  <div className="space-y-1.5">
                    {p.changes.map((c, ci) => (
                      <div key={ci} className="flex items-start gap-2.5">
                        <div
                          style={{
                            width: 4,
                            height: 4,
                            borderRadius: 999,
                            backgroundColor: p.accent,
                            opacity: 0.72,
                            flexShrink: 0,
                            marginTop: 7,
                          }}
                        />
                        <span
                          style={{
                            color: COFFEE,
                            opacity: 0.68,
                            fontSize: 11.5,
                            lineHeight: 1.55,
                          }}
                        >
                          {c}
                        </span>
                      </div>
                    ))}
                  </div>

                  {/* tags */}
                  <div className="flex gap-1.5 flex-wrap">
                    {p.tags.map((t) => (
                      <span
                        key={t}
                        style={{
                          backgroundColor: LINEN,
                          color: COFFEE,
                          borderRadius: 999,
                          fontSize: 10.5,
                          fontWeight: 600,
                          padding: "4px 10px",
                        }}
                      >
                        {t}
                      </span>
                    ))}
                  </div>
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>

      {/* ── Dots + CTA ── */}
      <div
        style={{
          paddingTop: 16,
          paddingBottom: 32,
          paddingLeft: 20,
          paddingRight: 20,
          backgroundColor: WHITE,
          borderTop: `1px solid ${SOFT}`,
          marginTop: 12,
        }}
      >
        {/* animated dots */}
        <div className="flex justify-center gap-1.5 mb-5">
          {plans.map((_, i) => (
            <motion.button
              key={i}
              onClick={() => setIdx(i)}
              animate={{
                width: i === idx ? 24 : 7,
                backgroundColor: i === idx ? ORANGE : "rgba(123,92,72,0.2)",
              }}
              style={{ height: 7, borderRadius: 999 }}
              transition={{ type: "spring", stiffness: 380, damping: 32 }}
            />
          ))}
        </div>

        <button
          onClick={() => onStart(active)}
          className="w-full py-4 flex items-center justify-center gap-2 active:scale-[0.98] transition-transform"
          style={{
            backgroundColor: ORANGE,
            color: WHITE,
            borderRadius: 999,
            fontSize: 14,
            fontWeight: 700,
            boxShadow: "0 10px 28px rgba(250,136,58,0.34)",
          }}
        >
          <Check size={16} />
          选择此方案
        </button>
        <button
          onClick={() => onTune(active)}
          className="w-full py-3 mt-2.5 flex items-center justify-center gap-2 active:scale-[0.98] transition-transform"
          style={{
            backgroundColor: LINEN,
            color: COFFEE,
            borderRadius: 999,
            fontSize: 13,
            fontWeight: 600,
          }}
        >
          <Sparkles size={14} color={ORANGE} />
          微调方案
        </button>
      </div>
    </div>
  );
}

/* ---------- 1.7 Tune: iterative plan refinement ---------- */

type TuneMsg = { id: string; role: "user" | "ai"; text: string; tweakSnap?: string[] };

const TUNE_CHIPS = [
  "再简洁一些",
  "更易收纳",
  "保留可见性",
  "多留空白",
  "适合孩子",
  "预算低一些",
];

function PlanPreviewCard({ plan, tweaks }: { plan: GenPlan; tweaks: string[] }) {
  const [loaded, setLoaded] = useState(false);
  useEffect(() => {
    const t = setTimeout(() => setLoaded(true), 680);
    return () => clearTimeout(t);
  }, []);

  return (
    <motion.div
      initial={{ opacity: 0, y: 10, scale: 0.96 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ duration: 0.38, ease: [0.22, 1, 0.36, 1] }}
      style={{
        marginLeft: 36,
        borderRadius: 18,
        overflow: "hidden",
        backgroundColor: WHITE,
        boxShadow: "0 4px 20px rgba(123,92,72,0.12)",
      }}
    >
      {/* Image area */}
      <div style={{ position: "relative", height: 148 }}>
        {!loaded ? (
          /* Shimmer skeleton */
          <motion.div
            style={{ position: "absolute", inset: 0, backgroundColor: SOFT, overflow: "hidden" }}
          >
            <motion.div
              animate={{ x: ["-100%", "200%"] }}
              transition={{ duration: 1.1, repeat: Infinity, ease: "easeInOut" }}
              style={{
                position: "absolute", inset: 0,
                background: "linear-gradient(90deg, transparent 0%, rgba(255,255,255,0.55) 50%, transparent 100%)",
              }}
            />
            <div style={{ position: "absolute", bottom: 10, left: 12, right: 12 }}>
              <div style={{ height: 9, width: "55%", borderRadius: 5, backgroundColor: "rgba(123,92,72,0.12)", marginBottom: 6 }} />
              <div style={{ height: 7, width: "35%", borderRadius: 5, backgroundColor: "rgba(123,92,72,0.08)" }} />
            </div>
          </motion.div>
        ) : (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.5 }}
            style={{ position: "absolute", inset: 0 }}
          >
            <ImageWithFallback src={plan.image} alt="" className="h-full w-full object-cover" />
            {/* Accent colour wash */}
            <div style={{ position: "absolute", inset: 0, background: `linear-gradient(140deg, ${plan.accent}55 0%, transparent 58%)` }} />
            {/* Bottom gradient for legibility */}
            <div style={{ position: "absolute", inset: 0, background: "linear-gradient(0deg, rgba(0,0,0,0.52) 0%, transparent 55%)" }} />

            {/* "AI 效果预览" pill */}
            <div style={{ position: "absolute", top: 10, left: 10 }}>
              <div style={{
                display: "flex", alignItems: "center", gap: 4,
                backgroundColor: "rgba(0,0,0,0.48)", backdropFilter: "blur(6px)",
                borderRadius: 999, padding: "3px 10px",
              }}>
                <Sparkles size={9} color="rgba(255,255,255,0.75)" />
                <span style={{ color: "rgba(255,255,255,0.85)", fontSize: 9.5, fontWeight: 600, letterSpacing: "0.02em" }}>
                  AI 效果预览
                </span>
              </div>
            </div>
            {/* "已应用" badge */}
            <div style={{ position: "absolute", top: 10, right: 10 }}>
              <div style={{
                backgroundColor: plan.accent, borderRadius: 999,
                padding: "3px 9px", fontSize: 9, fontWeight: 700, color: WHITE,
              }}>
                ✓ 已应用
              </div>
            </div>

            {/* Zone dots — small colour indicators */}
            <motion.div
              initial={{ opacity: 0 }} animate={{ opacity: 1 }}
              transition={{ delay: 0.18, duration: 0.5 }}
              style={{ position: "absolute", bottom: 36, left: 14, display: "flex", gap: 5 }}
            >
              {[ORANGE, BLUE, plan.accent].map((c, ci) => (
                <div key={ci} style={{
                  width: 8, height: 8, borderRadius: 999, border: "1.5px solid rgba(255,255,255,0.7)",
                  backgroundColor: c, boxShadow: `0 0 6px ${c}88`,
                }} />
              ))}
            </motion.div>

            {/* Plan name at bottom */}
            <div style={{ position: "absolute", bottom: 10, left: 12, right: 12 }}>
              <p style={{ color: WHITE, fontSize: 12.5, fontWeight: 700, letterSpacing: "-0.01em" }}>
                {plan.name}{tweaks.length > 0 ? " · 定制" : ""}
              </p>
            </div>
          </motion.div>
        )}
      </div>

      {/* Tweak pills */}
      {tweaks.length > 0 && (
        <div style={{ padding: "10px 13px 13px" }}>
          <p style={{ color: COFFEE, opacity: 0.5, fontSize: 10.5, fontWeight: 600, marginBottom: 7, letterSpacing: "0.02em" }}>
            已调整 {tweaks.length} 项
          </p>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 5 }}>
            {tweaks.map((t, i) => (
              <span key={i} style={{
                backgroundColor: LINEN, color: COFFEE, fontSize: 10.5,
                borderRadius: 999, padding: "3px 10px",
                border: `1px solid rgba(123,92,72,0.14)`,
              }}>
                {t}
              </span>
            ))}
          </div>
        </div>
      )}
    </motion.div>
  );
}

function TuneChatStep({
  plan,
  onBack,
  onConfirm,
}: {
  plan: GenPlan;
  onBack: () => void;
  onConfirm: (refined: GenPlan) => void;
}) {
  const [messages, setMessages] = useState<TuneMsg[]>([
    {
      id: "t0",
      role: "ai",
      text: `我们在「${plan.name}」的基础上调整。有什么具体想改变的？可以直接说，或点下方建议。`,
    },
  ]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const [tweaks, setTweaks] = useState<string[]>([]);
  const tweaksRef = useRef<string[]>([]);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [messages]);

  const push = async (text: string) => {
    if (!text.trim() || sending) return;
    const newTweak = text.trim();
    tweaksRef.current = [...tweaksRef.current, newTweak];
    const snap = [...tweaksRef.current];
    setTweaks(snap);
    const previousHistory = messages.map((item) => ({ role: item.role === "ai" ? "assistant" : "user", text: item.text }));
    setMessages((m) => [...m, { id: `u${Date.now()}`, role: "user", text: newTweak }]);
    setInput("");
    setSending(true);
    try {
      const result = await nativeRequest<{ reply: string }>("chat.send", { message: newTweak, history: previousHistory });
      setMessages((m) => [...m, { id: `a${Date.now()}`, role: "ai", text: result.reply, tweakSnap: snap }]);
    } catch (error) {
      setMessages((m) => [...m, {
        id: `e${Date.now()}`,
        role: "ai",
        text: error instanceof Error ? error.message : "AI 暂时不可用，请检查设置和网络。",
        tweakSnap: snap,
      }]);
    } finally {
      setSending(false);
    }
  };

  const refined: GenPlan = {
    ...plan,
    name: tweaks.length ? `${plan.name} · 定制` : plan.name,
    vibe: tweaks.length ? tweaks.slice(-2).join(" · ") : plan.vibe,
  };

  return (
    <div className="h-full w-full flex flex-col" style={{ backgroundColor: LINEN }}>

      {/* ── Plan image hero ── */}
      <div className="relative flex-shrink-0" style={{ height: 196 }}>
        <ImageWithFallback
          src={plan.image}
          alt={plan.name}
          className="h-full w-full object-cover"
        />
        <div
          className="absolute inset-0 pointer-events-none"
          style={{
            background:
              "linear-gradient(180deg, rgba(0,0,0,0.44) 0%, rgba(0,0,0,0.06) 52%, rgba(246,241,235,0.97) 100%)",
          }}
        />
        <button
          onClick={onBack}
          className="absolute top-14 left-5 h-9 w-9 rounded-full flex items-center justify-center"
          style={{ backgroundColor: "rgba(255,255,255,0.9)", backdropFilter: "blur(8px)" }}
        >
          <ArrowLeft size={16} color={COFFEE} />
        </button>
        <div className="absolute bottom-5 left-5 right-5">
          <div className="flex items-center gap-2 mb-0.5">
            <span className="h-2 w-2 rounded-full flex-shrink-0" style={{ backgroundColor: plan.accent }} />
            <p style={{ color: WHITE, fontSize: 19, fontWeight: 700, letterSpacing: "-0.02em" }}>{plan.name}</p>
          </div>
          <p style={{ color: "rgba(255,255,255,0.62)", fontSize: 11.5, paddingLeft: 16 }}>
            在此方案基础上微调
          </p>
        </div>
      </div>

      {/* ── Messages ── */}
      <div
        ref={scrollRef}
        className="flex-1 overflow-y-auto"
        style={{ padding: "14px 16px 10px", display: "flex", flexDirection: "column", gap: 10 }}
      >
        {messages.map((m) => (
          <div key={m.id}>
            {m.role === "ai" ? (
              <div className="flex items-start gap-2.5">
                <div
                  className="h-7 w-7 rounded-full flex items-center justify-center flex-shrink-0"
                  style={{ backgroundColor: plan.accent }}
                >
                  <Sparkles size={13} color={WHITE} />
                </div>
                <div
                  className="px-3.5 py-2.5"
                  style={{
                    backgroundColor: WHITE,
                    borderRadius: 18,
                    borderTopLeftRadius: 5,
                    maxWidth: "82%",
                  }}
                >
                  <p style={{ color: COFFEE, fontSize: 13, lineHeight: 1.62 }}>{m.text}</p>
                </div>
              </div>
            ) : (
              <div className="flex justify-end">
                <div
                  className="px-3.5 py-2.5"
                  style={{
                    backgroundColor: COFFEE,
                    color: WHITE,
                    borderRadius: 18,
                    borderTopRightRadius: 5,
                    maxWidth: "80%",
                  }}
                >
                  <p style={{ fontSize: 13, lineHeight: 1.62 }}>{m.text}</p>
                </div>
              </div>
            )}
            {/* Visual preview card — shown after each AI response that carries tweaks */}
            {m.role === "ai" && m.tweakSnap && m.tweakSnap.length > 0 && (
              <div style={{ marginTop: 8 }}>
                <PlanPreviewCard plan={plan} tweaks={m.tweakSnap} />
              </div>
            )}
          </div>
        ))}
      </div>

      {/* ── Suggestion chips ── */}
      <div
        className="overflow-x-auto flex-shrink-0"
        style={{ paddingLeft: 16, paddingRight: 16, paddingTop: 6, paddingBottom: 6 }}
      >
        <div className="flex gap-2" style={{ width: "max-content" }}>
          {TUNE_CHIPS.map((t) => (
            <button
              key={t}
              onClick={() => push(t)}
              className="flex-shrink-0"
              style={{
                backgroundColor: WHITE,
                color: COFFEE,
                borderRadius: 999,
                fontSize: 12,
                fontWeight: 500,
                border: `1px solid ${SOFT}`,
                padding: "6px 14px",
              }}
            >
              {t}
            </button>
          ))}
        </div>
      </div>

      {/* ── Composer + confirm ── */}
      <div
        className="flex-shrink-0"
        style={{
          paddingLeft: 16,
          paddingRight: 16,
          paddingTop: 12,
          paddingBottom: 28,
          backgroundColor: WHITE,
          borderTop: `1px solid ${SOFT}`,
        }}
      >
        <div
          className="flex items-center gap-2"
          style={{
            backgroundColor: LINEN,
            borderRadius: 22,
            paddingLeft: 16,
            paddingRight: 6,
            paddingTop: 6,
            paddingBottom: 6,
          }}
        >
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && push(input)}
            placeholder="告诉我想怎么调整…"
            className="flex-1 bg-transparent outline-none"
            style={{ color: COFFEE, fontSize: 13, lineHeight: 1.5 }}
          />
          <button
            onClick={() => push(input)}
            className="h-9 w-9 rounded-full flex items-center justify-center flex-shrink-0"
            style={{
              backgroundColor: input.trim() ? ORANGE : SOFT,
              boxShadow: input.trim() ? "0 4px 12px rgba(250,136,58,0.28)" : "none",
              transition: "background 0.18s",
            }}
          >
            <Send size={15} color={WHITE} />
          </button>
        </div>

        <button
          onClick={() => onConfirm(refined)}
          className="w-full py-3.5 mt-3 flex items-center justify-center gap-2 active:scale-[0.98] transition-transform"
          style={{
            backgroundColor: ORANGE,
            color: WHITE,
            borderRadius: 999,
            fontSize: 14,
            fontWeight: 700,
            boxShadow: "0 10px 28px rgba(250,136,58,0.34)",
          }}
        >
          <Check size={16} />
          确认方案
          {tweaks.length > 0 && (
            <span
              style={{
                backgroundColor: "rgba(255,255,255,0.25)",
                borderRadius: 999,
                fontSize: 10,
                padding: "2px 7px",
              }}
            >
              {tweaks.length} 项调整
            </span>
          )}
        </button>
      </div>
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
  const [previewMode, setPreviewMode] = useState(false);
  const [currentIdx, setCurrentIdx] = useState(0);
  const [reshootIdx, setReshootIdx] = useState<number | null>(null);
  const [freshEntryId, setFreshEntryId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const recTimer = useRef<any>(null);
  // 真实取景：相机画面垫在 WebView 底下，页面原地透明透出来，UI 一个像素都不动。
  // 相机在点进来之前就已经待命，所以这里乐观地认为"画面已经在"——
  // 容器一开始就是透明的，画面直接透出来，中间没有"深色底 → 画面"的跳变。
  // 万一真的没起来，startPreview 失败后才会切成深色底并给重试提示。
  const previewRef = useRef<HTMLDivElement>(null);
  const [liveFeed, setLiveFeed] = useState(true);
  // 等待画面期间一律用深色底（和相机出画面前的黑屏一致），不再显示任何占位图。
  // 取景失败只在这页里提示 + 重试，绝不跳到系统相机页。
  const [camFailed, setCamFailed] = useState(false);
  const [camReason, setCamReason] = useState<string | null>(null);

  // Swipe / drag state
  const dragStartX = useRef<number | null>(null);
  const isDragging = useRef(false);
  const [dragOffset, setDragOffset] = useState(0);

  const angleHint = ANGLE_HINTS[Math.min(shots.length, ANGLE_HINTS.length - 1)];
  const fmt = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

  // 进入拍摄页就起真相机；离开时关掉。
  // 没画面时只在这一页里重试 + 提示，绝不跳到系统相机页。
  const rectOf = () => {
    const r = previewRef.current?.getBoundingClientRect();
    return r
      ? { x: r.x, y: r.y, width: r.width, height: r.height }
      : { x: 0, y: 0, width: window.innerWidth, height: window.innerHeight };
  };

  const startPreview = async (): Promise<boolean> => {
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        const res = await nativeRequest<{ ok: boolean; reason?: string }>("camera.preview.start", rectOf());
        if (res.ok === true) {
          setLiveFeed(true);
          setCamReason(null);
          return true;
        }
        setCamReason(res.reason ?? "unavailable");
      } catch {
        setCamReason("unavailable");
      }
      // 相机可能刚被别的应用占着，缓一下再试。
      await new Promise((r) => setTimeout(r, 600));
    }
    // 真的没起来才收回"画面已在"的乐观假设，改用深色底 + 重试提示。
    setLiveFeed(false);
    return false;
  };

  useEffect(() => {
    let stopped = false;
    (async () => {
      const ok = await startPreview();
      if (!stopped && !ok) setCamFailed(true);
    })();
    const sync = () => {
      void nativeRequest("camera.preview.frame", rectOf()).catch(() => {});
    };
    window.addEventListener("resize", sync);
    return () => {
      stopped = true;
      window.removeEventListener("resize", sync);
      void nativeRequest("camera.preview.stop", {}).catch(() => {});
    };
  }, []);

  // 画面要透上来，得把预览区以上这条链路的背景临时改成透明，离开时还原。
  useEffect(() => {
    if (!liveFeed) return;
    const chain: HTMLElement[] = [];
    let node: HTMLElement | null = previewRef.current;
    while (node) {
      chain.push(node);
      node = node.parentElement;
    }
    const saved = chain.map((el) => el.style.background);
    const savedHtml = document.documentElement.style.background;
    const savedBody = document.body.style.background;
    chain.forEach((el) => { el.style.background = "transparent"; });
    document.documentElement.style.background = "transparent";
    document.body.style.background = "transparent";
    return () => {
      chain.forEach((el, i) => { el.style.background = saved[i]; });
      document.documentElement.style.background = savedHtml;
      document.body.style.background = savedBody;
    };
  }, [liveFeed]);

  const snapPhoto = async () => {
    if (busy) return;
    setShutter(true);
    setTimeout(() => setShutter(false), 200);
    setBusy(true);
    setError(null);
    try {
      // 只在有实时画面时原地拍；没有画面就提示重试，绝不跳出去开系统相机。
      if (!liveFeed) {
        setError(camReason === "denied" ? "没有相机权限：去「设置 → 灵爪收纳」里打开相机" : "相机还没准备好，点一下画面里的重试");
        void startPreview().then((ok) => setCamFailed(!ok));
        return;
      }
      const shot = await nativeRequest<{ preview?: string }>("camera.capture", {});
      const src = shot.preview;
      if (!src) {
        setError("没有拿到照片，光线亮一点再试一次");
        return;
      }
    const newId = `p${Date.now()}`;
    const newShot: CapturedAsset = {
      id: newId,
      kind: "photo",
      src,
      label: ANGLE_HINTS[reshootIdx !== null ? reshootIdx : shots.length] || `拍摄 ${shots.length + 1}`,
    };

    if (reshootIdx !== null) {
      const idx = reshootIdx;
      setShots((arr) => arr.map((s, i) => (i === idx ? newShot : s)));
      setCurrentIdx(idx);
      setFreshEntryId(newId);
      setReshootIdx(null);
    } else {
      setShots((arr) => {
        const next = [...arr, newShot];
        setCurrentIdx(next.length - 1);
        return next;
      });
      setFreshEntryId(newId);
    }

    setTimeout(() => setPreviewMode(true), 220);
    } catch (e) {
      const message = e instanceof Error ? e.message : "拍摄未完成";
      if (message !== "已取消") setError(message);
    } finally {
      setBusy(false);
    }
  };

  const toggleRecord = async () => {
    if (busy) return;
    setBusy(true);
    setError(null);
    setRecording(true);
    setRecDuration(0);
    recTimer.current = setInterval(() => setRecDuration((d) => d + 1), 1000);
    try {
      // 真实 AR 扫描就在这一页里抓帧；没画面只提示重试，不跳原生页。
      if (!liveFeed) {
        setError("相机还没准备好，点一下画面里的重试");
        void startPreview().then((ok) => setCamFailed(!ok));
        return;
      }
      const shot = await nativeRequest<{ preview?: string }>("camera.capture", {});
      const src = shot.preview;
      if (!src) {
        setError("扫描没有生成画面，换一个角度再试一次");
        return;
      }
      const newId = `v${Date.now()}`;
      const newVideo: CapturedAsset = {
        id: newId,
        kind: "video",
        src,
        label: "AR扫描视频",
        duration: Math.max(recDuration, 3),
      };
      setShots((arr) => {
        const next = [...arr, newVideo];
        setCurrentIdx(next.length - 1);
        return next;
      });
      setFreshEntryId(newId);
      setTimeout(() => setPreviewMode(true), 220);
    } catch (e) {
      const message = e instanceof Error ? e.message : "扫描未完成";
      if (message !== "已取消") setError(message);
    } finally {
      clearInterval(recTimer.current);
      setRecording(false);
      setRecDuration(0);
      setBusy(false);
    }
  };

  const deleteShot = () => {
    const newShots = shots.filter((_, i) => i !== currentIdx);
    if (newShots.length === 0) {
      setShots([]);
      setPreviewMode(false);
      setCurrentIdx(0);
      return;
    }
    setShots(newShots);
    setCurrentIdx(Math.min(currentIdx, newShots.length - 1));
  };

  const reshootCurrent = () => {
    setReshootIdx(currentIdx);
    setFreshEntryId(null);
    setPreviewMode(false);
  };

  const addMore = () => {
    setReshootIdx(null);
    setFreshEntryId(null);
    setPreviewMode(false);
  };

  const handleDragStart = (x: number) => {
    dragStartX.current = x;
    isDragging.current = true;
  };

  const handleDragMove = (x: number) => {
    if (!isDragging.current || dragStartX.current === null) return;
    setDragOffset(x - dragStartX.current);
  };

  const handleDragEnd = () => {
    if (!isDragging.current) return;
    isDragging.current = false;
    const maxIdx = shots.length; // index shots.length = "+" card
    if (dragOffset < -60) {
      setCurrentIdx((i) => Math.min(i + 1, maxIdx));
    } else if (dragOffset > 60) {
      setCurrentIdx((i) => Math.max(i - 1, 0));
    }
    setDragOffset(0);
    dragStartX.current = null;
  };

  /* ---- PREVIEW MODE ---- */
  if (previewMode) {
    const SLIDE_W = 390;
    const totalSlides = shots.length + 1;
    const isOnPlus = currentIdx === shots.length;
    const translateX = -(currentIdx * SLIDE_W) + dragOffset;

    return (
      <div className="absolute inset-0" style={{ backgroundColor: "#0d0b09" }}>
        {/* Shutter flash overlay */}
        <AnimatePresence>
          {shutter && (
            <motion.div
              className="absolute inset-0 pointer-events-none"
              style={{ backgroundColor: WHITE, zIndex: 100 }}
              initial={{ opacity: 0.9 }}
              animate={{ opacity: 0 }}
              transition={{ duration: 0.22 }}
            />
          )}
        </AnimatePresence>

        {/* Header */}
        <div
          className="absolute left-0 right-0 flex items-center justify-between px-5"
          style={{ top: 0, paddingTop: 54, paddingBottom: 12, zIndex: 20 }}
        >
          <button
            onClick={onClose}
            className="h-10 w-10 rounded-full flex items-center justify-center"
            style={{ backgroundColor: "rgba(255,255,255,0.10)" }}
          >
            <X size={18} color={WHITE} />
          </button>
          <motion.span
            key={currentIdx}
            initial={{ opacity: 0, y: -6 }}
            animate={{ opacity: 1, y: 0 }}
            style={{ color: WHITE, fontSize: 15, fontWeight: 600 }}
          >
            {isOnPlus ? "添加照片" : `${currentIdx + 1} / ${shots.length}`}
          </motion.span>
          <div style={{ width: 40 }} />
        </div>

        {/* Carousel */}
        <div
          className="absolute"
          style={{ top: 108, bottom: 148, left: 0, right: 0, overflow: "hidden" }}
          onMouseDown={(e) => handleDragStart(e.clientX)}
          onMouseMove={(e) => handleDragMove(e.clientX)}
          onMouseUp={handleDragEnd}
          onMouseLeave={handleDragEnd}
          onTouchStart={(e) => handleDragStart(e.touches[0].clientX)}
          onTouchMove={(e) => {
            e.preventDefault();
            handleDragMove(e.touches[0].clientX);
          }}
          onTouchEnd={handleDragEnd}
        >
          <div
            style={{
              display: "flex",
              width: `${totalSlides * SLIDE_W}px`,
              height: "100%",
              transform: `translateX(${translateX}px)`,
              transition: isDragging.current ? "none" : "transform 0.32s cubic-bezier(0.22,1,0.36,1)",
              userSelect: "none",
              touchAction: "pan-y",
            }}
          >
            {shots.map((shot, i) => (
              <motion.div
                key={shot.id}
                initial={shot.id === freshEntryId ? { scale: 0.72, opacity: 0 } : false}
                animate={{
                  scale: i === currentIdx ? 1 : 0.88,
                  opacity: i === currentIdx ? 1 : 0.45,
                }}
                transition={{ type: "spring", stiffness: 320, damping: 28 }}
                style={{
                  width: SLIDE_W,
                  height: "100%",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  padding: "0 22px",
                  flexShrink: 0,
                }}
              >
                <div
                  style={{
                    width: "100%",
                    height: "100%",
                    borderRadius: 14,
                    overflow: "hidden",
                    boxShadow:
                      i === currentIdx
                        ? "0 20px 60px rgba(0,0,0,0.65)"
                        : "0 4px 16px rgba(0,0,0,0.3)",
                  }}
                >
                  <img
                    src={shot.src}
                    alt={shot.label}
                    style={{
                      width: "100%",
                      height: "100%",
                      objectFit: "contain",
                      backgroundColor: "#111",
                      pointerEvents: "none",
                      display: "block",
                    }}
                    draggable={false}
                  />
                </div>
              </motion.div>
            ))}

            {/* "+" card */}
            <div
              style={{
                width: SLIDE_W,
                height: "100%",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                flexShrink: 0,
                cursor: "pointer",
              }}
              onClick={addMore}
            >
              <motion.div
                animate={{ opacity: isOnPlus ? 1 : 0.42, scale: isOnPlus ? 1 : 0.88 }}
                transition={{ type: "spring", stiffness: 320, damping: 28 }}
                style={{
                  width: 150,
                  height: 200,
                  borderRadius: 18,
                  border: "1.5px dashed rgba(255,255,255,0.32)",
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "center",
                  justifyContent: "center",
                  gap: 14,
                }}
              >
                <div
                  style={{
                    width: 56,
                    height: 56,
                    borderRadius: 28,
                    backgroundColor: "rgba(255,255,255,0.10)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  <Plus size={28} color={WHITE} />
                </div>
                <span style={{ color: "rgba(255,255,255,0.72)", fontSize: 13, fontWeight: 500 }}>
                  添加照片
                </span>
              </motion.div>
            </div>
          </div>
        </div>

        {/* Dot indicators */}
        <div
          className="absolute flex items-center justify-center gap-1.5"
          style={{ bottom: 156, left: 0, right: 0 }}
        >
          {[...shots, null].map((_, i) => (
            <motion.div
              key={i}
              animate={{
                width: i === currentIdx ? 20 : 5,
                opacity: i === currentIdx ? 1 : 0.35,
                backgroundColor:
                  i === shots.length ? "rgba(255,255,255,0.5)" : WHITE,
              }}
              transition={{ duration: 0.22 }}
              style={{ height: 5, borderRadius: 3 }}
            />
          ))}
        </div>

        {/* Bottom dock */}
        <div
          className="absolute bottom-0 left-0 right-0 flex items-center gap-2.5"
          style={{
            padding: "14px 16px 42px",
            backgroundColor: "rgba(18,13,10,0.92)",
            borderTop: "1px solid rgba(255,255,255,0.06)",
          }}
        >
          <button
            onClick={reshootCurrent}
            disabled={isOnPlus}
            className="flex-1 flex flex-col items-center gap-1.5 py-3 rounded-2xl"
            style={{
              backgroundColor: "rgba(255,255,255,0.07)",
              opacity: isOnPlus ? 0.28 : 1,
            }}
          >
            <RotateCcw size={17} color={WHITE} />
            <span style={{ color: WHITE, fontSize: 11, fontWeight: 500 }}>重拍这张</span>
          </button>
          <button
            onClick={deleteShot}
            disabled={isOnPlus}
            className="flex-1 flex flex-col items-center gap-1.5 py-3 rounded-2xl"
            style={{
              backgroundColor: "rgba(255,255,255,0.07)",
              opacity: isOnPlus ? 0.28 : 1,
            }}
          >
            <Trash2 size={17} color="#E06060" />
            <span style={{ color: "#E06060", fontSize: 11, fontWeight: 500 }}>删除</span>
          </button>
          <button
            onClick={() => on完成(shots)}
            disabled={shots.length === 0}
            className="flex-1 flex flex-col items-center gap-1.5 py-3 rounded-2xl"
            style={{
              backgroundColor: shots.length > 0 ? ORANGE : "rgba(255,255,255,0.12)",
              opacity: shots.length === 0 ? 0.4 : 1,
              boxShadow: shots.length > 0 ? "0 6px 22px rgba(250,136,58,0.38)" : "none",
            }}
          >
            <Check size={17} color={WHITE} />
            <span style={{ color: WHITE, fontSize: 11, fontWeight: 600 }}>完成</span>
          </button>
        </div>
      </div>
    );
  }

  /* ---- CAMERA MODE ---- */
  return (
    <div
      ref={previewRef}
      className="relative h-full w-full overflow-hidden"
      style={{ backgroundColor: liveFeed ? "transparent" : "#1a1411" }}
    >
      {/* 相机画面是垫在底下的真实画面。没出画面前就是一块深色底，
          不再插任何占位图 —— 以前会先显示远程房间图再换成相机，那一下就是"UI 变了"。 */}

      {/* 取景没起来：只在这页里提示 + 重试，不跳系统相机 */}
      {camFailed && (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 px-8" style={{ backgroundColor: "#1a1411" }}>
          <p style={{ color: "#FFFFFF", fontSize: 14, textAlign: "center" }}>
            {camReason === "denied"
              ? "没有相机权限，去「设置 → 灵爪收纳」里允许使用相机"
              : "相机暂时没起来，可能刚被别的应用占用"}
          </p>
          <button
            onClick={async () => {
              setCamFailed(false);
              const ok = await startPreview();
              setCamFailed(!ok);
            }}
            className="px-5 py-2.5 rounded-full"
            style={{ backgroundColor: ORANGE, color: WHITE, fontSize: 13, fontWeight: 600 }}
          >
            重试
          </button>
        </div>
      )}

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
                {reshootIdx !== null
                  ? `重拍第 ${reshootIdx + 1} 张`
                  : mode === "photo"
                  ? `已拍 ${shots.length} 张 · ${angleHint}`
                  : "AR 扫描就绪"}
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
              {m === "photo" ? "多张连拍" : "AR 扫描"}
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
        {/* Thumbnail strip — tap to jump back into preview */}
        {shots.length > 0 && (
          <div className="flex gap-2 mb-3 overflow-x-auto -mx-1 px-1">
            {shots.map((s, i) => (
              <button
                key={s.id}
                onClick={() => { setCurrentIdx(i); setPreviewMode(true); }}
                className="relative flex-shrink-0"
                style={{ width: 52, height: 52, borderRadius: 10, overflow: "hidden", border: `2px solid ${ORANGE}` }}
              >
                <ImageWithFallback src={s.src} alt={s.label} className="h-full w-full object-cover" />
                {s.kind === "video" && (
                  <div
                    className="absolute bottom-0 left-0 right-0 text-center"
                    style={{ backgroundColor: "rgba(0,0,0,0.55)", color: WHITE, fontSize: 8, padding: 1 }}
                  >
                    {fmt(s.duration)}
                  </div>
                )}
              </button>
            ))}
          </div>
        )}

        <div className="flex items-center justify-between">
          {/* Left: shot counter */}
          <button
            onClick={() => shots.length > 0 && setPreviewMode(true)}
            className="h-12 w-12 rounded-2xl flex flex-col items-center justify-center flex-shrink-0"
            style={{ backgroundColor: WHITE }}
          >
            <span style={{ color: COFFEE, fontSize: 15, fontWeight: 700, lineHeight: 1 }}>
              {shots.length}
            </span>
            <span style={{ color: COFFEE, opacity: 0.55, fontSize: 8, marginTop: 1 }}>
              {mode === "photo" ? "张" : "段"}
            </span>
          </button>

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
              <div className="rounded" style={{ width: 26, height: 26, backgroundColor: "#E25555" }} />
            ) : mode === "video" ? (
              <div className="rounded-full" style={{ width: 52, height: 52, backgroundColor: "#E25555" }} />
            ) : (
              <div
                className="rounded-full"
                style={{ width: 52, height: 52, backgroundColor: pressed ? COFFEE : "#cfc6bb" }}
              />
            )}
          </button>

          {/* Right: 完成 */}
          <button
            onClick={() => shots.length > 0 && on完成(shots)}
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

        <p
          style={{
            color: error ? "#C44545" : COFFEE,
            opacity: error ? 1 : 0.5,
            fontSize: 10,
            marginTop: 8,
            textAlign: "center",
          }}
        >
          {error
            ? error
            : busy
            ? "正在打开相机…"
            : reshootIdx !== null
            ? `正在重拍第 ${reshootIdx + 1} 张 · 点击快门替换`
            : mode === "photo"
            ? `拍摄不同角度以提高识别精度 · 下一角度: ${angleHint}`
            : "点击红色按钮开始 AR 扫描，缓慢环绕房间"}
        </p>
      </div>
    </div>
  );
}
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
          <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>查看拍摄</p>
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
            <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>还没有拍摄</p>
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
            <p style={{ color: COFFEE, fontSize: 12.5, fontWeight: 600 }}>AR 扫描就绪</p>
            <p style={{ color: COFFEE, opacity: 0.6, fontSize: 11, marginTop: 2 }}>
              {assets.some((x) => x.kind === "video")
                ? "Video scan will be reconstructed into a 3D mesh."
                : "将拼接多个角度以分析空间纵深。"}
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

function ConfirmStep({ assets, onBack, onNext }: { assets: CapturedAsset[]; onBack: () => void; onNext: () => void }) {
  const [loadingItems, setLoadingItems] = useState(true);
  const [items, setItems] = useState<DetectedItem[]>([]);
  const [adding, set添加ing] = useState(false);
  const [newItem, setNewItem] = useState("");
  const [showItemPicker, setShowItemPicker] = useState(false);
  const [blindSpots, setBlindSpots] = useState<BlindSpot[]>([]);
  const [activeSpot, setActiveSpot] = useState<string | null>(null);
  const [spotNote, setSpotNote] = useState("");

  useEffect(() => {
    // 识别在后台跑（快门不等它），进这一步时先等它跑完，再取结果。
    (async () => {
      try {
        await nativeRequest("scan.await", {});
        const state = await nativeRequest<NativeState>("state.get");
        setItems(state.scannedItems.map((item) => ({ ...item, emoji: getEmojiForItem(item.name) })));
        setBlindSpots(state.scannedItems.filter((item) => item.confidence < 0.55).map((item, index) => ({
          id: `low-${item.id}`, label: item.name, reason: `置信度 ${Math.round(item.confidence * 100)}% — 请确认`,
          left: `${10 + (index % 3) * 28}%`, top: `${34 + (index % 2) * 25}%`, w: "22%", h: "18%",
        })));
      } catch {
        /* 取不到就走空态提示 */
      } finally {
        setLoadingItems(false);
      }
    })();
  }, []);

  const confirmAndContinue = async () => {
    await nativeRequest("items.save", { items: items.map((item) => ({ ...item, category: item.category || "收纳工具", suggestedZone: item.suggestedZone || "手边工具区", isSelected: item.isSelected ?? true })) });
    onNext();
  };

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
        <ImageWithFallback src={assets[0]?.src ?? ROOM_IMG} alt="已拍摄" className="h-full w-full object-cover" />
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
              识别到 {items.length} 件 · {blindSpots.length} 处待确认
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
              我从这次拍摄里认出了 {items.length} 件物品，请确认一下；还有{" "}
              <span style={{ color: ORANGE, fontWeight: 600 }}>
                {blindSpots.filter((b) => !b.resolved).length} 处
              </span>
              看得不太准，需要你帮我定夺。
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

        {!loadingItems && items.length === 0 && (
          <div
            className="mb-4 p-3.5"
            style={{
              backgroundColor: "rgba(250,136,58,0.08)",
              border: `1px solid rgba(250,136,58,0.25)`,
              borderRadius: 16,
            }}
          >
            <div className="flex items-center gap-2 mb-1.5">
              <AlertTriangle size={14} color={ORANGE} />
              <p style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>这次没认出东西来</p>
            </div>
            <p style={{ color: COFFEE, opacity: 0.7, fontSize: 12, lineHeight: 1.6 }}>
              可能是光线偏暗或角度太杂。可以退回补拍一张，也可以直接手动添加物品 —— 后面的方案会按你填的生成。
            </p>
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
          onClick={() => void confirmAndContinue()}
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
  const [tags, setTags] = useState<string[]>(["极简", "快速（5–10 分钟）"]);
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

  const send = async () => {
    const text = input.trim();
    if (!text && tags.length === 0 && refs.length === 0) return;
    const parts: string[] = [];
    if (text) parts.push(text);
    if (refs.length) parts.push(`📎 ${refs.length} reference photo${refs.length === 1 ? "" : "s"}`);
    const compiled = parts.join("  ·  ") || `Style: ${tags.join(", ")}`;
    const userMsg: ChatMsg = { id: `u${Date.now()}`, role: "user", text: compiled };

    const previousHistory = messages.map((item) => ({
      role: item.role === "ai" ? "assistant" : "user",
      text: item.text,
    }));
    setMessages((m) => [...m, userMsg]);
    setInput("");
    setSending(true);
    try {
      const result = await nativeRequest<{ reply: string }>("chat.send", {
        message: compiled,
        history: previousHistory,
      });
      const firstReply = previousHistory.every((item) => item.role !== "user");
      setMessages((m) => [...m, { id: `a${Date.now()}`, role: "ai", text: result.reply, ...(firstReply ? { styleOptions: STYLE_OPTIONS } : {}) }]);
    } catch (error) {
      setMessages((m) => [...m, {
        id: `e${Date.now()}`,
        role: "ai",
        text: error instanceof Error ? error.message : "AI 暂时不可用，请检查设置和网络。",
      }]);
    } finally {
      setSending(false);
    }
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
          <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>描述你的整理目标</p>
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
            <ImageWithFallback src={ROOM_IMG} alt="空间场景" className="h-full w-full object-cover" />
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
  { n: 1, label: "茶几区", left: "12%", top: "38%", w: "32%", h: "26%" },
  { n: 2, label: "沙发区", left: "46%", top: "28%", w: "38%", h: "42%" },
  { n: 3, label: "书架角落", left: "8%", top: "8%", w: "28%", h: "24%" },
];

const durations = [
  { id: "5min", label: "5 分钟", sub: "快速整理" },
  { id: "10min", label: "10 分钟", sub: "标准整理" },
  { id: "1h", label: "1 小时", sub: "深度清洁" },
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
    duration: "10 分钟",
    steps: 6,
    badge: "基础",
    accent: BLUE,
    features: ["表面整理", "物品归位", "无需工具"],
    tools: false,
    image: "https://images.unsplash.com/photo-1649083048269-8bfb755e7b87?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtaW5pbWFsJTIwb3JnYW5pemVkJTIwbGl2aW5nJTIwcm9vbSUyMGNsZWFuJTIwc2ltcGxlfGVufDF8fHx8MTc3ODYzNTc2OHww&ixlib=rb-4.1.0&q=80&w=1080",
  },
  {
    id: "smart",
    label: "智能整理",
    tagline: "AI平衡方案",
    duration: "25 分钟",
    steps: 12,
    badge: "智能推荐",
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
        <ImageWithFallback src={ROOM_IMG} alt="房间" className="h-full w-full object-cover" />
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
        <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600, marginBottom: 14 }}>选择方案</p>

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
    "把书叠整齐",
    "擦拭茶几",
    "把杯子放回厨房",
    "折叠盖毯",
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
        <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>清扫中</p>
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
        <p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>茶几区</p>
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
  const [captureError, setCaptureError] = useState<string | null>(null);

  const captureAfter = async () => {
    setFlash(true); setCaptureError(null);
    try {
      const result = await nativeRequest<{ preview?: string }>("capture.open", { source: "camera", purpose: "after" });
      if (result.preview) setAfterPhoto(result.preview);
    } catch (error) { if ((error as Error).message !== "已取消") setCaptureError((error as Error).message); }
    finally { setFlash(false); }
  };

  // Camera capture view
  if (!afterPhoto) {
    return (
      <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: "#1a1411" }}>
        {/* Live camera feed */}
        <ImageWithFallback src={AFTER_IMG} alt="相机" className="h-full w-full object-cover" />

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
                void captureAfter();
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

        <motion.button
          whileTap={{ scale: 0.96 }}
          transition={{ type: "spring", stiffness: 400, damping: 28 }}
          onClick={(e) => {
            const btn = e.currentTarget;
            const { left, top, width, height } = btn.getBoundingClientRect();
            const cx = left + width / 2;
            const cy = top + height / 2;

            // Fragment colors & positions: isometric-tile diamonds burst outward
            const frags = [
              { angle: -90,  dist: 58, size: 9,  color: ORANGE },
              { angle: -38,  dist: 64, size: 7,  color: BLUE },
              { angle:  14,  dist: 54, size: 8,  color: ORANGE },
              { angle:  66,  dist: 68, size: 6,  color: SOFT },
              { angle: 118,  dist: 56, size: 9,  color: ORANGE },
              { angle: 170,  dist: 62, size: 7,  color: BLUE },
              { angle:-142,  dist: 52, size: 8,  color: SOFT },
              { angle: -66,  dist: 72, size: 5,  color: ORANGE },
            ];

            frags.forEach(({ angle, dist, size, color }) => {
              const rad = (angle * Math.PI) / 180;
              const tx = Math.cos(rad) * dist;
              const ty = Math.sin(rad) * dist;
              const el = document.createElement("span");
              el.style.cssText = `
                position:fixed;
                left:${cx}px; top:${cy}px;
                width:${size}px; height:${size}px;
                background:${color};
                border-radius:2px;
                pointer-events:none;
                z-index:9999;
                box-shadow: 0 2px 8px rgba(250,136,58,0.28);
                transform:translate(-50%,-50%) rotate(45deg) scale(1);
                opacity:1;
                transition:transform 0.62s cubic-bezier(0.22,1,0.36,1),opacity 0.52s ease-out;
              `;
              document.body.appendChild(el);
              requestAnimationFrame(() =>
                requestAnimationFrame(() => {
                  el.style.transform = `translate(calc(-50% + ${tx}px),calc(-50% + ${ty}px)) rotate(45deg) scale(0.2)`;
                  el.style.opacity = "0";
                })
              );
              setTimeout(() => el.remove(), 700);
            });

            setTimeout(onClose, 660);
          }}
          className="w-full py-4 mt-6 flex items-center justify-center gap-2"
          style={{
            backgroundColor: ORANGE,
            color: WHITE,
            borderRadius: 999,
            fontSize: 15,
            fontWeight: 600,
            border: "none",
            cursor: "pointer",
            boxShadow: "0 8px 24px rgba(250,136,58,0.35)",
          }}
        >
          <CheckCircle2 size={16} />
          返回空间
        </motion.button>
      </div>
    </div>
  );
}

/* ---------- D. Zone Selection ---------- */

const SELECTABLE_ZONES = [
  { n: 1, label: "茶几区", color: ORANGE, left: "10%", top: "44%", w: "34%", h: "26%", items: 6, mins: 4 },
  { n: 2, label: "沙发区", color: BLUE, left: "44%", top: "30%", w: "40%", h: "42%", items: 9, mins: 7 },
  { n: 3, label: "书架角落", color: "#A88370", left: "6%", top: "8%", w: "30%", h: "26%", items: 4, mins: 3 },
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
          <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>选择区域</p>
          <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>可多选</p>
        </div>
        <div className="w-10" />
      </div>

      {/* Photo with zone overlays */}
      <div className="mx-5 mt-3 relative overflow-hidden" style={{ borderRadius: 22, aspectRatio: "3/4" }}>
        <ImageWithFallback src={ROOM_IMG} alt="空间场景" className="h-full w-full object-cover" />
        <div className="absolute inset-0" style={{ backgroundColor: "rgba(26,20,17,0.28)" }} />

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
  { from: "30%,55%", to: "12%,72%", label: "充电线" },
  { from: "55%,40%", to: "78%,30%", label: "Mug" },
  { from: "45%,68%", to: "22%,82%", label: "书籍" },
];

function ARPreviewStep({ onBack, onNext }: { onBack: () => void; onNext: () => void }) {
  const [demo, setDemo] = useState(false);
  const [warn, setWarn] = useState(true);
  const arSupported = true; // toggle for demo

  return (
    <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: "#13110f" }}>
      {/* 3D mesh background */}
      <div className="absolute inset-0">
        <ImageWithFallback src={ROOM_IMG} alt="空间场景" className="h-full w-full object-cover" />
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
            {demo ? "AR 实景" : "3D 预览"}
          </span>
        </div>
        <button
          onClick={() => setDemo((d) => !d)}
          className="h-10 px-3 rounded-full flex items-center gap-1.5"
          style={{ backgroundColor: demo ? ORANGE : "rgba(255,255,255,0.92)" }}
        >
          <Move3d size={14} color={demo ? WHITE : COFFEE} />
          <span style={{ color: demo ? WHITE : COFFEE, fontSize: 11, fontWeight: 600 }}>
            {demo ? "关闭" : "AR"}
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
            <p style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>检测到空间冲突</p>
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
    label: "茶几区",
    color: ORANGE,
    tasks: [
      { id: "z1t1", text: "把充电线绕好放进蓝色收纳盒" },
      { id: "z1t2", text: "把杯子移到厨房台面" },
      { id: "z1t3", text: "把书竖着堆在右侧" },
      { id: "z1t4", text: "用超细纤维布擦净台面" },
    ],
  },
  {
    zone: 2,
    label: "沙发区",
    color: BLUE,
    tasks: [
      { id: "z2t1", text: "把盖毯折好搭在沙发扶手上" },
      { id: "z2t2", text: "拍松并摆正靠垫" },
      { id: "z2t3", text: "把遥控器收进侧边收纳篮" },
    ],
  },
  {
    zone: 3,
    label: "书架角落",
    color: "#A88370",
    tasks: [
      { id: "z3t1", text: "按高度把书排在顶层隔板" },
      { id: "z3t2", text: "擦干净装饰碗" },
      { id: "z3t3", text: "把台灯线移到架子后面" },
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
              <ImageWithFallback src={ROOM_IMG} alt="整理前" className="h-full w-full object-cover" />
              <span
                className="absolute top-20 left-3 px-2 py-0.5"
                style={{ backgroundColor: "rgba(0,0,0,0.55)", color: WHITE, borderRadius: 6, fontSize: 10, fontWeight: 600 }}
              >
                BEFORE
              </span>
            </div>
            <div className="flex-1 relative overflow-hidden">
              <ImageWithFallback src={ROOM_IMG} alt="目标区域" className="h-full w-full object-cover" />
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
            <ImageWithFallback src={ROOM_IMG} alt="实时画面" className="h-full w-full object-cover" />
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
                <span style={{ color: WHITE, fontSize: 11 }}>正在显示原图 — 松手继续</span>
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
              {current?.text || "全部步骤已完成！"}
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
                  <span style={{ color: COFFEE, opacity: 0.5, fontSize: 10 }}>已跳过</span>
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
            {["物品没识别到", "不想收拾", "稍后再说"].map((r) => (
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

/* ================================================================== *
 *  RELIGHT FLOW — "重新点亮"
 *  Triggered from the overdue space card's Sparkles button.
 *  KEY RULE: restores the existing tile's colour — no new tile drops.
 * ================================================================== */

const CHAOS_SPOTS = [
  { x: "20%", y: "48%" },
  { x: "58%", y: "60%" },
  { x: "74%", y: "36%" },
  { x: "40%", y: "72%" },
  { x: "84%", y: "54%" },
];

function DisorderAnalysisStep({
  spaceName,
  onDone,
}: {
  spaceName: string;
  onDone: () => void;
}) {
  const [phase, setPhase] = useState(0);

  useEffect(() => {
    const t1 = setTimeout(() => setPhase(1), 1900);
    const t2 = setTimeout(() => setPhase(2), 3400);
    const done = setTimeout(onDone, 5500);
    return () => { [t1, t2, done].forEach(clearTimeout); };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div
      className="h-full w-full flex flex-col relative overflow-hidden"
      style={{ backgroundColor: "#0D0A07" }}
    >
      <ImageWithFallback
        src={ROOM_IMG}
        alt=""
        className="absolute inset-0 h-full w-full object-cover"
        style={{ opacity: 0.46 }}
      />

      {/* Scan sweep */}
      <AnimatePresence>
        {phase < 2 && (
          <motion.div
            className="absolute inset-0 pointer-events-none"
            exit={{ opacity: 0, transition: { duration: 0.4 } }}
          >
            <motion.div
              style={{
                position: "absolute", left: 0, right: 0, height: 2,
                background: `linear-gradient(90deg, transparent, ${ORANGE}, transparent)`,
                boxShadow: `0 0 14px 4px ${ORANGE}40`,
              }}
              animate={{ top: ["0%", "100%", "0%"] }}
              transition={{ duration: 3.4, repeat: Infinity, ease: "linear" }}
            />
            <div
              style={{
                position: "absolute", inset: 0,
                backgroundImage: `
                  linear-gradient(rgba(250,136,58,0.06) 1px, transparent 1px),
                  linear-gradient(90deg, rgba(250,136,58,0.06) 1px, transparent 1px)`,
                backgroundSize: "44px 44px",
              }}
            />
          </motion.div>
        )}
      </AnimatePresence>

      {/* Hotspot markers */}
      {phase >= 1 && CHAOS_SPOTS.map((s, i) => (
        <motion.div
          key={i}
          initial={{ opacity: 0, scale: 0 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: i * 0.2, type: "spring", stiffness: 360, damping: 22 }}
          style={{
            position: "absolute", left: s.x, top: s.y,
            transform: "translate(-50%, -50%)", zIndex: 10,
          }}
        >
          <div style={{ position: "relative", width: 30, height: 30 }}>
            <motion.div
              animate={{ scale: [1, 1.65], opacity: [0.45, 0] }}
              transition={{ duration: 1.3, repeat: Infinity, ease: "easeOut" }}
              style={{ position: "absolute", inset: 0, borderRadius: "50%", backgroundColor: "#E25A4A" }}
            />
            <div style={{
              position: "absolute", inset: 4, borderRadius: "50%",
              backgroundColor: "#E25A4A",
              display: "flex", alignItems: "center", justifyContent: "center",
            }}>
              <X size={11} color={WHITE} strokeWidth={2.5} />
            </div>
          </div>
        </motion.div>
      ))}

      {/* Status label */}
      <div style={{ position: "absolute", top: 60, left: 24, right: 24, zIndex: 12 }}>
        <p style={{ color: "rgba(255,255,255,0.5)", fontSize: 12, fontWeight: 600, letterSpacing: "0.06em" }}>
          {spaceName}
        </p>
        <AnimatePresence mode="wait">
          <motion.p
            key={phase}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.3 }}
            style={{ color: WHITE, fontSize: 22, fontWeight: 700, marginTop: 6, letterSpacing: "-0.02em" }}
          >
            {phase === 0 && "正在扫描空间状态…"}
            {phase === 1 && "检测到 5 处混乱区域"}
            {phase >= 2 && "分析完成"}
          </motion.p>
        </AnimatePresence>
      </div>

      {/* Results panel */}
      <AnimatePresence>
        {phase >= 2 && (
          <motion.div
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            transition={{ type: "spring", stiffness: 290, damping: 28 }}
            style={{
              position: "absolute", left: 0, right: 0, bottom: 0,
              backgroundColor: WHITE,
              borderTopLeftRadius: 32, borderTopRightRadius: 32,
              padding: "26px 24px 52px",
              zIndex: 20,
            }}
          >
            <p style={{ color: COFFEE, opacity: 0.45, fontSize: 12, fontWeight: 600 }}>空间混乱度评估</p>
            <div className="flex items-end gap-3 mt-2.5 mb-5">
              <p style={{ color: COFFEE, fontSize: 40, fontWeight: 800, letterSpacing: "-0.05em", lineHeight: 1 }}>62%</p>
              <p style={{ color: "#ECC079", fontSize: 17, fontWeight: 700, marginBottom: 6 }}>中度混乱</p>
            </div>
            <div style={{ height: 6, backgroundColor: SOFT, borderRadius: 999, overflow: "hidden", marginBottom: 18 }}>
              <motion.div
                initial={{ width: 0 }}
                animate={{ width: "62%" }}
                transition={{ duration: 1.0, ease: [0.22, 1, 0.36, 1] }}
                style={{ height: "100%", borderRadius: 999, backgroundColor: "#ECC079" }}
              />
            </div>
            <div className="space-y-2.5">
              {[
                { icon: "📦", text: "发现 5 处物品堆积区" },
                { icon: "⏱️", text: "预计整理约需 40 分钟" },
                { icon: "💡", text: "建议重新规划收纳动线" },
              ].map((item, i) => (
                <motion.div
                  key={i}
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.28 + i * 0.14 }}
                  className="flex items-center gap-3"
                >
                  <span style={{ fontSize: 15 }}>{item.icon}</span>
                  <p style={{ color: COFFEE, opacity: 0.68, fontSize: 13 }}>{item.text}</p>
                </motion.div>
              ))}
            </div>
            <motion.p
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 1.1 }}
              style={{ color: COFFEE, opacity: 0.35, fontSize: 11.5, marginTop: 18, textAlign: "center" }}
            >
              即将进入方案选择…
            </motion.p>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

function RelightChoiceStep({
  spaceName,
  spaceVivid,
  onTune,
  onNew,
}: {
  spaceName: string;
  spaceVivid: string;
  onTune: () => void;
  onNew: () => void;
}) {
  return (
    <div className="h-full w-full flex flex-col" style={{ backgroundColor: LINEN }}>
      <div style={{ paddingTop: 68, paddingLeft: 24, paddingRight: 24, paddingBottom: 20 }}>
        <p style={{ color: COFFEE, opacity: 0.45, fontSize: 12, fontWeight: 600, letterSpacing: "0.04em" }}>
          重新点亮 · {spaceName}
        </p>
        <p style={{ color: COFFEE, fontSize: 27, fontWeight: 800, letterSpacing: "-0.03em", marginTop: 8, lineHeight: 1.2 }}>
          选择整理方式
        </p>
        <p style={{ color: COFFEE, opacity: 0.5, fontSize: 13, marginTop: 10, lineHeight: 1.65 }}>
          在原有基础上微调，<br />还是探索全新的整理风格？
        </p>
      </div>

      <div style={{ flex: 1, padding: "0 20px", display: "flex", flexDirection: "column", gap: 14, minHeight: 0 }}>
        {/* Option A — Tweak existing plan */}
        <motion.button
          whileTap={{ scale: 0.97 }}
          transition={{ type: "spring", stiffness: 400, damping: 28 }}
          onClick={onTune}
          style={{
            flex: 1, borderRadius: 26, overflow: "hidden",
            position: "relative", border: "none", cursor: "pointer",
            backgroundColor: spaceVivid, textAlign: "left",
          }}
        >
          <div style={{ position: "absolute", inset: 0, background: "linear-gradient(145deg, rgba(255,255,255,0.20) 0%, transparent 55%)" }} />
          <div style={{ position: "relative", padding: "28px 24px 26px" }}>
            <div style={{ fontSize: 34, marginBottom: 14 }}>✏️</div>
            <p style={{ color: WHITE, fontSize: 20, fontWeight: 700, letterSpacing: "-0.02em" }}>在原方案基础上微调</p>
            <p style={{ color: "rgba(255,255,255,0.70)", fontSize: 13, marginTop: 8, lineHeight: 1.6 }}>
              保留原有整理习惯<br />轻松小调整，焕然一新
            </p>
            <div style={{
              display: "inline-flex", alignItems: "center",
              backgroundColor: "rgba(255,255,255,0.20)",
              borderRadius: 999, padding: "6px 16px", marginTop: 18,
            }}>
              <span style={{ color: WHITE, fontSize: 12, fontWeight: 600 }}>快速完成 · 约 20 分钟</span>
            </div>
          </div>
        </motion.button>

        {/* Option B — New style */}
        <motion.button
          whileTap={{ scale: 0.97 }}
          transition={{ type: "spring", stiffness: 400, damping: 28 }}
          onClick={onNew}
          style={{
            flex: 1, borderRadius: 26, overflow: "hidden",
            position: "relative", border: `2px solid ${SOFT}`,
            cursor: "pointer", backgroundColor: WHITE, textAlign: "left",
          }}
        >
          <div style={{ position: "relative", padding: "28px 24px 26px" }}>
            <div style={{ fontSize: 34, marginBottom: 14 }}>🌟</div>
            <p style={{ color: COFFEE, fontSize: 20, fontWeight: 700, letterSpacing: "-0.02em" }}>探索全新整理风格</p>
            <p style={{ color: COFFEE, opacity: 0.55, fontSize: 13, marginTop: 8, lineHeight: 1.6 }}>
              重新规划空间动线<br />找到当下最合适的收纳方式
            </p>
            <div style={{
              display: "inline-flex", alignItems: "center",
              backgroundColor: LINEN, borderRadius: 999, padding: "6px 16px", marginTop: 18,
            }}>
              <span style={{ color: COFFEE, fontSize: 12, fontWeight: 600, opacity: 0.65 }}>深度整理 · 约 40 分钟</span>
            </div>
          </div>
        </motion.button>
      </div>

      <div style={{ height: 44 }} />
    </div>
  );
}

function ProofCaptureStep({
  spaceName,
  onBack,
  onDone,
}: {
  spaceName: string;
  onBack: () => void;
  onDone: () => void;
}) {
  const [captured, setCaptured] = useState(false);
  const [flash, setFlash] = useState(false);

  function shoot() {
    setFlash(true);
    setTimeout(() => setFlash(false), 180);
    setTimeout(() => setCaptured(true), 280);
  }

  return (
    <div className="h-full w-full flex flex-col relative" style={{ backgroundColor: "#130F09" }}>
      <ImageWithFallback
        src={ROOM_IMG}
        alt=""
        className="absolute inset-0 h-full w-full object-cover"
        style={{ opacity: 0.72 }}
      />

      <AnimatePresence>
        {flash && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.07 }}
            className="absolute inset-0"
            style={{ backgroundColor: WHITE, zIndex: 60 }}
          />
        )}
      </AnimatePresence>

      {/* Header */}
      <div
        style={{
          position: "absolute", top: 0, left: 0, right: 0, zIndex: 10,
          background: "linear-gradient(180deg, rgba(0,0,0,0.58) 0%, transparent 100%)",
        }}
      >
        <div style={{ paddingTop: 58, paddingLeft: 20, paddingRight: 20, paddingBottom: 24 }}>
          <button
            onClick={onBack}
            className="h-9 w-9 rounded-full flex items-center justify-center mb-5"
            style={{ backgroundColor: "rgba(255,255,255,0.18)", backdropFilter: "blur(8px)" }}
          >
            <ArrowLeft size={16} color={WHITE} />
          </button>
          <p style={{ color: "rgba(255,255,255,0.55)", fontSize: 12, fontWeight: 600, letterSpacing: "0.04em" }}>整理完成</p>
          <p style={{ color: WHITE, fontSize: 20, fontWeight: 700, letterSpacing: "-0.02em", marginTop: 5 }}>拍摄留证</p>
          <p style={{ color: "rgba(255,255,255,0.45)", fontSize: 12.5, marginTop: 4 }}>记录整理后的 {spaceName}</p>
        </div>
      </div>

      {/* Captured preview */}
      <AnimatePresence>
        {captured && (
          <motion.div
            initial={{ opacity: 0, scale: 0.93 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ type: "spring", stiffness: 280, damping: 22 }}
            style={{
              position: "absolute", inset: 0, zIndex: 40,
              backgroundColor: "#130F09",
              display: "flex", flexDirection: "column",
            }}
          >
            <div style={{ flex: 1, position: "relative" }}>
              <ImageWithFallback src={ROOM_IMG} alt="拍摄留证" className="h-full w-full object-cover" />
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.18 }}
                style={{
                  position: "absolute", inset: 16,
                  border: `2.5px solid ${ORANGE}`, borderRadius: 22,
                  pointerEvents: "none",
                }}
              />
              <motion.div
                initial={{ scale: 0 }}
                animate={{ scale: 1 }}
                transition={{ type: "spring", stiffness: 320, damping: 16, delay: 0.3 }}
                style={{
                  position: "absolute", top: 28, right: 28,
                  width: 40, height: 40, borderRadius: "50%",
                  backgroundColor: ORANGE,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  boxShadow: "0 4px 14px rgba(250,136,58,0.5)",
                }}
              >
                <Check size={20} color={WHITE} strokeWidth={2.5} />
              </motion.div>
            </div>
            <div style={{ padding: "20px 20px 44px", backgroundColor: "#130F09" }}>
              <motion.button
                whileTap={{ scale: 0.97 }}
                onClick={onDone}
                style={{
                  width: "100%", padding: "16px 0",
                  backgroundColor: ORANGE, color: WHITE,
                  borderRadius: 999, fontSize: 15, fontWeight: 700,
                  border: "none", cursor: "pointer",
                  boxShadow: "0 8px 24px rgba(250,136,58,0.4)",
                }}
              >
                完成整理 ✦
              </motion.button>
              <button
                onClick={() => setCaptured(false)}
                style={{
                  width: "100%", marginTop: 12, padding: "12px 0",
                  backgroundColor: "transparent", color: "rgba(255,255,255,0.5)",
                  fontSize: 13, fontWeight: 500, border: "none", cursor: "pointer",
                }}
              >
                重新拍摄
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Shutter controls */}
      {!captured && (
        <div
          style={{
            position: "absolute", bottom: 0, left: 0, right: 0,
            paddingBottom: 50, paddingTop: 28,
            background: "linear-gradient(0deg, rgba(0,0,0,0.72) 0%, transparent 100%)",
            display: "flex", flexDirection: "column", alignItems: "center",
            gap: 18, zIndex: 10,
          }}
        >
          <div className="flex items-center gap-3">
            <div style={{
              width: 46, height: 46, borderRadius: 10,
              overflow: "hidden", border: "2px solid rgba(255,255,255,0.35)",
            }}>
              <ImageWithFallback
                src={ROOM_IMG} alt="整理前"
                className="w-full h-full object-cover"
                style={{ opacity: 0.65 }}
              />
            </div>
            <div>
              <p style={{ color: "rgba(255,255,255,0.65)", fontSize: 11, fontWeight: 600 }}>整理前对比</p>
              <p style={{ color: "rgba(255,255,255,0.35)", fontSize: 10.5 }}>已保存快照</p>
            </div>
          </div>
          <button
            onClick={shoot}
            style={{
              width: 76, height: 76, borderRadius: "50%",
              backgroundColor: WHITE,
              boxShadow: "0 0 0 5px rgba(255,255,255,0.28)",
              border: "none", cursor: "pointer",
              display: "flex", alignItems: "center", justifyContent: "center",
            }}
          >
            <div style={{ width: 60, height: 60, borderRadius: "50%", border: `3px solid ${COFFEE}` }} />
          </button>
        </div>
      )}
    </div>
  );
}

function RelightCompleteStep({
  spaceName,
  spaceVivid,
  onReturn,
}: {
  spaceName: string;
  spaceVivid: string;
  onReturn: () => void;
}) {
  return (
    <div
      className="h-full w-full flex flex-col items-center justify-center relative overflow-hidden"
      style={{ backgroundColor: LINEN }}
    >
      {/* Ambient glow */}
      <motion.div
        animate={{ scale: [1, 1.12, 1], opacity: [0.22, 0.38, 0.22] }}
        transition={{ duration: 4.2, repeat: Infinity, ease: "easeInOut" }}
        style={{
          position: "absolute", width: 300, height: 300, borderRadius: "50%",
          background: `radial-gradient(circle, ${spaceVivid}50, transparent 70%)`,
          top: "18%", transform: "translateY(-42%)",
          pointerEvents: "none",
        }}
      />

      {/* Spinning sparkle ring + centre tile */}
      <div style={{ position: "relative", width: 200, height: 200, marginBottom: 36 }}>
        <motion.div
          animate={{ rotate: 360 }}
          transition={{ duration: 9, repeat: Infinity, ease: "linear" }}
          style={{ position: "absolute", inset: 0 }}
        >
          {[0, 1, 2, 3, 4, 5].map((i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, scale: 0 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: 0.45 + i * 0.1, type: "spring", stiffness: 260, damping: 18 }}
              style={{
                position: "absolute",
                left: "50%", top: "50%",
                transform: `rotate(${i * 60}deg) translateY(-92px) translate(-50%, -50%)`,
                color: i % 2 === 0 ? ORANGE : BLUE,
                display: "flex", alignItems: "center", justifyContent: "center",
              }}
            >
              <Sparkles size={i % 2 === 0 ? 14 : 11} />
            </motion.div>
          ))}
        </motion.div>

        {/* Tile: grey → space colour */}
        <motion.div
          initial={{ scale: 0.55, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ type: "spring", stiffness: 190, damping: 12, delay: 0.15 }}
          style={{ position: "absolute", inset: 22 }}
        >
          <motion.div
            initial={{ backgroundColor: "#C7C0B4" }}
            animate={{ backgroundColor: spaceVivid }}
            transition={{ duration: 1.8, ease: "easeOut", delay: 0.45 }}
            style={{
              width: "100%", height: "100%",
              borderRadius: 28,
              display: "flex", alignItems: "center", justifyContent: "center",
              position: "relative", overflow: "hidden",
            }}
          >
            <div
              style={{
                position: "absolute", inset: 0,
                backgroundImage: `url("data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20width='120'%20height='120'%3E%3Cfilter%20id='n'%3E%3CfeTurbulence%20type='fractalNoise'%20baseFrequency='0.85'%20numOctaves='2'%20stitchTiles='stitch'/%3E%3CfeColorMatrix%20type='saturate'%20values='0'/%3E%3C/filter%3E%3Crect%20width='100%25'%20height='100%25'%20filter='url(%23n)'/%3E%3C/svg%3E")`,
                backgroundSize: "120px 120px",
                mixBlendMode: "soft-light", opacity: 0.42,
              }}
            />
            <motion.div
              initial={{ opacity: 0.95 }}
              animate={{ opacity: 0 }}
              transition={{ duration: 1.6, ease: "easeOut", delay: 0.45 }}
              style={{
                position: "absolute", inset: 0,
                background: "radial-gradient(circle at 50% 44%, rgba(255,255,255,0.95), transparent 68%)",
              }}
            />
            <span style={{ fontSize: 38, position: "relative" }}>✨</span>
          </motion.div>
        </motion.div>
      </div>

      {/* Text block */}
      <motion.div
        initial={{ opacity: 0, y: 18 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.55, duration: 0.5, ease: "easeOut" }}
        style={{ textAlign: "center", paddingLeft: 36, paddingRight: 36 }}
      >
        <p style={{ color: ORANGE, fontSize: 12, fontWeight: 700, letterSpacing: "0.09em" }}>空间已点亮</p>
        <h2 style={{ color: COFFEE, fontSize: 26, fontWeight: 800, letterSpacing: "-0.03em", marginTop: 8, lineHeight: 1.25 }}>
          「{spaceName}」<br />重新焕发光彩
        </h2>
        <p style={{ color: COFFEE, opacity: 0.5, fontSize: 13.5, marginTop: 12, lineHeight: 1.65 }}>
          整理记录已更新<br />空间碎片颜色已恢复
        </p>
      </motion.div>

      {/* Stats row */}
      <motion.div
        initial={{ opacity: 0, scale: 0.94 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.85, duration: 0.4 }}
        style={{ display: "flex", gap: 32, marginTop: 30 }}
      >
        {[
          { value: "40", unit: "分钟", label: "整理时长" },
          { value: "1", unit: "次", label: "本次整理" },
          { value: "12", unit: "件", label: "收纳物品" },
        ].map((s) => (
          <div key={s.label} style={{ textAlign: "center" }}>
            <p style={{ color: COFFEE, fontSize: 22, fontWeight: 800, letterSpacing: "-0.02em" }}>
              {s.value}
              <span style={{ fontSize: 12, fontWeight: 600, marginLeft: 1 }}>{s.unit}</span>
            </p>
            <p style={{ color: COFFEE, opacity: 0.42, fontSize: 11.5, marginTop: 3 }}>{s.label}</p>
          </div>
        ))}
      </motion.div>

      {/* Return button */}
      <motion.button
        initial={{ opacity: 0, y: 14 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 1.05 }}
        whileTap={{ scale: 0.97 }}
        onClick={onReturn}
        style={{
          marginTop: 38, width: 290, padding: "16px 0",
          backgroundColor: ORANGE, color: WHITE,
          borderRadius: 999, fontSize: 15, fontWeight: 700,
          border: "none", cursor: "pointer",
          boxShadow: "0 10px 30px rgba(250,136,58,0.32)",
        }}
      >
        返回我的空间地图
      </motion.button>
    </div>
  );
}

/* ---------- RelightFlow coordinator ---------- */

export type RelightFlowProps = {
  spaceId: string;
  spaceName: string;
  spaceVivid: string;
  onClose: () => void;
  onComplete: (id: string) => void;
};

type RelightStep =
  | "capture"
  | "analyzing"
  | "choice"
  | "tune"
  | "plandeck"
  | "zones"
  | "proof"
  | "complete";

export function RelightFlow({ spaceId, spaceName, spaceVivid, onClose, onComplete }: RelightFlowProps) {
  const [step, setStep] = useState<RelightStep>("capture");
  const [chosen, setChosen] = useState<GenPlan>(GEN_PLANS[0]);
  const [relightMode, setRelightMode] = useState<"tune" | "new">("tune");

  return (
    <div className="absolute inset-0 z-50" style={{ backgroundColor: LINEN }}>
      {step === "capture" && (
        <CaptureStep
          onClose={onClose}
          on完成={(_assets) => setStep("analyzing")}
        />
      )}
      {step === "analyzing" && (
        <DisorderAnalysisStep
          spaceName={spaceName}
          onDone={() => setStep("choice")}
        />
      )}
      {step === "choice" && (
        <RelightChoiceStep
          spaceName={spaceName}
          spaceVivid={spaceVivid}
          onTune={() => { setRelightMode("tune"); setStep("tune"); }}
          onNew={() => { setRelightMode("new"); setStep("plandeck"); }}
        />
      )}
      {step === "tune" && (
        <TuneChatStep
          plan={chosen}
          onBack={() => setStep("choice")}
          onConfirm={(refined) => { setChosen(refined); setStep("zones"); }}
        />
      )}
      {step === "plandeck" && (
        <PlanDeckStep
          plans={GEN_PLANS}
          onClose={() => setStep("choice")}
          onStart={(p) => { setChosen(p); setStep("zones"); }}
          onTune={(p) => { setChosen(p); setStep("tune"); }}
        />
      )}
      {step === "zones" && (
        <ZoneSelectStep
          onBack={() => setStep(relightMode === "tune" ? "tune" : "plandeck")}
          onNext={() => setStep("proof")}
        />
      )}
      {step === "proof" && (
        <ProofCaptureStep
          spaceName={spaceName}
          onBack={() => setStep("zones")}
          onDone={() => setStep("complete")}
        />
      )}
      {step === "complete" && (
        <RelightCompleteStep
          spaceName={spaceName}
          spaceVivid={spaceVivid}
          onReturn={() => onComplete(spaceId)}
        />
      )}
    </div>
  );
}
