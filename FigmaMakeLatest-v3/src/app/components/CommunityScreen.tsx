import { useState } from "react";
import { Heart, Search, X } from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { COFFEE, ORANGE, LINEN, WHITE } from "./theme";
import { CommunityPostDetail } from "./CommunityPostDetail";
import { nativeRequest, type NativeState } from "../nativeBridge";

/* 设计稿的 6 张帖子：视觉基线，保证社区始终有内容 */
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
    img: "https://images.unsplash.com/photo-1749705319317-f3a2bf24fe3d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
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

const REAL_COVERS = [
  { avatarBg: "#E8B894", h: 270, img: posts[0].img },
  { avatarBg: "#B4D4C9", h: 210, img: posts[1].img },
  { avatarBg: "#D9B4C7", h: 250, img: posts[2].img },
  { avatarBg: "#A8B8CC", h: 290, img: posts[3].img },
];

const tabs = ["推荐", "热门", "技巧", "衣柜"];

type DisplayPost = {
  id: string;
  title: string;
  user: string;
  avatar: string;
  avatarBg: string;
  likes: number;
  h: number;
  img: string;
  tags: string[];
  liked: boolean;
  real: boolean;
};

/* 按标题内容判定标签：衣柜类 / 技巧类 */
function tagsOf(title: string): string[] {
  const t = title.toLowerCase();
  const tags: string[] = [];
  if (t.includes("衣柜") || t.includes("衣橱") || t.includes("服饰")) tags.push("衣柜");
  if (
    t.includes("分钟") ||
    t.includes("魔法") ||
    t.includes("极简") ||
    t.includes("整理") ||
    t.includes("布置") ||
    t.includes("储藏") ||
    t.includes("收纳")
  ) {
    tags.push("技巧");
  }
  return tags.length > 0 ? tags : ["技巧"];
}

interface CommunityScreenProps {
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
}

