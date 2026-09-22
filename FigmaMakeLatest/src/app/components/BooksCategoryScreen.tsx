import { useState } from "react";
import { ArrowLeft, Search, Sparkles, BookOpen, Plus, X, Pencil, Check } from "lucide-react";
import { AddItemModal } from "./AddItemModal";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { nativeRequest, type NativeState } from "../nativeBridge";

type Book = { id: string; title: string; tag: string; cover: string };
type Group = { name: string; books: Book[] };

// 与 Swift ItemCategory 的 rawValue 保持一致
const builtInCategories = ["书籍", "文具", "衣物", "电子产品", "收纳工具", "玩偶杂物", "待丢弃"];
const coverColors = ["#A8B8CC", "#E8B894", "#C44545", "#7FA8C9", "#8B6F47"];

export function BooksCategoryScreen({
  onBack,
  nativeState,
  onNativeChange,
  categoryName = "书籍",
}: {
  onBack: () => void;
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
  categoryName?: string;
}) {
  const [editing, setEditing] = useState(false);
  const [adding, setAdding] = useState(false);

  // 物品来自原生空间目录，按 Swift ItemCategory 分组；分类本身是固定枚举，不提供自定义分类
  const allItems = (nativeState?.spaces ?? []).flatMap((space) =>
    space.detectedItems.map((item) => ({ ...item, spaceName: space.name }))
  );
  const categoryNames = Array.from(new Set(allItems.map((item) => item.category)));
  const groups: Group[] = categoryNames.map((name) => ({
    name,
    books: allItems
      .filter((item) => item.category === name)
      .map((item, index) => ({
        id: item.id,
        title: item.name,
        tag: item.suggestedZone || item.spaceName || "已分类",
        cover: coverColors[index % coverColors.length],
      })),
  }));

  const total = groups.reduce((acc, g) => acc + g.books.length, 0);

  const mutate = (command: string, payload: Record<string, unknown>) => {
    void nativeRequest(command, payload)
      .then(() => onNativeChange?.())
      .catch(() => undefined);
  };

  const removeBook = (_groupName: string, id: string) => {
    mutate("item.delete", { id });
  };

  const addBook = (item: { name: string; subgroup: string }) => {
    if (!item.name.trim()) return;
    mutate("item.add", { name: item.name.trim(), category: item.subgroup });
  };

  return (
    <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: LINEN }}>
      <div className="h-full w-full overflow-y-auto pb-32">
        {/* Top bar */}
        <div className="px-6 pt-14 pb-2 flex items-center justify-between">
          <button
            onClick={onBack}
            className="h-11 w-11 rounded-full flex items-center justify-center"
            style={{ backgroundColor: WHITE }}
          >
            <ArrowLeft size={20} color={COFFEE} />
          </button>
          <div>
            <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, textAlign: "center" }}>
              全部物品
            </p>
            <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>分类管理</p>
          </div>
          <button
            onClick={() => setEditing((e) => !e)}
            className="h-11 px-4 rounded-full flex items-center gap-1.5"
            style={{
              backgroundColor: editing ? ORANGE : WHITE,
              color: editing ? WHITE : COFFEE,
              boxShadow: editing ? "0 6px 16px rgba(250,136,58,0.3)" : "none",
            }}
          >
            {editing ? <Check size={16} /> : <Pencil size={14} />}
            <span style={{ fontSize: 12, fontWeight: 600 }}>{editing ? "完成" : "编辑"}</span>
          </button>
        </div>

        {/* Search */}
        <div className="px-6 mt-4">
          <div
            className="flex items-center gap-3 px-5 py-3.5"
            style={{
              backgroundColor: WHITE,
              borderRadius: 24,
              boxShadow: "0 4px 20px rgba(123,92,72,0.05)",
            }}
          >
            <Search size={18} color={COFFEE} />
            <input
              placeholder="搜索物品"
              className="flex-1 bg-transparent outline-none"
              style={{ color: COFFEE, fontSize: 14 }}
            />
            <div
              className="px-2.5 py-1.5 flex items-center gap-1"
              style={{ backgroundColor: LINEN, borderRadius: 999 }}
            >
              <Sparkles size={12} color={ORANGE} />
              <span style={{ color: ORANGE, fontSize: 11 }}>AI 标注</span>
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
            <p style={{ color: WHITE, fontSize: 13, fontWeight: 600 }}>
              AI 已自动标注 {total} 件物品
            </p>
            <p style={{ color: WHITE, opacity: 0.85, fontSize: 11 }}>点击可查看和确认</p>
          </div>
        </div>

        {/* Category header */}
        <div
          className="mx-6 mt-5 px-4 py-3 flex items-center gap-3"
          style={{ backgroundColor: WHITE, borderRadius: 18 }}
        >
          <div
            className="h-11 w-11 rounded-2xl flex items-center justify-center"
            style={{ backgroundColor: LINEN }}
          >
            <BookOpen size={20} color={COFFEE} />
          </div>
          <div className="flex-1">
            <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>{categoryName}</p>
            <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>
              {total} 件 · {groups.length} 个分组
            </p>
          </div>
        </div>

        {/* Subgroups */}
        {groups.map((g) => (
          <div key={g.name} className="mt-6">
            <div className="px-6 mb-3 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>{g.name}</p>
              </div>
              <span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>
                {g.books.length}
              </span>
            </div>
            <div className="px-6 grid grid-cols-3 gap-3">
              {g.books.map((b) => (
                <BookCard
                  key={b.id}
                  book={b}
                  editing={editing}
                  onRemove={() => removeBook(g.name, b.id)}
                />
              ))}
              {editing && (
                <button
                  onClick={() => setAdding(true)}
                  className="flex flex-col items-center justify-center"
                  style={{
                    backgroundColor: WHITE,
                    border: `1.5px dashed ${ORANGE}`,
                    borderRadius: 16,
                    minHeight: 140,
                  }}
                >
                  <div
                    className="h-9 w-9 rounded-full flex items-center justify-center"
                    style={{ backgroundColor: ORANGE }}
                  >
                    <Plus size={18} color={WHITE} />
                  </div>
                  <p style={{ color: ORANGE, fontSize: 11, fontWeight: 600, marginTop: 6 }}>
                    添加物品
                  </p>
                </button>
              )}
            </div>
          </div>
        ))}

        {/* Floating add button (when not editing) */}
        {!editing && (
          <button
            onClick={() => setAdding(true)}
            className="absolute right-5 bottom-28 h-14 w-14 rounded-full flex items-center justify-center"
            style={{
              backgroundColor: ORANGE,
              boxShadow: "0 8px 24px rgba(250,136,58,0.4)",
            }}
          >
            <Plus size={26} color={WHITE} strokeWidth={2.5} />
          </button>
        )}
      </div>

      {adding && (
        <AddItemModal
          onClose={() => setAdding(false)}
          onAdd={addBook}
          subgroups={Array.from(new Set([...groups.map((g) => g.name), ...builtInCategories]))}
        />
      )}

    </div>
  );
}

