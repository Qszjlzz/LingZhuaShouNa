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
} from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { TryPlanScreen } from "./TryPlanScreen";
import { nativeRequest, type NativeState } from "../nativeBridge";

const images = [
  "https://images.unsplash.com/photo-1775029918191-32e44ee20d06?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
  "https://images.unsplash.com/photo-1772475385426-ebd50c772229?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
  "https://images.unsplash.com/photo-1758366278666-902516aac79f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
  "https://images.unsplash.com/photo-1769690398992-dfafcba3d41b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080",
];

const tags = ["#衣柜改造", "#小公寓", "#断舍离", "#柔和极简"];

const steps = [
  "把所有东西倒在床上 — 不要跳过",
  "按类别分类，而不是按抽屉",
  "捐赠12个月内没穿过的任何衣物",
  "使用纤薄天鹅绒衣架 — 节省40%空间",
  "把针织衫垂直卷放在浅篮子里",
];

const comments = [
  {
    id: "c1",
    user: "Yuki",
    avatar: "Y",
    bg: "#E8B894",
    text: "天鹅绒衣架的建议改变了我的生活🥹 同一个衣柜从60件增加到90件衬衫",
    likes: 124,
    time: "2小时前",
  },
  {
    id: "c2",
    user: "Mei",
    avatar: "M",
    bg: "#B4D4C9",
    text: "你在哪里买的那些篮子？？看起来很完美",
    likes: 56,
    time: "4小时前",
    reply: "Mira: 无印良品！长方形软篮 — L号 👌",
  },
  {
    id: "c3",
    user: "Daisy",
    avatar: "D",
    bg: "#D9B4C7",
    text: "已保存，周末就试试 💪",
    likes: 12,
    time: "8小时前",
  },
];

interface CommunityPostDetailProps {
  post?: {
    id: string; title: string; user: string; avatar: string; avatarBg: string;
    likes: number; img: string; real?: boolean;
  } | null;
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
  onBack: () => void;
}

