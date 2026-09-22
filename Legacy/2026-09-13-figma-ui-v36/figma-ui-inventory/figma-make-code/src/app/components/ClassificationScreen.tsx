import { useState } from "react";
import { Search, Sparkles, Shirt, BookOpen, Coffee, Gamepad2, Pill, Wrench, Utensils, Sparkle } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { BooksCategoryScreen } from "./BooksCategoryScreen";

const categories = [
  { id: "c1", name: "服饰", count: 124, icon: Shirt, color: BLUE },
  { id: "c2", name: "书籍", count: 56, icon: BookOpen, color: "#D9C2A8" },
  { id: "c3", name: "厨房", count: 88, icon: Utensils, color: "#E8B894" },
  { id: "c4", name: "饮品", count: 21, icon: Coffee, color: "#C9A687" },
  { id: "c5", name: "玩具", count: 34, icon: Gamepad2, color: "#B4D4C9" },
  { id: "c6", name: "健康", count: 17, icon: Pill, color: "#D9B4C7" },
  { id: "c7", name: "工具", count: 29, icon: Wrench, color: "#A8B8CC" },
  { id: "c8", name: "装饰", count: 42, icon: Sparkle, color: "#E8D4B4" },
];

const recentItems = [
  { id: "i1", name: "羊毛衫", cat: "服饰", emoji: "🧥" },
  { id: "i2", name: "陶瓷杯", cat: "厨房", emoji: "☕" },
  { id: "i3", name: "小说", cat: "书籍", emoji: "📚" },
  { id: "i4", name: "乐高", cat: "玩具", emoji: "🧱" },
  { id: "i5", name: "维生素C", cat: "健康", emoji: "💊" },
  { id: "i6", name: "香薰蜡烛", cat: "装饰", emoji: "🕯️" },
];

export function ClassificationScreen() {
  const [openCategory, setOpenCategory] = useState<string | null>(null);

  if (openCategory === "书籍") {
    return <BooksCategoryScreen onBack={() => setOpenCategory(null)} />;
  }

  return (
    <div className="h-full w-full overflow-y-auto pb-32" style={{ backgroundColor: LINEN }}>
      <div className="px-6 pt-14 pb-2">
        <p style={{ color: COFFEE, opacity: 0.55, fontSize: 12 }}>你的全部物品</p>
        <p style={{ color: COFFEE, fontSize: 24, fontWeight: 600 }}>分类</p>
      </div>

      {/* Search with AI */}
      <div className="px-6 mt-4">
        <div
          className="flex items-center gap-3 px-5 py-4"
          style={{
            backgroundColor: WHITE,
            borderRadius: 24,
            boxShadow: "0 4px 20px rgba(123,92,72,0.05)",
          }}
        >
          <Search size={18} color={COFFEE} />
          <input
            placeholder="搜索物品或分类…"
            className="flex-1 bg-transparent outline-none"
            style={{ color: COFFEE, fontSize: 14 }}
          />
          <div
            className="px-2.5 py-1.5 flex items-center gap-1"
            style={{ backgroundColor: LINEN, borderRadius: 999 }}
          >
            <Sparkles size={12} color={ORANGE} />
            <span style={{ color: ORANGE, fontSize: 11 }}>AI标签</span>
          </div>
        </div>
      </div>

      {/* AI banner */}
      <div
        className="mx-6 mt-4 p-4 flex items-center gap-3"
        style={{
          background: `linear-gradient(135deg, ${ORANGE} 0%, #FFAA66 100%)`,
          borderRadius: 20,
        }}
      >
        <div
          className="h-10 w-10 rounded-full flex items-center justify-center"
          style={{ backgroundColor: "rgba(255,255,255,0.25)" }}
        >
          <Sparkles size={18} color={WHITE} />
        </div>
        <div className="flex-1">
          <p style={{ color: WHITE, fontSize: 13, fontWeight: 600 }}>AI自动标记了8个新物品</p>
          <p style={{ color: WHITE, opacity: 0.85, fontSize: 11 }}>点击查看并确认</p>
        </div>
      </div>

      {/* Categories grid */}
      <div className="px-6 mt-7 mb-3 flex items-center justify-between">
        <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>分类</p>
        <span style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>{categories.length}</span>
      </div>

      <div className="px-6 grid grid-cols-2 gap-3">
        {categories.map((c) => {
          const Icon = c.icon;
          return (
            <button
              key={c.id}
              onClick={() => setOpenCategory(c.name)}
              className="p-4 flex items-center gap-3 text-left"
              style={{
                backgroundColor: WHITE,
                borderRadius: 20,
                boxShadow: "0 4px 16px rgba(123,92,72,0.04)",
              }}
            >
              <div
                className="h-11 w-11 rounded-2xl flex items-center justify-center"
                style={{ backgroundColor: c.color }}
              >
                <Icon size={20} color={WHITE} />
              </div>
              <div className="flex-1 min-w-0">
                <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{c.name}</p>
                <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>{c.count} 个物品</p>
              </div>
            </button>
          );
        })}
      </div>

      {/* Recent items */}
      <div className="px-6 mt-7 mb-3 flex items-center justify-between">
        <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>最近标记</p>
        <span style={{ color: ORANGE, fontSize: 12 }}>编辑</span>
      </div>

      <div className="px-6 grid grid-cols-3 gap-3">
        {recentItems.map((it) => (
          <div
            key={it.id}
            className="p-3 flex flex-col items-center"
            style={{
              backgroundColor: WHITE,
              borderRadius: 18,
              boxShadow: "0 4px 16px rgba(123,92,72,0.04)",
            }}
          >
            <div
              className="h-12 w-12 rounded-2xl flex items-center justify-center mb-2"
              style={{ backgroundColor: SOFT, fontSize: 22 }}
            >
              {it.emoji}
            </div>
            <p style={{ color: COFFEE, fontSize: 11, fontWeight: 600 }}>{it.name}</p>
            <span
              className="mt-1 px-2 py-0.5"
              style={{ backgroundColor: BLUE, color: WHITE, borderRadius: 999, fontSize: 9 }}
            >
              {it.cat}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
