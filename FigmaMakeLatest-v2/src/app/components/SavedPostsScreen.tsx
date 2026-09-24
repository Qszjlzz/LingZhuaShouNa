import { useState } from "react";
import { ArrowLeft, Bookmark, Search, Folder } from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { COFFEE, ORANGE, LINEN, WHITE, SOFT } from "./theme";
import { nativeRequest, type NativeState } from "../nativeBridge";

// 仅作为卡片封面占位图使用，标题、作者、标签、收藏状态全部来自原生数据
const covers = [
  "https://images.unsplash.com/photo-1775029918191-32e44ee20d06?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
  "https://images.unsplash.com/photo-1772475385491-f3cf64d4131a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
  "https://images.unsplash.com/photo-1758366278666-902516aac79f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
  "https://images.unsplash.com/photo-1749705319317-f3a2bf24fe3d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
  "https://images.unsplash.com/photo-1774578342274-29121c889b01?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
  "https://images.unsplash.com/photo-1772475385426-ebd50c772229?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
];
const heights = [240, 180, 220, 280, 200, 240];

export function SavedPostsScreen({
  onBack,
  nativeState,
  onNativeChange,
}: {
  onBack: () => void;
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
}) {
  const [active, setActive] = useState("全部");

  // 收藏关系来自原生 favorites（持久化在设备里），案例内容来自 communityCases
  const savedPosts = (nativeState?.communityCases ?? [])
    .filter((item) => nativeState?.favorites.includes(item.id))
    .map((item, index) => ({
      id: item.id,
      title: item.title,
      user: item.author,
      likes: item.likes,
      h: heights[index % heights.length],
      img: covers[index % covers.length],
      folder: item.tags?.[0] ?? item.style ?? "其他",
    }));

  const folders = ["全部", ...Array.from(new Set(savedPosts.map((p) => p.folder)))];
  const filtered = active === "全部" ? savedPosts : savedPosts.filter((p) => p.folder === active);

  const toggleFavorite = (id: string) => {
    void nativeRequest("community.favorite", { id })
      .then(() => onNativeChange?.())
      .catch(() => undefined);
  };

  return (
    <div className="h-full w-full overflow-y-auto pb-10" style={{ backgroundColor: LINEN }}>
      <div className="px-6 pt-14 pb-2 flex items-center justify-between">
        <button
          onClick={onBack}
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ArrowLeft size={20} color={COFFEE} />
        </button>
        <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>已保存</p>
        <button
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <Search size={18} color={COFFEE} />
        </button>
      </div>

      {/* Stats */}
      <div className="px-6 mt-4">
        <div
          className="p-5 flex items-center gap-4"
          style={{
            backgroundColor: WHITE,
            borderRadius: 22,
            boxShadow: "0 4px 18px rgba(123,92,72,0.06)",
          }}
        >
          <div
            className="h-14 w-14 rounded-2xl flex items-center justify-center"
            style={{ backgroundColor: ORANGE, boxShadow: "0 6px 16px rgba(250,136,58,0.3)" }}
          >
            <Bookmark size={22} color={WHITE} fill={WHITE} />
          </div>
          <div className="flex-1">
            <p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>{savedPosts.length} 条收藏</p>
            <p style={{ color: COFFEE, opacity: 0.55, fontSize: 12 }}>
              分布在 {Math.max(folders.length - 1, 0)} 个分类
            </p>
          </div>
        </div>
      </div>

      {/* Collections */}
      <div className="px-6 mt-5 flex items-center justify-between mb-3">
        <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>分类</p>
      </div>
      <div className="px-6 flex gap-2 overflow-x-auto">
        {folders.map((name) => {
          const isActive = active === name;
          const count = name === "全部" ? savedPosts.length : savedPosts.filter((p) => p.folder === name).length;
          return (
            <button
              key={name}
              onClick={() => setActive(name)}
              className="flex-shrink-0 flex items-center gap-2 px-4 py-2.5"
              style={{
                backgroundColor: isActive ? COFFEE : WHITE,
                color: isActive ? WHITE : COFFEE,
                borderRadius: 14,
                fontSize: 12,
                fontWeight: isActive ? 600 : 500,
                boxShadow: isActive ? "none" : "0 2px 8px rgba(123,92,72,0.04)",
              }}
            >
              <Folder size={14} color={isActive ? WHITE : ORANGE} fill={isActive ? WHITE : ORANGE} />
              {name}
              <span
                style={{
                  color: isActive ? "rgba(255,255,255,0.7)" : COFFEE,
                  opacity: isActive ? 1 : 0.5,
                  fontSize: 11,
                }}
              >
                {count}
              </span>
            </button>
          );
        })}
      </div>

      {savedPosts.length === 0 && (
        <div className="px-6 mt-6">
          <div className="p-6 text-center" style={{ backgroundColor: WHITE, borderRadius: 18 }}>
            <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>
              还没有收藏，去社区点赞收藏后会同步到这里
            </p>
          </div>
        </div>
      )}

      {/* Masonry */}
      <div className="px-4 mt-5 grid grid-cols-2 gap-3">
        <div className="space-y-3">
          {filtered.filter((_, i) => i % 2 === 0).map((p) => (
            <SavedCard key={p.id} post={p} onToggle={() => toggleFavorite(p.id)} />
          ))}
        </div>
        <div className="space-y-3">
          {filtered.filter((_, i) => i % 2 === 1).map((p) => (
            <SavedCard key={p.id} post={p} onToggle={() => toggleFavorite(p.id)} />
          ))}
        </div>
      </div>
    </div>
  );
}

function SavedCard({
  post,
  onToggle,
}: {
  post: { id: string; title: string; user: string; likes: number; h: number; img: string; folder: string };
  onToggle: () => void;
}) {
  return (
    <div
      style={{
        backgroundColor: WHITE,
        borderRadius: 18,
        overflow: "hidden",
        boxShadow: "0 4px 14px rgba(123,92,72,0.05)",
      }}
    >
      <div className="relative" style={{ height: post.h }}>
        <ImageWithFallback src={post.img} alt={post.title} className="h-full w-full object-cover" />
        <button
          onClick={onToggle}
          aria-label={`取消收藏${post.title}`}
          className="absolute top-2 right-2 h-7 w-7 rounded-full flex items-center justify-center"
          style={{ backgroundColor: "rgba(255,255,255,0.92)" }}
        >
          <Bookmark size={13} color={ORANGE} fill={ORANGE} />
        </button>
        <span
          className="absolute bottom-2 left-2 px-2 py-0.5"
          style={{
            backgroundColor: "rgba(123,92,72,0.85)",
            color: WHITE,
            borderRadius: 999,
            fontSize: 9,
            fontWeight: 600,
          }}
        >
          {post.folder}
        </span>
      </div>
      <div className="p-2.5">
        <p style={{ color: COFFEE, fontSize: 11, fontWeight: 500, lineHeight: 1.4 }}>
          {post.title}
        </p>
        <p style={{ color: COFFEE, opacity: 0.55, fontSize: 10, marginTop: 3 }}>by {post.user}</p>
      </div>
    </div>
  );
}