export function CommunityPostDetail({ post, nativeState, onNativeChange, onBack }: CommunityPostDetailProps) {
  const [idx, setIdx] = useState(0);
  const [liked, setLiked] = useState(post?.real ? (nativeState?.liked ?? []).includes(post.id) : false);
  const [saved, setSaved] = useState(post?.real ? (nativeState?.favorites ?? []).includes(post.id) : false);
  const [following, setFollowing] = useState(post?.real ? (nativeState?.followedAuthors ?? []).includes(post.user) : false);
  const [tryingPlan, setTryingPlan] = useState(false);
  const [draft, setDraft] = useState("");
  const [localComments, setLocalComments] = useState<{ id: string; user: string; avatar: string; bg: string; text: string; likes: number; time: string }[]>([]);

  const gallery = post ? [post.img, ...images.slice(1)] : images;
  const authorName = post?.user ?? "Mira";
  const authorAvatar = post?.avatar ?? "M";
  const authorBg = post?.avatarBg ?? "#E8B894";
  const baseLikes = post?.likes ?? 1248;
  const nativeComments = (post && nativeState?.comments?.[post.id]) ?? [];
  const shownComments = [
    ...comments.map((c) => ({ ...c, id: `design-${c.id}` })),
    ...nativeComments.map((c: any, i: number) => ({
      id: `native-${c.id ?? i}`,
      user: c.author ?? "我",
      avatar: String(c.author ?? "我").slice(0, 1),
      bg: ["#A8B8CC", "#B4D4C9", "#D9B4C7"][i % 3],
      text: c.text ?? "",
      likes: c.likes ?? 0,
      time: c.time ?? "刚刚",
    })),
    ...localComments,
  ];

  const toggleLike = () => {
    const next = !liked;
    setLiked(next);
    if (post?.real) void nativeRequest("community.like", { id: post.id, liked: next }).then(onNativeChange);
  };
  const toggleSave = () => {
    const next = !saved;
    setSaved(next);
    if (post?.real) void nativeRequest("community.favorite", { id: post.id, favorite: next }).then(onNativeChange);
  };
  const toggleFollow = () => {
    const next = !following;
    setFollowing(next);
    if (post?.real) void nativeRequest("community.follow", { author: authorName, follow: next }).then(onNativeChange);
  };
  const sendComment = () => {
    const text = draft.trim();
    if (!text) return;
    setLocalComments((prev) => [
      ...prev,
      { id: `local-${Date.now()}`, user: "我", avatar: "我", bg: "#E8B894", text, likes: 0, time: "刚刚" },
    ]);
    if (post?.real) void nativeRequest("community.comment", { id: post.id, text }).then(onNativeChange);
    setDraft("");
  };

  if (tryingPlan) {
    return <TryPlanScreen caseID={post?.real ? post.id : undefined} nativeState={nativeState} onNativeChange={onNativeChange} onBack={() => setTryingPlan(false)} />;
  }

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
              style={{ backgroundColor: authorBg, color: WHITE, fontSize: 12, fontWeight: 600 }}
            >
              {authorAvatar}
            </div>
            <span style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>{authorName}</span>
            <button
              onClick={toggleFollow}
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
            src={gallery[idx]}
            alt="Post"
            className="h-full w-full object-cover"
          />

          {/* Pager */}
          <span
            className="absolute top-14 right-5 px-2.5 py-1"
            style={{
              backgroundColor: "rgba(0,0,0,0.45)",
              color: WHITE,
              borderRadius: 999,
              fontSize: 11,
              fontWeight: 600,
            }}
          >
            {idx + 1} / {gallery.length}
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
          {idx < gallery.length - 1 && (
            <button
              onClick={() => setIdx((i) => i + 1)}
              className="absolute right-3 top-1/2 -translate-y-1/2 h-9 w-9 rounded-full flex items-center justify-center"
              style={{ backgroundColor: "rgba(255,255,255,0.85)" }}
            >
              <ChevronRight size={18} color={COFFEE} />
            </button>
          )}

          {/* Dots */}
          <div className="absolute bottom-3 left-0 right-0 flex justify-center gap-1.5">
            {gallery.map((_, i) => (
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
          <p style={{ color: COFFEE, fontSize: 18, fontWeight: 600, lineHeight: 1.35 }}>
            {post?.title ?? "小公寓，衣柜大改造 ✨"}
          </p>
          <p
            style={{
              color: COFFEE,
              fontSize: 13,
              lineHeight: 1.65,
              marginTop: 10,
              opacity: 0.85,
            }}
          >
            花了一个周六，把我1.2米的衣柜变成了一个终于能呼吸的系统。分享我使用的确切5步方法（花了4小时，不是我担心的整个周末😅）。
          </p>

          {/* Steps */}
          <div className="mt-5">
            <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600, marginBottom: 10 }}>
              5个步骤 👇
            </p>
            <div className="space-y-2.5">
              {steps.map((s, i) => (
                <div key={i} className="flex gap-3 items-start">
                  <div
                    className="h-6 w-6 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5"
                    style={{
                      backgroundColor: ORANGE,
                      color: WHITE,
                      fontSize: 11,
                      fontWeight: 600,
                    }}
                  >
                    {i + 1}
                  </div>
                  <p style={{ color: COFFEE, fontSize: 13, lineHeight: 1.55 }}>{s}</p>
                </div>
              ))}
            </div>
          </div>

          {/* Linked space card */}
          <div
            className="mt-5 p-3 flex items-center gap-3"
            style={{
              backgroundColor: LINEN,
              borderRadius: 18,
              border: `1px solid ${SOFT}`,
            }}
          >
            <div
              className="h-12 w-12 rounded-2xl flex items-center justify-center"
              style={{ backgroundColor: BLUE }}
            >
              <CheckCircle2 size={22} color={WHITE} />
            </div>
            <div className="flex-1 min-w-0">
              <p style={{ color: COFFEE, opacity: 0.55, fontSize: 10, fontWeight: 600 }}>
                关联空间
              </p>
              <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>卧室衣柜</p>
              <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>78个物品 · 4小时12分钟</p>
            </div>
            <button
              onClick={() => setTryingPlan(true)}
              className="px-3 py-2"
              style={{
                backgroundColor: ORANGE,
                color: WHITE,
                borderRadius: 999,
                fontSize: 11,
                fontWeight: 600,
              }}
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
                style={{
                  backgroundColor: LINEN,
                  color: BLUE === BLUE ? "#5b7ea3" : COFFEE,
                  borderRadius: 999,
                  fontSize: 11,
                  fontWeight: 500,
                }}
              >
                {t}
              </span>
            ))}
          </div>

          {/* Meta */}
          <div className="flex items-center gap-3 mt-5">
            <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>2天前</span>
            <span className="h-1 w-1 rounded-full" style={{ backgroundColor: COFFEE, opacity: 0.3 }} />
            <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>上海</span>
            <span className="h-1 w-1 rounded-full" style={{ backgroundColor: COFFEE, opacity: 0.3 }} />
            <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>14.2k 次浏览</span>
          </div>

          {/* Divider */}
          <div className="mt-5 mb-4" style={{ height: 1, backgroundColor: SOFT }} />

          {/* Comments */}
          <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>
            评论 · {shownComments.length + 84}
          </p>

          <div className="mt-3 space-y-4">
            {shownComments.map((c) => (
              <div key={c.id} className="flex gap-3">
                <div
                  className="h-9 w-9 rounded-full flex items-center justify-center flex-shrink-0"
                  style={{ backgroundColor: c.bg, color: WHITE, fontSize: 12, fontWeight: 600 }}
                >
                  {c.avatar}
                </div>
                <div className="flex-1">
                  <p style={{ color: COFFEE, fontSize: 12, fontWeight: 600 }}>{c.user}</p>
                  <p style={{ color: COFFEE, fontSize: 13, lineHeight: 1.5, marginTop: 2 }}>
                    {c.text}
                  </p>
                  <div className="flex items-center gap-3 mt-1.5">
                    <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>{c.time}</span>
                    <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>回复</span>
                  </div>
                  {c.reply && (
                    <div
                      className="mt-2 p-2.5"
                      style={{ backgroundColor: LINEN, borderRadius: 12 }}
                    >
                      <p style={{ color: COFFEE, fontSize: 12, lineHeight: 1.5 }}>{c.reply}</p>
                    </div>
                  )}
                </div>
                <button className="flex flex-col items-center pt-1">
                  <Heart size={14} color={COFFEE} opacity={0.5} />
                  <span style={{ color: COFFEE, opacity: 0.5, fontSize: 10, marginTop: 2 }}>
                    {c.likes}
                  </span>
                </button>
              </div>
            ))}
          </div>

          <div className="mt-5 mb-4 flex items-center gap-2">
            <div
              className="h-9 w-9 rounded-full flex items-center justify-center flex-shrink-0"
              style={{ backgroundColor: authorBg, color: WHITE, fontSize: 12, fontWeight: 600 }}
            >
              我
            </div>
            <div className="flex-1 flex items-center gap-2 px-4 py-2.5" style={{ backgroundColor: LINEN, borderRadius: 999 }}>
              <input
                value={draft}
                onChange={(event) => setDraft(event.target.value)}
                onKeyDown={(event) => { if (event.key === "Enter") sendComment(); }}
                placeholder="说点好听的…"
                className="flex-1 bg-transparent outline-none"
                style={{ color: COFFEE, fontSize: 13 }}
              />
              <button onClick={sendComment} style={{ color: draft.trim() ? ORANGE : COFFEE, opacity: draft.trim() ? 1 : 0.35, fontSize: 12, fontWeight: 600 }}>
                发送
              </button>
            </div>
          </div>
          <div className="mb-4 text-center">
            <span style={{ color: COFFEE, opacity: 0.4, fontSize: 11 }}>
              — 评论结束 —
            </span>
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
          className="flex-1 px-4 py-2.5"
          style={{ backgroundColor: LINEN, borderRadius: 999 }}
        >
          <span style={{ color: COFFEE, opacity: 0.55, fontSize: 12 }}>说点好听的…</span>
        </div>

        <ActionBtn
          icon={
            <Heart
              size={20}
              color={liked ? "#E25555" : COFFEE}
              fill={liked ? "#E25555" : "none"}
            />
          }
          count={liked ? baseLikes + 1 : baseLikes}
          onClick={toggleLike}
        />
        <ActionBtn
          icon={
            <Bookmark
              size={20}
              color={saved ? ORANGE : COFFEE}
              fill={saved ? ORANGE : "none"}
            />
          }
          count={saved ? 343 : 342}
          onClick={toggleSave}
        />
        <ActionBtn icon={<MessageCircle size={20} color={COFFEE} />} count={87} />
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
