import { useState } from "react";
import { Search, Sparkles, Shirt, BookOpen, Coffee, Gamepad2, Pill, Wrench, Utensils, Sparkle, Smartphone, Pencil, Trash2, Package } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { BooksCategoryScreen } from "./BooksCategoryScreen";
import type { NativeState } from "../nativeBridge";
import { displayCategory } from "../itemCategories";

const categories = [
  { id: "c1", name: "服饰", icon: Shirt, color: BLUE },
  { id: "c2", name: "书籍", icon: BookOpen, color: "#D9C2A8" },
  { id: "c3", name: "厨房", icon: Utensils, color: "#E8B894" },
  { id: "c4", name: "饮品", icon: Coffee, color: "#C9A687" },
  { id: "c5", name: "玩具", icon: Gamepad2, color: "#B4D4C9" },
  { id: "c6", name: "健康", icon: Pill, color: "#D9B4C7" },
  { id: "c7", name: "工具", icon: Wrench, color: "#A8B8CC" },
  { id: "c8", name: "装饰", icon: Sparkle, color: "#E8D4B4" },
];

const legacyCategories = [
  { id: "old-electronics", name: "电子产品", icon: Smartphone, color: "#A8B8CC" },
  { id: "old-stationery", name: "文具", icon: Pencil, color: "#D9C2A8" },
  { id: "old-discard", name: "待丢弃", icon: Trash2, color: "#C9A687" },
];

interface ClassificationScreenProps {
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
  onCamera?: () => void;
}

export function ClassificationScreen({ nativeState, onNativeChange, onCamera }: ClassificationScreenProps = {}) {
  const [openCategory, setOpenCategory] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const keyword = query.trim().toLowerCase();
  const items = nativeState?.spaces.flatMap((space) => space.detectedItems) ?? [];
  const counts = new Map<string, number>();
  items.forEach((item) => {
    const name = displayCategory(item.category || "未分类");
    counts.set(name, (counts.get(name) ?? 0) + 1);
  });

  if (openCategory) {
    return (
      <BooksCategoryScreen
        categoryName={openCategory}
        nativeState={nativeState}
        onNativeChange={onNativeChange}
        onCamera={onCamera}
        onBack={() => setOpenCategory(null)}
      />
    );
  }

  const known = new Set([...categories, ...legacyCategories].map((category) => category.name));
  const extraCategories = [
    ...legacyCategories.filter((category) => counts.has(category.name)),
    ...Array.from(counts.keys()).filter((name) => !known.has(name)).map((name) => ({ id: `other-${name}`, name, icon: Package, color: BLUE })),
  ];
  const filteredCategories = categories.filter((c) => c.name.toLowerCase().includes(keyword));
  const filteredExtra = extraCategories.filter((c) => c.name.toLowerCase().includes(keyword));
  const filteredRecent = [...items].reverse().filter((item) =>
    `${item.name} ${displayCategory(item.category)}`.toLowerCase().includes(keyword)
  ).slice(0, 6);

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

      {/* Recorded item summary */}
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
          <p style={{ color: WHITE, fontSize: 13, fontWeight: 600 }}>已记录 {items.length} 件物品</p>
          <p style={{ color: WHITE, opacity: 0.85, fontSize: 11 }}>按类别查看和整理</p>
        </div>
      </div>

      {/* Categories grid */}
      <div className="px-6 mt-7 mb-3 flex items-center justify-between">
        <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>分类</p>
        <span style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>{filteredCategories.length + filteredExtra.length}</span>
      </div>

      <div className="px-6 grid grid-cols-2 gap-3">
        {[...filteredCategories, ...filteredExtra].map((c) => {
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
                <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>{counts.get(c.name) ?? 0} 个物品</p>
              </div>
            </button>
          );
        })}
      </div>

      {/* Recent items */}
      <div className="px-6 mt-7 mb-3 flex items-center justify-between">
        <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>最近标记</p>
        <span style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>{filteredRecent.length}</span>
      </div>

      <div className="px-6 grid grid-cols-3 gap-3">
        {filteredRecent.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => setOpenCategory(displayCategory(item.category || "未分类"))}
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
              <Package size={22} color={COFFEE} />
            </div>
            <p className="w-full truncate text-center" style={{ color: COFFEE, fontSize: 11, fontWeight: 600 }}>{item.name}</p>
            <span
              className="mt-1 px-2 py-0.5"
              style={{ backgroundColor: BLUE, color: WHITE, borderRadius: 999, fontSize: 9 }}
            >
              {displayCategory(item.category || "未分类")}
            </span>
          </button>
        ))}
      </div>
      {items.length === 0 && <p className="px-6 mt-3" style={{ color: COFFEE, opacity: 0.55, fontSize: 12 }}>还没有标记的物品，拍照或手动添加后会显示在这里。</p>}
    </div>
  );
}
