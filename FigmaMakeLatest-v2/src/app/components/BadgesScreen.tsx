import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { ArrowLeft, Lock, Sparkles, Share2, X } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import type { NativeState } from "../nativeBridge";

type Badge = {
  id: string;
  name: string;
  emoji: string;
  desc: string;
  rarity: "common" | "rare" | "epic" | "legendary";
  earnedAt?: string;
  progress?: number;
  locked?: boolean;
};

// 原生 Achievement.iconName 用的是 SF Symbol 名，这里映射成页面用的图形
const iconEmoji: Record<string, string> = {
  "camera.viewfinder": "📷",
  "photo.on.rectangle.angled": "🖼️",
  "square.on.square": "🧩",
  tag: "🏷️",
  timer: "⏱️",
  sparkles: "✨",
  flame: "🔥",
  leaf: "🌿",
  "cube.box": "📦",
  target: "🎯",
  "checkmark.seal": "🏅",
  trophy: "🏆",
};

const rarityOrder: Badge["rarity"][] = ["common", "rare", "epic", "legendary"];

const rarityColor: Record<Badge["rarity"], { bg: string; ring: string; label: string }> = {
  common: { bg: "#B4C7DC", ring: "#B4C7DC", label: "普通" },
  rare: { bg: "#A8B8CC", ring: "#7FA8C9", label: "稀有" },
  epic: { bg: "#FA883A", ring: "#FFAA66", label: "史诗" },
  legendary: { bg: "#FFD58A", ring: "#FFB347", label: "传说" },
};

const filters = ["全部", "已解锁", "未解锁"] as const;