function BookCard({
  book,
  editing,
  onRemove,
}: {
  book: Book;
  editing: boolean;
  onRemove: () => void;
}) {
  const isNew = book.tag === "新添加";
  return (
    <div
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
          height: 88,
          background: `linear-gradient(160deg, ${book.cover} 0%, ${book.cover}cc 100%)`,
          borderRadius: 10,
          marginBottom: 8,
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
            color: WHITE,
            fontSize: 9,
            fontWeight: 600,
            padding: "4px 6px",
            textAlign: "center",
            lineHeight: 1.2,
            opacity: 0.9,
          }}
        >
          {book.title.replace(/[《》]/g, "")}
        </span>
      </div>
      <p
        style={{
          color: COFFEE,
          fontSize: 11,
          fontWeight: 500,
          textAlign: "center",
          lineHeight: 1.3,
        }}
      >
        {book.title}
      </p>
      <span
        className="mt-1.5 px-2 py-0.5"
        style={{
          backgroundColor: isNew ? ORANGE : BLUE,
          color: WHITE,
          borderRadius: 999,
          fontSize: 9,
        }}
      >
        {book.tag}
      </span>

      {editing && (
        <button
          onClick={onRemove}
          className="absolute -top-1.5 -right-1.5 h-6 w-6 rounded-full flex items-center justify-center"
          style={{
            backgroundColor: "#E25555",
            boxShadow: "0 4px 10px rgba(226,85,85,0.4)",
          }}
        >
          <X size={13} color={WHITE} strokeWidth={3} />
        </button>
      )}
    </div>
  );
}
