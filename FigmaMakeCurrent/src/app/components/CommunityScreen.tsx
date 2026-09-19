import { useState } from "react";
import { Heart, Search } from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { COFFEE, ORANGE, LINEN, WHITE } from "./theme";
import { CommunityPostDetail } from "./CommunityPostDetail";
import { nativeRequest, type NativeState } from "../nativeBridge";

const posts = [
  {
    id: "p1",
    title: "小公寓，衣柜大改造",
    user: "Mira",
    avatar: "M",
    avatarBg: "#E8B894",
    likes: 1248,
    h: 280,
    img: "https://images.unsplash.com/photo-1775029918191-32e44ee20d06?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
  },
  {
    id: "p2",
    title: "5分钟厨房整理",
    user: "Lin",
    avatar: "L",
    avatarBg: "#B4D4C9",
    likes: 642,
    h: 200,
    img: "https://images.unsplash.com/photo-1772475385491-f3cf64d4131a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
  },
  {
    id: "p3",
    title: "浮动搁板魔法 ✨",
    user: "Anna",
    avatar: "A",
    avatarBg: "#D9B4C7",
    likes: 980,
    h: 240,
    img: "https://images.unsplash.com/photo-1758366278666-902516aac79f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
  },
  {
    id: "p4",
    title: "一个周末从混乱到平静",
    user: "Joon",
    avatar: "J",
    avatarBg: "#A8B8CC",
    likes: 2104,
    h: 300,
    img: "https://images.unsplash.com/photo-1749705319317-f9a2bf24fe3d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
  },
  {
    id: "p5",
    title: "办公桌极简布置",
    user: "Kai",
    avatar: "K",
    avatarBg: "#C9A687",
    likes: 421,
    h: 220,
    img: "https://images.unsplash.com/photo-1774578342274-29121c889b01?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
  },
  {
    id: "p6",
    title: "储藏室目标 🥫",
    user: "Sara",
    avatar: "S",
    avatarBg: "#E8D4B4",
    likes: 1572,
    h: 260,
    img: "https://images.unsplash.com/photo-1772475385426-ebd50c772229?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
  },
];

const tabs = ["推荐", "热门", "技巧", "衣柜"];

export function CommunityScreen({ nativeState, onNativeChange }: { nativeState?: NativeState | null; onNativeChange?: () => void }) {
  const [openPost, setOpenPost] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState(0);

  if (openPost) {
    return <CommunityPostDetail onBack={() => setOpenPost(null)} />;
  }

  const displayPosts = nativeState?.communityCases.length ? nativeState.communityCases.map((item, index) => ({
    id: item.id, title: item.title, user: item.author, avatar: String(item.author || "我").slice(0, 1),
    avatarBg: posts[index % posts.length].avatarBg, likes: item.likes, h: posts[index % posts.length].h,
    img: posts[index % posts.length].img,
  })) : posts;
  const left = displayPosts.filter((_, i) => i % 2 === 0);
  const right = displayPosts.filter((_, i) => i % 2 === 1);

  return (
    <div className="h-full w-full overflow-y-auto pb-32" style={{ backgroundColor: LINEN }}>
      <div className="px-6 pt-14 pb-2 flex items-center justify-between">
        <div>
          <p style={{ color: COFFEE, opacity: 0.55, fontSize: 12 }}>发现</p>
          <p style={{ color: COFFEE, fontSize: 24, fontWeight: 600 }}>社区</p>
        </div>
        <div
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <Search size={20} color={COFFEE} />
        </div>
      </div>

      <div className="overflow-x-auto px-6 mt-4">
        <div className="flex gap-2" style={{ width: "max-content" }}>
          {tabs.map((t, i) => (
            <button
              key={t}
              onClick={() => setActiveTab(i)}
              className="px-4 py-2"
              style={{
                backgroundColor: i === activeTab ? COFFEE : WHITE,
                color: i === activeTab ? WHITE : COFFEE,
                borderRadius: 999,
                fontSize: 12,
                fontWeight: i === 0 ? 600 : 500,
              }}
            >
              {t}
            </button>
          ))}
        </div>
      </div>

      <div className="px-4 mt-5 grid grid-cols-2 gap-3">
        <div className="space-y-3">
          {left.map((p) => (
            <PostCard key={p.id} post={p} onClick={() => setOpenPost(p.id)} onLike={() => void nativeRequest("community.like", { id: p.id }).then(onNativeChange)} />
          ))}
        </div>
        <div className="space-y-3">
          {right.map((p) => (
            <PostCard key={p.id} post={p} onClick={() => setOpenPost(p.id)} onLike={() => void nativeRequest("community.like", { id: p.id }).then(onNativeChange)} />
          ))}
        </div>
      </div>
    </div>
  );
}

function PostCard({ post, onClick, onLike }: { post: (typeof posts)[number]; onClick: () => void; onLike: () => void }) {
  return (
    <button
      onClick={onClick}
      className="w-full text-left"
      style={{
        backgroundColor: WHITE,
        borderRadius: 20,
        overflow: "hidden",
        boxShadow: "0 4px 16px rgba(123,92,72,0.05)",
      }}
    >
      <div style={{ height: post.h }} className="w-full overflow-hidden">
        <ImageWithFallback src={post.img} alt={post.title} className="h-full w-full object-cover" />
      </div>
      <div className="p-3">
        <p style={{ color: COFFEE, fontSize: 12, fontWeight: 500, lineHeight: 1.35 }}>
          {post.title}
        </p>
        <div className="flex items-center justify-between mt-2.5">
          <div className="flex items-center gap-1.5">
            <div
              className="h-5 w-5 rounded-full flex items-center justify-center"
              style={{ backgroundColor: post.avatarBg, color: WHITE, fontSize: 9, fontWeight: 600 }}
            >
              {post.avatar}
            </div>
            <span style={{ color: COFFEE, opacity: 0.6, fontSize: 10 }}>{post.user}</span>
          </div>
          <span role="button" aria-label={`点赞${post.title}`} onClick={(event) => { event.stopPropagation(); onLike(); }} className="flex items-center gap-1">
            <Heart size={12} color={ORANGE} fill={ORANGE} />
            <span style={{ color: COFFEE, opacity: 0.7, fontSize: 10 }}>{post.likes}</span>
          </span>
        </div>
      </div>
    </button>
  );
}