export function BadgesScreen({ onBack, nativeState }: { onBack: () => void; nativeState?: NativeState | null }) {
  const [filter, setFilter] = useState<(typeof filters)[number]>("全部");

  // 徽章来自原生 AppViewModel.achievements，完成扫描/整理后会自动解锁新徽章
  const badges: Badge[] = (nativeState?.achievements ?? []).map((achievement, index) => ({
    id: achievement.id,
    name: achievement.title,
    emoji: iconEmoji[achievement.iconName] ?? "🎖️",
    desc: achievement.subtitle,
    rarity: rarityOrder[index % rarityOrder.length],
    earnedAt: "已解锁",
  }));
  const [active, setActive] = useState<Badge | null>(null);

  const earnedCount = badges.filter((b) => !b.locked).length;

  const filtered = badges.filter((b) => {
    if (filter === "已解锁") return !b.locked;
    if (filter === "未解锁") return b.locked;
    return true;
  });

  return (
    <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: LINEN }}>
      <div className="h-full w-full overflow-y-auto pb-10">
        {/* Top bar */}
        <div className="px-6 pt-14 pb-2 flex items-center justify-between">
          <button
            onClick={onBack}
            className="h-11 w-11 rounded-full flex items-center justify-center"
            style={{ backgroundColor: WHITE }}
          >
            <ArrowLeft size={20} color={COFFEE} />
          </button>
          <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>徽章</p>
          <button
            className="h-11 w-11 rounded-full flex items-center justify-center"
            style={{ backgroundColor: WHITE }}
          >
            <Share2 size={18} color={COFFEE} />
          </button>
        </div>

        {/* Hero — animated showcase */}
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, ease: "easeOut" }}
          className="mx-6 mt-4 p-6 relative overflow-hidden"
          style={{
            background: `linear-gradient(135deg, ${COFFEE} 0%, #5d4334 100%)`,
            borderRadius: 28,
          }}
        >
          {/* Glow blobs */}
          <motion.div
            animate={{
              x: [0, 30, 0],
              y: [0, -20, 0],
              opacity: [0.5, 0.8, 0.5],
            }}
            transition={{ duration: 8, repeat: Infinity, ease: "easeInOut" }}
            className="absolute"
            style={{
              top: -40,
              right: -40,
              width: 180,
              height: 180,
              borderRadius: "50%",
              background: `radial-gradient(circle, ${ORANGE}88 0%, transparent 70%)`,
              filter: "blur(20px)",
            }}
          />
          <motion.div
            animate={{
              x: [0, -20, 0],
              y: [0, 15, 0],
              opacity: [0.3, 0.6, 0.3],
            }}
            transition={{ duration: 10, repeat: Infinity, ease: "easeInOut" }}
            className="absolute"
            style={{
              bottom: -30,
              left: -30,
              width: 150,
              height: 150,
              borderRadius: "50%",
              background: `radial-gradient(circle, #FFD58A88 0%, transparent 70%)`,
              filter: "blur(20px)",
            }}
          />

          <div className="relative flex items-center gap-4">
            <motion.div
              className="h-20 w-20 rounded-3xl flex items-center justify-center"
              style={{ backgroundColor: "rgba(255,255,255,0.12)", fontSize: 40 }}
              animate={{
                rotate: [0, -5, 5, 0],
                scale: [1, 1.05, 1],
              }}
              transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
            >
              💎
            </motion.div>
            <div className="flex-1">
              <p style={{ color: WHITE, opacity: 0.7, fontSize: 11 }}>已获得徽章</p>
              <motion.p
                key={earnedCount}
                initial={{ scale: 0.8, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                style={{ color: WHITE, fontSize: 32, fontWeight: 600 }}
              >
                {earnedCount} 枚
              </motion.p>
              <div
                className="mt-1.5 h-1.5 w-full rounded-full overflow-hidden"
                style={{ backgroundColor: "rgba(255,255,255,0.15)" }}
              >
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${badges.length ? (earnedCount / badges.length) * 100 : 0}%` }}
                  transition={{ duration: 1.2, ease: "easeOut", delay: 0.2 }}
                  className="h-full rounded-full"
                  style={{
                    background: `linear-gradient(90deg, ${ORANGE} 0%, #FFD58A 100%)`,
                  }}
                />
              </div>
            </div>
          </div>
        </motion.div>

        {/* Filter pills */}
        <div className="px-6 mt-5 flex gap-2">
          {filters.map((f) => {
            const active = filter === f;
            return (
              <motion.button
                key={f}
                onClick={() => setFilter(f)}
                whileTap={{ scale: 0.94 }}
                className="px-4 py-2"
                style={{
                  backgroundColor: active ? ORANGE : WHITE,
                  color: active ? WHITE : COFFEE,
                  borderRadius: 999,
                  fontSize: 12,
                  fontWeight: active ? 600 : 500,
                }}
                animate={
                  active
                    ? { boxShadow: "0 6px 16px rgba(250,136,58,0.3)" }
                    : { boxShadow: "0 2px 8px rgba(123,92,72,0.04)" }
                }
              >
                {f}
              </motion.button>
            );
          })}
        </div>

        {/* Badge grid */}
        <motion.div
          layout
          className="px-6 mt-5 grid grid-cols-3 gap-3"
        >
          <AnimatePresence>
            {filtered.map((b, i) => (
              <motion.button
                key={b.id}
                layout
                initial={{ opacity: 0, scale: 0.85, y: 12 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.85 }}
                transition={{ duration: 0.35, delay: i * 0.04, ease: "easeOut" }}
                whileTap={{ scale: 0.94 }}
                whileHover={{ y: -3 }}
                onClick={() => setActive(b)}
                className="relative flex flex-col items-center p-3"
                style={{
                  backgroundColor: WHITE,
                  borderRadius: 20,
                  boxShadow: b.locked
                    ? "0 2px 8px rgba(123,92,72,0.04)"
                    : `0 4px 14px ${rarityColor[b.rarity].ring}33`,
                }}
              >
                <BadgeIcon badge={b} />
                <p
                  style={{
                    color: COFFEE,
                    fontSize: 11,
                    fontWeight: 600,
                    marginTop: 8,
                    textAlign: "center",
                    opacity: b.locked ? 0.45 : 1,
                  }}
                >
                  {b.name}
                </p>
                {b.locked && b.progress !== undefined && b.progress > 0 && (
                  <div
                    className="mt-1.5 h-1 w-12 rounded-full overflow-hidden"
                    style={{ backgroundColor: SOFT }}
                  >
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{ width: `${b.progress}%` }}
                      transition={{ duration: 1, ease: "easeOut", delay: i * 0.04 + 0.4 }}
                      className="h-full"
                      style={{ backgroundColor: ORANGE }}
                    />
                  </div>
                )}
              </motion.button>
            ))}
          </AnimatePresence>
        </motion.div>


        {filtered.length === 0 && (
          <div className="px-6 mt-6">
            <div className="p-6 text-center" style={{ backgroundColor: WHITE, borderRadius: 18 }}>
              <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>
                还没有徽章，完成一次扫描整理即可解锁
              </p>
            </div>
          </div>
        )}

        {/* Rarity legend */}
        <div className="px-6 mt-7">
          <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600, marginBottom: 10 }}>
            稀有度
          </p>
          <div className="flex flex-wrap gap-2">
            {Object.entries(rarityColor).map(([k, v]) => (
              <div
                key={k}
                className="flex items-center gap-2 px-3 py-2"
                style={{ backgroundColor: WHITE, borderRadius: 999 }}
              >
                <span
                  className="h-2.5 w-2.5 rounded-full"
                  style={{ backgroundColor: v.ring }}
                />
                <span style={{ color: COFFEE, fontSize: 11, fontWeight: 500 }}>{v.label}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Badge detail modal */}
      <AnimatePresence>
        {active && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="absolute inset-0 z-50 flex items-center justify-center px-7"
            style={{ backgroundColor: "rgba(45,32,26,0.55)" }}
            onClick={() => setActive(null)}
          >
            <motion.div
              onClick={(e) => e.stopPropagation()}
              initial={{ scale: 0.85, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.85, opacity: 0 }}
              transition={{ type: "spring", stiffness: 320, damping: 26 }}
              className="relative w-full p-7 overflow-hidden"
              style={{ backgroundColor: WHITE, borderRadius: 32 }}
            >
              <button
                onClick={() => setActive(null)}
                className="absolute top-4 right-4 h-9 w-9 rounded-full flex items-center justify-center z-10"
                style={{ backgroundColor: LINEN }}
              >
                <X size={16} color={COFFEE} />
              </button>

              {/* Animated halo */}
              {!active.locked && (
                <motion.div
                  animate={{
                    scale: [1, 1.15, 1],
                    opacity: [0.4, 0.7, 0.4],
                  }}
                  transition={{ duration: 2.4, repeat: Infinity, ease: "easeInOut" }}
                  className="absolute"
                  style={{
                    top: 30,
                    left: "50%",
                    transform: "translateX(-50%)",
                    width: 200,
                    height: 200,
                    borderRadius: "50%",
                    background: `radial-gradient(circle, ${rarityColor[active.rarity].ring}55 0%, transparent 70%)`,
                    filter: "blur(8px)",
                  }}
                />
              )}

              <div className="relative flex flex-col items-center text-center">
                <motion.div
                  initial={{ scale: 0, rotate: -90 }}
                  animate={{ scale: 1, rotate: 0 }}
                  transition={{ type: "spring", stiffness: 200, damping: 14, delay: 0.1 }}
                  className="h-28 w-28 rounded-full flex items-center justify-center mb-4"
                  style={{
                    background: active.locked
                      ? `linear-gradient(135deg, ${SOFT} 0%, #d8cdc1 100%)`
                      : `linear-gradient(135deg, ${rarityColor[active.rarity].bg} 0%, ${rarityColor[active.rarity].ring} 100%)`,
                    boxShadow: active.locked
                      ? "none"
                      : `0 12px 30px ${rarityColor[active.rarity].ring}66, inset 0 -8px 20px rgba(0,0,0,0.1)`,
                  }}
                >
                  <span style={{ fontSize: 56, filter: active.locked ? "grayscale(1)" : "none", opacity: active.locked ? 0.5 : 1 }}>
                    {active.emoji}
                  </span>
                  {active.locked && (
                    <div
                      className="absolute h-9 w-9 rounded-full flex items-center justify-center"
                      style={{ backgroundColor: COFFEE, bottom: -2, right: -2 }}
                    >
                      <Lock size={16} color={WHITE} />
                    </div>
                  )}
                </motion.div>

                <span
                  className="px-3 py-1 mb-2"
                  style={{
                    backgroundColor: rarityColor[active.rarity].ring,
                    color: WHITE,
                    borderRadius: 999,
                    fontSize: 10,
                    fontWeight: 600,
                  }}
                >
                  {rarityColor[active.rarity].label.toUpperCase()}
                </span>

                <p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>{active.name}</p>
                <p
                  style={{
                    color: COFFEE,
                    opacity: 0.65,
                    fontSize: 13,
                    marginTop: 6,
                    lineHeight: 1.5,
                  }}
                >
                  {active.desc}
                </p>

                {active.locked ? (
                  <div className="w-full mt-5">
                    <div className="flex items-center justify-between mb-2">
                      <span style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>进度</span>
                      <span style={{ color: ORANGE, fontSize: 12, fontWeight: 600 }}>
                        {active.progress ?? 0}%
                      </span>
                    </div>
                    <div
                      className="h-2 w-full rounded-full overflow-hidden"
                      style={{ backgroundColor: LINEN }}
                    >
                      <motion.div
                        initial={{ width: 0 }}
                        animate={{ width: `${active.progress ?? 0}%` }}
                        transition={{ duration: 0.9, ease: "easeOut", delay: 0.3 }}
                        className="h-full"
                        style={{
                          background: `linear-gradient(90deg, ${ORANGE} 0%, #FFAA66 100%)`,
                        }}
                      />
                    </div>
                  </div>
                ) : (
                  <div
                    className="mt-4 px-4 py-2 flex items-center gap-2"
                    style={{ backgroundColor: LINEN, borderRadius: 999 }}
                  >
                    <Sparkles size={12} color={ORANGE} />
                    <span style={{ color: COFFEE, fontSize: 11 }}>
                      {active.earnedAt ?? "已解锁"}
                    </span>
                  </div>
                )}

                <button
                  onClick={() => setActive(null)}
                  className="w-full mt-5 py-3"
                  style={{
                    backgroundColor: active.locked ? LINEN : ORANGE,
                    color: active.locked ? COFFEE : WHITE,
                    borderRadius: 999,
                    fontSize: 13,
                    fontWeight: 600,
                    boxShadow: active.locked ? "none" : "0 6px 16px rgba(250,136,58,0.3)",
                  }}
                >
                  {active.locked ? "继续加油" : "分享徽章"}
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

function BadgeIcon({ badge }: { badge: Badge }) {
  const r = rarityColor[badge.rarity];
  return (
    <div className="relative">
      <motion.div
        whileHover={badge.locked ? {} : { rotate: [0, -8, 8, 0] }}
        transition={{ duration: 0.5 }}
        className="h-16 w-16 rounded-2xl flex items-center justify-center"
        style={{
          background: badge.locked
            ? `linear-gradient(135deg, ${SOFT} 0%, #d8cdc1 100%)`
            : `linear-gradient(135deg, ${r.bg} 0%, ${r.ring} 100%)`,
          boxShadow: badge.locked
            ? "none"
            : `0 6px 16px ${r.ring}55, inset 0 -4px 10px rgba(0,0,0,0.08)`,
          fontSize: 28,
          filter: badge.locked ? "grayscale(0.8)" : "none",
          opacity: badge.locked ? 0.5 : 1,
        }}
      >
        {badge.emoji}
      </motion.div>
      {badge.locked && (
        <div
          className="absolute h-6 w-6 rounded-full flex items-center justify-center"
          style={{
            backgroundColor: COFFEE,
            bottom: -4,
            right: -4,
            border: `2px solid ${WHITE}`,
          }}
        >
          <Lock size={11} color={WHITE} />
        </div>
      )}
    </div>
  );
}