export function CommunityScreen({ nativeState, onNativeChange }: CommunityScreenProps = {}) {
  const [openPost, setOpenPost] = useState<DisplayPost | null>(null);
  const [tab, setTab] = useState("推荐");
  const [query, setQuery] = useState("");
  const [searching, setSearching] = useState(false);
  const [localLiked, setLocalLiked] = useState<Record<string, boolean>>({});

  if (openPost) {
    return (
      <CommunityPostDetail
        post={{
          id: openPost.id,
          title: openPost.title,
          user: openPost.user,
          avatar: openPost.avatar,
          avatarBg: openPost.avatarBg,
          likes: openPost.likes,
          img: openPost.img,
          real: openPost.real,
        }}
        nativeState={nativeState}
        onNativeChange={onNativeChange}
        onBack={() => setOpenPost(null)}
      />
    );
  }

  const nativeLiked = nativeState?.liked ?? [];
  const designPosts: DisplayPost[] = posts.map((p) => ({
    ...p,
    tags: tagsOf(p.title),
    liked: localLiked[p.id] ?? nativeLiked.includes(p.id),
    real: false,
  }));
  // 真实发布过的方案追加在后面，设计稿 6 张始终在前面
  const realPosts: DisplayPost[] = (nativeState?.communityCases ?? []).map((item, index) => {
    const cover = REAL_COVERS[index % REAL_COVERS.length];
    return {
      id: item.id,
      title: item.title,
      user: item.author,
      avatar: String(item.author || "我").slice(0, 1),
      avatarBg: cover.avatarBg,
      likes: item.likes ?? 0,
      h: cover.h,
      img: cover.img,
      tags: tagsOf(item.title),
      liked: localLiked[item.id] ?? nativeLiked.includes(item.id),
      real: true,
    };
  });

  const keyword = query.trim().toLowerCase();
  const allPosts = [...designPosts, ...realPosts];
  const displayPosts = allPosts.filter((p) => {
    const matchKeyword =
      keyword.length === 0 ||
      `${p.title}${p.user}`.toLowerCase().includes(keyword);
    if (!matchKeyword) return false;
    if (tab === "推荐") return true;
    if (tab === "热门") return p.likes >= 1000;
    return p.tags.includes(tab);
  });

  const toggleLike = (post: DisplayPost) => {
    const next = !post.liked;
    setLocalLiked((prev) => ({ ...prev, [post.id]: next }));
    if (post.real) {
      void nativeRequest("community.like", { id: post.id, liked: next }).then(onNativeChange);
    }
  };

  const left = displayPosts.filter((_, i) => i % 2 === 0);
  const right = displayPosts.filter((_, i) => i % 2 === 1);

  return (
    <div className="h-full w-full overflow-y-auto pb-32" style={{ backgroundColor: LINEN }}>
      <div className="px-6 pt-14 pb-2 flex items-center justify-between">
        <div>
          <p style={{ color: COFFEE, opacity: 0.55, fontSize: 12 }}>发现</p>
          <p style={{ color: COFFEE, fontSize: 24, fontWeight: 600 }}>社区</p>
        </div>
        <button
          onClick={() => setSearching((v) => !v)}
          className="h-11 min-w-11 px-3 rounded-full flex items-center justify-center gap-2"
          style={{ backgroundColor: WHITE }}
        >
          {searching ? <X size={18} color={COFFEE} /> : <Search size={20} color={COFFEE} />}
        </button>
      </div>

      {searching && (
        <div className="px-6 mt-2">
          <div
            className="flex items-center gap-2 px-4 py-3"
            style={{ backgroundColor: WHITE, borderRadius: 20 }}
          >
            <Search size={16} color={COFFEE} />
            <input
              autoFocus
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="搜索帖子或作者…"
              className="flex-1 bg-transparent outline-none"
              style={{ color: COFFEE, fontSize: 14 }}
            />
          </div>
        </div>
      )}

      <div className="overflow-x-auto px-6 mt-4">
        <div className="flex gap-2" style={{ width: "max-content" }}>
          {tabs.map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className="px-4 py-2"
              style={{
                backgroundColor: tab === t ? COFFEE : WHITE,
                color: tab === t ? WHITE : COFFEE,
                borderRadius: 999,
                fontSize: 12,
                fontWeight: tab === t ? 600 : 500,
              }}
            >
              {t}
            </button>
          ))}
        </div>
      </div>

      {displayPosts.length === 0 ? (
        <div
          className="mx-6 mt-6 p-6 text-center"
          style={{ backgroundColor: WHITE, borderRadius: 20 }}
        >
          <p style={{ color: COFFEE, opacity: 0.6, fontSize: 13 }}>
            {keyword ? `没有找到包含“${query}”的帖子` : "这个分类下暂时还没有帖子"}
          </p>
        </div>
      ) : (
        <div className="px-4 mt-5 grid grid-cols-2 gap-3">
          <div className="space-y-3">
            {left.map((p) => (
              <PostCard key={p.id} post={p} onOpen={() => setOpenPost(p)} onLike={() => toggleLike(p)} />
            ))}
          </div>
          <div className="space-y-3">
            {right.map((p) => (
              <PostCard key={p.id} post={p} onOpen={() => setOpenPost(p)} onLike={() => toggleLike(p)} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function PostCard({
  post,
  onOpen,
  onLike,
}: {
  post: DisplayPost;
  onOpen: () => void;
  onLike: () => void;
}) {
  return (
    <div
      className="w-full text-left relative"
      style={{
        backgroundColor: WHITE,
        borderRadius: 20,
        overflow: "hidden",
        boxShadow: "0 4px 16px rgba(123,92,72,0.05)",
      }}
    >
      <button onClick={onOpen} className="w-full text-left block">
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
          </div>
        </div>
      </button>
      <button
        onClick={onLike}
        aria-label={post.liked ? "取消点赞" : "点赞"}
        className="absolute flex items-center gap-1 px-2 py-1"
        style={{ right: 12, bottom: 12, borderRadius: 999, backgroundColor: "rgba(255,255,255,0.9)" }}
      >
        <Heart size={12} color={ORANGE} fill={post.liked ? ORANGE : "transparent"} />
        <span style={{ color: COFFEE, opacity: 0.7, fontSize: 10 }}>{post.likes}</span>
      </button>
    </div>
  );
}
