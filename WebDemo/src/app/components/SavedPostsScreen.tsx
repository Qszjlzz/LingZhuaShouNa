import { useState } from "react";
import { ArrowLeft, Bookmark, Search, Folder } from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { COFFEE, ORANGE, LINEN, WHITE, SOFT } from "./theme";

const collections = [
  { id: "c1", name: "全部", count: 24, color: ORANGE },
  { id: "c2", name: "衣柜", count: 8, color: "#B4D4C9" },
  { id: "c3", name: "厨房", count: 6, color: "#E8B894" },
  { id: "c4", name: "技巧", count: 10, color: "#B4C7DC" },
];

const posts = [
  {
    id: "p1",
    title: "小公寓，衣柜大改造",
    user: "Mira",
    h: 240,
    img: "https://images.unsplash.com/photo-1775029918191-32e44ee20d06?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    folder: "Wardrobe",
  },
  {
    id: "p2",
    title: "5分钟厨房复位",
    user: "Lin",
    h: 180,
    img: "https://images.unsplash.com/photo-1772475385491-f3cf64d4131a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    folder: "Kitchen",
  },
  {
    id: "p3",
    title: "浮动搁板魔法 ✨",
    user: "Anna",
    h: 220,
    img: "https://images.unsplash.com/photo-1758366278666-902516aac79f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    folder: "Tips",
  },
  {
    id: "p4",
    title: "一个周末从混乱到平静",
    user: "Joon",
    h: 280,
    img: "https://images.unsplash.com/photo-1749705319317-f9a2bf24fe3d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    folder: "Tips",
  },
  {
    id: "p5",
    title: "办公桌极简布置",
    user: "Kai",
    h: 200,
    img: "https://images.unsplash.com/photo-1774578342274-29121c889b01?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    folder: "Tips",
  },
  {
    id: "p6",
    title: "储藏室目标 🥫",
    user: "Sara",
    h: 240,
    img: "https://images.unsplash.com/photo-1772475385426-ebd50c772229?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800",
    folder: "Kitchen",
  },
];

export function SavedPostsScreen({ onBack }: { onBack: () => void }) {
  const [active, setActive] = useState("All");
  const filtered = active === "All" ? posts : posts.filter((p) => p.folder === active);

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
            <p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>24 saved</p>
            <p style={{ color: COFFEE, opacity: 0.55, fontSize: 12 }}>共 3 个收藏夹</p>
          </div>
        </div>
      </div>

      {/* Collections */}
      <div className="px-6 mt-5 flex items-center justify-between mb-3">
        <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>收藏夹</p>
        <span style={{ color: ORANGE, fontSize: 12 }}>+ New folder</span>
      </div>
      <div className="px-6 flex gap-2 overflow-x-auto">
        {collections.map((c) => {
          const isActive = active === c.name;
          return (
            <button
              key={c.id}
              onClick={() => setActive(c.name)}
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
              <Folder size={14} color={isActive ? WHITE : c.color} fill={c.color} />
              {c.name}
              <span
                style={{
                  color: isActive ? "rgba(255,255,255,0.7)" : COFFEE,
                  opacity: isActive ? 1 : 0.5,
                  fontSize: 11,
                }}
              >
                {c.count}
              </span>
            </button>
          );
        })}
      </div>

      {/* Masonry */}
      <div className="px-4 mt-5 grid grid-cols-2 gap-3">
        <div className="space-y-3">
          {filtered.filter((_, i) => i % 2 === 0).map((p) => (
            <SavedCard key={p.id} post={p} />
          ))}
        </div>
        <div className="space-y-3">
          {filtered.filter((_, i) => i % 2 === 1).map((p) => (
            <SavedCard key={p.id} post={p} />
          ))}
        </div>
      </div>
    </div>
  );
}

function SavedCard({ post }: { post: (typeof posts)[number] }) {
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
        <div
          className="absolute top-2 right-2 h-7 w-7 rounded-full flex items-center justify-center"
          style={{ backgroundColor: "rgba(255,255,255,0.92)" }}
        >
          <Bookmark size={13} color={ORANGE} fill={ORANGE} />
        </div>
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
