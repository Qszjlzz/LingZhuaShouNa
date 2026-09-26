import { useState } from "react";
import { Search, Sparkles, Shirt, BookOpen, Coffee, Gamepad2, Pill, Wrench, Utensils, Sparkle } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { BooksCategoryScreen, resolveCategoryGroups, type CategoryGroup } from "./BooksCategoryScreen";
import type { NativeState } from "../nativeBridge";

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

interface ClassificationScreenProps {
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
}

export function ClassificationScreen({ nativeState, onNativeChange }: ClassificationScreenProps = {}) {
  const [openCategory, setOpenCategory] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const keyword = query.trim().toLowerCase();

  if (openCategory) {
    return (
      <BooksCategoryScreen
        categoryName={openCategory}
        nativeState={nativeState}
        onNativeChange={onNativeChange}
        onBack={() => setOpenCategory(null)}
      />
    );
  }

  const filteredCategories = categories.filter((c) => c.name.toLowerCase().includes(keyword));
  const filteredRecent = recentItems.filter(
    (it) => `${it.name}${it.cat}`.toLowerCase().includes(keyword)
  );

  /* 搜索联想（设计稿：匹配分类 → 建议卡 + 该分类下匹配的分组物品卡） */
  const matchedCategory =
    keyword.length > 0
      ? categories.find((c) => c.name.includes(query.trim()) || query.trim().includes(c.name))
      : undefined;
  let searchGroups: CategoryGroup[] = [];
  if (matchedCategory) {
    const all = resolveCategoryGroups(matchedCategory.name, nativeState);
    searchGroups = all
      .map((g) => ({
        ...g,
        books: g.books.filter((b) => b.title.toLowerCase().includes(keyword)),
      }))
      .filter((g) => g.books.length > 0);
    if (searchGroups.length === 0) searchGroups = all; // 命中分类但没命中具体物品时展示全部分组
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
            value={query}
            onChange={(event) => setQuery(event.target.value)}
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

      {/* 搜索联想结果（设计稿第 2/3 屏：建议卡 + 匹配分组） */}
      {matchedCategory ? (
        <>
          <div className="px-6 mt-4">
            <button
              onClick={() => setOpenCategory(matchedCategory.name)}
              className="w-full px-4 py-3 flex items-center gap-3 text-left"
              style={{ backgroundColor: WHITE, borderRadius: 18, boxShadow: "0 4px 16px rgba(123,92,72,0.04)" }}
            >
              <div
                className="h-11 w-11 rounded-2xl flex items-center justify-center flex-shrink-0"
                style={{ backgroundColor: matchedCategory.color }}
              >
                <matchedCategory.icon size={20} color={WHITE} />
              </div>
              <div className="flex-1 min-w-0">
                <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>{matchedCategory.name}</p>
                <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>{matchedCategory.count} 个物品</p>
              </div>
            </button>
          </div>
          {searchGroups.map((g) => (
            <div key={g.name} className="mt-6">
              <div className="px-6 mb-3 flex items-center justify-between">
                <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>{g.name}</p>
                <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>{g.books.length}</span>
              </div>
              <div className="px-6 grid grid-cols-3 gap-3">
                {g.books.slice(0, 6).map((b) => (
                  <button
                    key={b.id}
                    onClick={() => setOpenCategory(matchedCategory.name)}
                    className="relative flex flex-col items-center p-2"
                    style={{
                      backgroundColor: WHITE,
                      borderRadius: 16,
                      boxShadow: "0 4px 12px rgba(123,92,72,0.04)",
                    }}
                  >
                    <div
                      className="w-full flex items-end justify-center"
                      style={{
                        height: 76,
                        background: `linear-gradient(160deg, ${b.cover} 0%, ${b.cover}cc 100%)`,
                        borderRadius: 10,
                        marginBottom: 6,
                        position: "relative",
                        overflow: "hidden",
                      }}
                    >
                      <div
                        className="absolute left-1.5 top-1.5 bottom-1.5 w-[3px] rounded-full"
                        style={{ backgroundColor: "rgba(0,0,0,0.18)" }}
                      />
                      <span
                        style={{
                          color: WHITE, fontSize: 9, fontWeight: 600, padding: "3px 5px",
                          textAlign: "center", lineHeight: 1.2, opacity: 0.9,
                        }}
                      >
                        {b.title.replace(/[《》]/g, "")}
                      </span>
                    </div>
                    <p style={{ color: COFFEE, fontSize: 10.5, fontWeight: 500, textAlign: "center", lineHeight: 1.3 }}>
                      {b.title}
                    </p>
                    <span
                      className="mt-1 mb-0.5 px-2 py-0.5"
                      style={{ backgroundColor: BLUE, color: WHITE, borderRadius: 999, fontSize: 9 }}
                    >
                      {b.tag}
                    </span>
                  </button>
                ))}
              </div>
            </div>
          ))}
        </>
      ) : (
        <>
      {/* Categories grid */}
      <div className="px-6 mt-7 mb-3 flex items-center justify-between">
        <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>分类</p>
        <span style={{ color: ORANGE, fontSize: 12, fontWeight: 500 }}>编辑</span>
      </div>

      <div className="px-6 grid grid-cols-2 gap-3">
        {filteredCategories.map((c) => {
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
        {filteredRecent.map((it) => (
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
        </>
      )}
    </div>
  );
}
