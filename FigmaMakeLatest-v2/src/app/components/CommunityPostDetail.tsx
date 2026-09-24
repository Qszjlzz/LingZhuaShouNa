import { useState } from "react";
import {
  ArrowLeft,
  MoreHorizontal,
  Heart,
  Bookmark,
  MessageCircle,
  ChevronLeft,
  ChevronRight,
  CheckCircle2,
  Send,
} from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { TryPlanScreen } from "./TryPlanScreen";
import { nativeRequest, type NativeState } from "../nativeBridge";

// 案例自带 before/after 资源名指向 App 内置图片，网页侧先用占位图呈现改造前后
const beforeAfter = [
  "https://images.unsplash.com/photo-1775029918191-32e44ee20d06?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
  "https://images.unsplash.com/photo-1749705319317-f3a2bf24fe3d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
];

const avatarColors = ["#E8B894", "#B4D4C9", "#D9B4C7", "#A8B8CC", "#C9A687"];

export function CommunityPostDetail({
  onBack,
  caseID,
  nativeState,
  onNativeChange,
}: {
  onBack: () => void;
  caseID?: string | null;
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
}) {
  const [idx, setIdx] = useState(0);
  const [draft, setDraft] = useState("");
  const [tryingPlan, setTryingPlan] = useState(false);

  const item = (nativeState?.communityCases ?? []).find((c) => c.id === caseID);
  const liked = caseID ? (nativeState?.liked ?? []).includes(caseID) : false;
  const saved = caseID ? (nativeState?.favorites ?? []).includes(caseID) : false;
  const following = item ? (nativeState?.followedAuthors ?? []).includes(item.author) : false;
  const comments = (caseID ? nativeState?.comments?.[caseID] : undefined) ?? [];

  const mutate = (command: string, payload: Record<string, unknown>) => {
    void nativeRequest(command, payload)
      .then(() => onNativeChange?.())
      .catch(() => undefined);
  };

  if (tryingPlan && item) {
    return (
      <TryPlanScreen
        caseItem={{
          id: item.id,
          title: item.title,
          author: item.author,
          style: item.style,
          durationText: item.durationText,
          difficultyText: item.difficultyText,
          items: (item.items ?? []).map((entry) => ({
            id: entry.id, name: entry.name, category: entry.category, suggestedZone: entry.suggestedZone,
          })),
        }}
        spaces={(nativeState?.spaces ?? []).map((space) => space.name)}
        onNativeChange={onNativeChange}
        onBack={() => setTryingPlan(false)}
      />
    );
  }

  if (!item) {
    return (
      <div className="h-full w-full flex flex-col items-center justify-center px-8" style={{ backgroundColor: WHITE }}>
        <p style={{ color: COFFEE, fontSize: 14, opacity: 0.6 }}>没有找到这个案例</p>
        <button
          onClick={onBack}
          className="mt-4 px-5 py-2.5"
          style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, fontSize: 13, fontWeight: 600 }}
        >
          返回社区
        </button>
      </div>
    );
  }

  const items = item.items ?? [];
  const tags = item.tags ?? [];

  return (
    <div className="relative h-full w-full" style={{ backgroundColor: WHITE }}>
      {/* Top bar (overlays photo) */}
      <div className="absolute top-0 left-0 right-0 z-30 px-5 pt-14 pb-2 flex items-center justify-between">
        <button
          onClick={onBack}
          className="h-10 w-10 rounded-full flex items-center justify-center"
          style={{ backgroundColor: "rgba(255,255,255,0.92)" }}
        >
          <ArrowLeft size={20} color={COFFEE} />
        </button>

        <div className="flex items-center gap-2">
          <div className="flex items-center gap-2 pr-3 pl-1 py-1" style={{ backgroundColor: "rgba(255,255,255,0.92)", borderRadius: 999 }}>
            <div
              className="h-8 w-8 rounded-full flex items-center justify-center"
              style={{ backgroundColor: avatarColors[0], color: WHITE, fontSize: 12, fontWeight: 600 }}
            >
              {String(item.author || "?").slice(0, 1)}
            </div>
            <span style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>{item.author}</span>
            <button
              onClick={() => mutate("community.follow", { author: item.author })}
              className="px-3 py-1 ml-1"
              style={{
                backgroundColor: following ? LINEN : ORANGE,
                color: following ? COFFEE : WHITE,
                borderRadius: 999,
                fontSize: 11,
                fontWeight: 600,
              }}
            >
              {following ? "已关注" : "+ 关注"}
            </button>
          </div>
          <button
            className="h-10 w-10 rounded-full flex items-center justify-center"
            style={{ backgroundColor: "rgba(255,255,255,0.92)" }}
          >
            <MoreHorizontal size={18} color={COFFEE} />
          </button>
        </div>
      </div>

      <div className="h-full w-full overflow-y-auto pb-28">
        {/* Image carousel */}
        <div className="relative w-full bg-black" style={{ height: 440 }}>
          <ImageWithFallback
            src={beforeAfter[idx]}
            alt={idx === 0 ? "改造前" : "改造后"}
            className="h-full w-full object-cover"
          />

          <span
            className="absolute top-14 left-5 px-2.5 py-1"
            style={{
              backgroundColor: idx === 0 ? "rgba(123,92,72,0.85)" : "rgba(250,136,58,0.9)",
              color: WHITE,
              borderRadius: 999,
              fontSize: 11,
              fontWeight: 600,
            }}
          >
            {idx === 0 ? "改造前" : "改造后"}
          </span>

          <span
            className="absolute top-14 right-5 px-2.5 py-1"
            style={{ backgroundColor: "rgba(0,0,0,0.45)", color: WHITE, borderRadius: 999, fontSize: 11, fontWeight: 600 }}
          >
            {idx + 1} / {beforeAfter.length}
          </span>

          {idx > 0 && (
            <button
              onClick={() => setIdx((i) => i - 1)}
              className="absolute left-3 top-1/2 -translate-y-1/2 h-9 w-9 rounded-full flex items-center justify-center"
              style={{ backgroundColor: "rgba(255,255,255,0.85)" }}
            >
              <ChevronLeft size={18} color={COFFEE} />
            </button>
          )}
          {idx < beforeAfter.length - 1 && (
            <button
              onClick={() => setIdx((i) => i + 1)}
              className="absolute right-3 top-1/2 -translate-y-1/2 h-9 w-9 rounded-full flex items-center justify-center"
              style={{ backgroundColor: "rgba(255,255,255,0.85)" }}
            >
              <ChevronRight size={18} color={COFFEE} />
            </button>
          )}

          <div className="absolute bottom-3 left-0 right-0 flex justify-center gap-1.5">
            {beforeAfter.map((_, i) => (
              <span
                key={i}
                className="h-1.5 rounded-full"
                style={{
                  width: i === idx ? 18 : 6,
                  backgroundColor: i === idx ? WHITE : "rgba(255,255,255,0.5)",
                  transition: "width 0.2s",
                }}
              />
            ))}
          </div>
        </div>

        {/* Body */}
        <div className="px-5 pt-5">
          <p style={{ color: COFFEE, fontSize: 18, fontWeight: 600, lineHeight: 1.35 }}>{item.title}</p>
          <p style={{ color: COFFEE, fontSize: 13, lineHeight: 1.65, marginTop: 10, opacity: 0.85 }}>
            {item.author} 用「{item.style}」的思路完成了这次整理：预计 {item.durationText}，难度{item.difficultyText}，
            共涉及 {items.length} 件物品。
          </p>

          {/* Items */}
          {items.length > 0 && (
            <div className="mt-5">
              <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600, marginBottom: 10 }}>
                涉及的物品 👇
              </p>
              <div className="space-y-2.5">
                {items.map((entry, i) => (
                  <div key={`${entry.id}-${i}`} className="flex gap-3 items-start">
                    <div
                      className="h-6 w-6 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5"
                      style={{ backgroundColor: ORANGE, color: WHITE, fontSize: 11, fontWeight: 600 }}
                    >
                      {i + 1}
                    </div>
                    <p style={{ color: COFFEE, fontSize: 13, lineHeight: 1.55 }}>
                      {entry.name}
                      <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>
                        {" "}
                        · {entry.category} · 建议放在{entry.suggestedZone || "就近区域"}
                      </span>
                    </p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Plan card */}
          <div
            className="mt-5 p-3 flex items-center gap-3"
            style={{ backgroundColor: LINEN, borderRadius: 18, border: `1px solid ${SOFT}` }}
          >
            <div className="h-12 w-12 rounded-2xl flex items-center justify-center" style={{ backgroundColor: BLUE }}>
              <CheckCircle2 size={22} color={WHITE} />
            </div>
            <div className="flex-1 min-w-0">
              <p style={{ color: COFFEE, opacity: 0.55, fontSize: 10, fontWeight: 600 }}>方案信息</p>
              <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{item.style}</p>
              <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>
                {item.durationText} · {item.difficultyText} · {items.length} 件物品
              </p>
            </div>
            <button
              onClick={() => setTryingPlan(true)}
              className="px-3 py-2"
              style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, fontSize: 11, fontWeight: 600 }}
            >
              试试方案
            </button>
          </div>

          {/* Tags */}
          <div className="flex flex-wrap gap-2 mt-5">
            {tags.map((t) => (
              <span
                key={t}
                className="px-3 py-1.5"
                style={{ backgroundColor: LINEN, color: "#5b7ea3", borderRadius: 999, fontSize: 11, fontWeight: 500 }}
              >
                #{t}
              </span>
            ))}
          </div>

          {/* Meta */}
          <div className="flex items-center gap-3 mt-5">
            <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>{item.durationText}</span>
            <span className="h-1 w-1 rounded-full" style={{ backgroundColor: COFFEE, opacity: 0.3 }} />
            <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>{item.difficultyText}</span>
            <span className="h-1 w-1 rounded-full" style={{ backgroundColor: COFFEE, opacity: 0.3 }} />
            <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>{item.likes} 次点赞</span>
          </div>

          <div className="mt-5 mb-4" style={{ height: 1, backgroundColor: SOFT }} />

          {/* Comments */}
          <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>评论 · {comments.length}</p>

          <div className="mt-3 space-y-4">
            {comments.length === 0 && (
              <p style={{ color: COFFEE, opacity: 0.45, fontSize: 12 }}>还没有评论，来说第一句</p>
            )}
            {comments.map((c) => (
              <div key={c.id} className="flex gap-3">
                <div
                  className="h-9 w-9 rounded-full flex items-center justify-center flex-shrink-0"
                  style={{ backgroundColor: avatarColors[1], color: WHITE, fontSize: 12, fontWeight: 600 }}
                >
                  {String(c.author || "我").slice(0, 1)}
                </div>
                <div className="flex-1">
                  <p style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>{c.author}</p>
                  <p style={{ color: COFFEE, fontSize: 13, lineHeight: 1.5, marginTop: 2 }}>{c.body}</p>
                  <div className="flex items-center gap-3 mt-1.5">
                    <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>
                      {c.createdAt ? new Date(c.createdAt).toLocaleString("zh-CN", { hour12: false }) : ""}
                    </span>
                    <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>{c.likes} 赞</span>
                  </div>
                </div>
              </div>
            ))}
          </div>

          <div className="mt-6 mb-4 text-center">
            <span style={{ color: COFFEE, opacity: 0.4, fontSize: 11 }}>— 评论结束 —</span>
          </div>
        </div>
      </div>

      {/* Bottom action bar */}
      <div
        className="absolute bottom-0 left-0 right-0 px-4 py-3 flex items-center gap-2"
        style={{
          backgroundColor: "rgba(255,255,255,0.96)",
          backdropFilter: "blur(12px)",
          borderTop: `1px solid ${SOFT}`,
        }}
      >
        <div
          className="flex-1 px-4 py-2.5 flex items-center gap-2"
          style={{ backgroundColor: LINEN, borderRadius: 999 }}
        >
          <input
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            placeholder="说点好听的…"
            className="flex-1 bg-transparent outline-none"
            style={{ color: COFFEE, fontSize: 12 }}
          />
          <button
            onClick={() => {
              const body = draft.trim();
              if (!body || !caseID) return;
              setDraft("");
              mutate("community.comment", { id: caseID, body });
            }}
            aria-label="发送评论"
            className="h-7 w-7 rounded-full flex items-center justify-center"
            style={{ backgroundColor: draft.trim() ? ORANGE : "transparent" }}
          >
            <Send size={14} color={draft.trim() ? WHITE : COFFEE} />
          </button>
        </div>

        <ActionBtn
          icon={<Heart size={20} color={liked ? "#E25555" : COFFEE} fill={liked ? "#E25555" : "none"} />}
          count={item.likes}
          onClick={() => mutate("community.like", { id: item.id })}
        />
        <ActionBtn
          icon={<Bookmark size={20} color={saved ? ORANGE : COFFEE} fill={saved ? ORANGE : "none"} />}
          count={nativeState?.favorites.length ?? 0}
          onClick={() => mutate("community.favorite", { id: item.id })}
        />
        <ActionBtn icon={<MessageCircle size={20} color={COFFEE} />} count={comments.length} />
      </div>
    </div>
  );
}

function ActionBtn({
  icon,
  count,
  onClick,
}: {
  icon: React.ReactNode;
  count: number;
  onClick?: () => void;
}) {
  return (
    <button onClick={onClick} className="flex flex-col items-center px-1">
      {icon}
      <span style={{ color: COFFEE, opacity: 0.7, fontSize: 9, marginTop: 1 }}>{count}</span>
    </button>
  );
}
