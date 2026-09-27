import { useEffect, useMemo, useState } from "react";
import { ArrowLeft, Search, Sparkles, BookOpen, Plus, X, Pencil, Check } from "lucide-react";
import { AddItemModal } from "./AddItemModal";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { nativeRequest, type NativeState } from "../nativeBridge";

type Book = { id: string; title: string; tag: string; cover: string };
type Group = { name: string; books: Book[] };

const COVERS = ["#A8B8CC", "#E8B894", "#C44545", "#7FA8C9", "#8B6F47", "#3A5A8C", "#E8DED0", "#8B6F47"];

/* 每个分类的示例分组（设计稿风格的中文内容，真实数据为空时作为兜底） */
const SAMPLES: Record<string, Group[]> = {
  书籍: [
    {
      name: "小说",
      books: [
        { id: "n1", title: "《活着》", tag: "已分类", cover: "#A8B8CC" },
        { id: "n2", title: "《傲慢与偏见》", tag: "已分类", cover: "#E8B894" },
        { id: "n3", title: "《简·爱》", tag: "已分类", cover: "#7FA8C9" },
      ],
    },
    {
      name: "学习",
      books: [
        { id: "s1", title: "《设计心理学》", tag: "已分类", cover: "#C44545" },
        { id: "s2", title: "《设计方法与策略》", tag: "已分类", cover: "#3A5A8C" },
        { id: "s3", title: "《设计中的设计》", tag: "已分类", cover: "#E8DED0" },
      ],
    },
    {
      name: "哲学",
      books: [
        { id: "p1", title: "《沉思录》", tag: "已分类", cover: "#8B6F47" },
        { id: "p2", title: "《查拉图斯特拉》", tag: "已分类", cover: "#4A4A4A" },
      ],
    },
  ],
  服饰: [
    {
      name: "上衣",
      books: [
        { id: "t1", title: "羊毛衫", tag: "已分类", cover: "#A8B8CC" },
        { id: "t2", title: "白色衬衫", tag: "已分类", cover: "#E8DED0" },
      ],
    },
    {
      name: "下装",
      books: [
        { id: "t3", title: "直筒牛仔裤", tag: "已分类", cover: "#3A5A8C" },
        { id: "t4", title: "针织半裙", tag: "已分类", cover: "#D9B4C7" },
      ],
    },
    {
      name: "外套",
      books: [{ id: "t5", title: "卡其风衣", tag: "已分类", cover: "#8B6F47" }],
    },
  ],
  厨房: [
    {
      name: "餐具",
      books: [
        { id: "k1", title: "陶瓷碗", tag: "已分类", cover: "#E8B894" },
        { id: "k2", title: "木筷子", tag: "已分类", cover: "#8B6F47" },
      ],
    },
    {
      name: "锅具",
      books: [{ id: "k3", title: "不粘炒锅", tag: "已分类", cover: "#4A4A4A" }],
    },
    {
      name: "调料",
      books: [
        { id: "k4", title: "海盐", tag: "已分类", cover: "#E8DED0" },
        { id: "k5", title: "黑胡椒", tag: "已分类", cover: "#4A4A4A" },
      ],
    },
  ],
  饮品: [
    {
      name: "茶",
      books: [
        { id: "d1", title: "茉莉花茶", tag: "已分类", cover: "#A9B486" },
        { id: "d2", title: "正山小种", tag: "已分类", cover: "#8B6F47" },
      ],
    },
    {
      name: "咖啡",
      books: [{ id: "d3", title: "手冲咖啡豆", tag: "已分类", cover: "#C44545" }],
    },
    {
      name: "杯具",
      books: [
        { id: "d4", title: "玻璃随行杯", tag: "已分类", cover: "#A8B8CC" },
        { id: "d5", title: "马克杯", tag: "已分类", cover: "#E8DED0" },
      ],
    },
  ],
  玩具: [
    {
      name: "积木",
      books: [
        { id: "y1", title: "乐高城市系列", tag: "已分类", cover: "#C44545" },
        { id: "y2", title: "木质积木", tag: "已分类", cover: "#E8B894" },
      ],
    },
    {
      name: "毛绒",
      books: [{ id: "y3", title: "兔子玩偶", tag: "已分类", cover: "#E8DED0" }],
    },
    {
      name: "电子",
      books: [{ id: "y4", title: "掌上游戏机", tag: "已分类", cover: "#3A5A8C" }],
    },
  ],
  健康: [
    {
      name: "常备药",
      books: [
        { id: "h1", title: "维生素C", tag: "已分类", cover: "#D9B4C7" },
        { id: "h2", title: "退热贴", tag: "已分类", cover: "#A8B8CC" },
      ],
    },
    {
      name: "保健",
      books: [{ id: "h3", title: "益生菌", tag: "已分类", cover: "#7FA8C9" }],
    },
    {
      name: "急救",
      books: [
        { id: "h4", title: "创可贴", tag: "已分类", cover: "#E8B894" },
        { id: "h5", title: "碘伏棉签", tag: "已分类", cover: "#4A4A4A" },
      ],
    },
  ],
  工具: [
    {
      name: "手动",
      books: [
        { id: "w1", title: "螺丝刀套装", tag: "已分类", cover: "#A8B8CC" },
        { id: "w2", title: "羊角锤", tag: "已分类", cover: "#8B6F47" },
      ],
    },
    {
      name: "测量",
      books: [{ id: "w3", title: "卷尺", tag: "已分类", cover: "#C44545" }],
    },
    {
      name: "耗材",
      books: [{ id: "w4", title: "双面胶带", tag: "已分类", cover: "#E8DED0" }],
    },
  ],
  装饰: [
    {
      name: "摆件",
      books: [
        { id: "z1", title: "陶瓷花瓶", tag: "已分类", cover: "#E8DED0" },
        { id: "z2", title: "树脂摆件", tag: "已分类", cover: "#D9B4C7" },
      ],
    },
    {
      name: "香薰",
      books: [{ id: "z3", title: "香薰蜡烛", tag: "已分类", cover: "#E8B894" }],
    },
    {
      name: "绿植",
      books: [{ id: "z4", title: "龟背竹", tag: "已分类", cover: "#A9B486" }],
    },
  ],
};

export function BooksCategoryScreen({
  onBack,
  categoryName = "书籍",
  nativeState,
  onNativeChange,
}: {
  onBack: () => void;
  categoryName?: string;
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
}) {
  /* 真实物品：按建议区域分组；没有真实数据时回落到设计稿示例 */
  const realGroups = useMemo<Group[]>(() => {
    const items =
      nativeState?.spaces.flatMap((space) =>
        space.detectedItems
          .filter((item) => (item.category || "").trim() === categoryName)
          .map((item) => ({ ...item, zone: item.suggestedZone?.trim() || "未分组" }))
      ) ?? [];
    const map = new Map<string, Book[]>();
    items.forEach((item, index) => {
      const list = map.get(item.zone) ?? [];
      list.push({
        id: `real-${item.id}`,
        title: item.name,
        tag: item.spaceName ?? "已扫描",
        cover: COVERS[index % COVERS.length],
      });
      map.set(item.zone, list);
    });
    return Array.from(map, ([name, books]) => ({ name, books }));
  }, [nativeState, categoryName]);

  const fallbackGroups = useMemo<Group[]>(
    () => SAMPLES[categoryName] ?? [{ name: `${categoryName}物件`, books: [] }],
    [categoryName]
  );
  const resolvedGroups = realGroups.length > 0 ? realGroups : fallbackGroups;
  const [groups, setGroups] = useState<Group[]>(resolvedGroups);

  useEffect(() => {
    setGroups(resolvedGroups);
  }, [resolvedGroups]);

  const [editing, setEditing] = useState(false);
  const [adding, setAdding] = useState(false);
  const [addingSubgroup, setAddingSubgroup] = useState(false);
  const [newSubgroupName, setNewSubgroupName] = useState("");
  const [confirmDeleteGroup, setConfirmDeleteGroup] = useState<string | null>(null);

  const total = groups.reduce((acc, g) => acc + g.books.length, 0);

  const removeBook = (groupName: string, id: string) => {
    setGroups((gs) =>
      gs.map((g) =>
        g.name === groupName ? { ...g, books: g.books.filter((b) => b.id !== id) } : g
      )
    );
    if (id.startsWith("real-")) {
      void nativeRequest("item.delete", { id: id.slice(5) }).then(onNativeChange);
    }
  };

  const addSubgroup = () => {
    const name = newSubgroupName.trim();
    if (!name) return;
    if (groups.some((g) => g.name.toLowerCase() === name.toLowerCase())) return;
    setGroups((gs) => [...gs, { name, books: [] }]);
    setNewSubgroupName("");
    setAddingSubgroup(false);
  };

  const removeSubgroup = (name: string) => {
    setGroups((gs) => gs.filter((g) => g.name !== name));
    setConfirmDeleteGroup(null);
  };

  const addBook = (item: { name: string; subgroup: string }) => {
    const colors = ["#A8B8CC", "#E8B894", "#C44545", "#7FA8C9", "#8B6F47"];
    const title =
      categoryName === "书籍" && !item.name.startsWith("《") ? `《${item.name}》` : item.name;
    const newBook: Book = {
      id: `new-${Date.now()}`,
      title,
      tag: "新添加",
      cover: colors[Math.floor(Math.random() * colors.length)],
    };
    setGroups((gs) =>
      gs.map((g) =>
        g.name === item.subgroup ? { ...g, books: [...g.books, newBook] } : g
      )
    );
    void nativeRequest("item.add", { name: item.name, category: categoryName }).then(onNativeChange);
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
              AI 已自动标注 8 件物品
            </p>
            <p style={{ color: WHITE, opacity: 0.85, fontSize: 11 }}>点击查看并确认</p>
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
          {editing && (
            <button
              onClick={() => setAddingSubgroup(true)}
              className="h-9 px-3 flex items-center gap-1 rounded-full"
              style={{
                backgroundColor: ORANGE,
                color: WHITE,
                boxShadow: "0 4px 12px rgba(250,136,58,0.3)",
              }}
            >
              <Plus size={14} />
              <span style={{ fontSize: 11, fontWeight: 600 }}>新建分组</span>
            </button>
          )}
        </div>

        {/* Subgroups */}
        {groups.map((g) => (
          <div key={g.name} className="mt-6">
            <div className="px-6 mb-3 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>{g.name}</p>
                {editing && (
                  <button
                    onClick={() => setConfirmDeleteGroup(g.name)}
                    className="h-6 w-6 rounded-full flex items-center justify-center"
                    style={{
                      backgroundColor: "#E25555",
                      boxShadow: "0 4px 10px rgba(226,85,85,0.3)",
                    }}
                  >
                    <X size={12} color={WHITE} strokeWidth={3} />
                  </button>
                )}
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
                    Add Item
                  </p>
                </button>
              )}
            </div>
          </div>
        ))}

        {/* "+ 新建分组" card (edit mode) */}
        {editing && (
          <div className="px-6 mt-6">
            <button
              onClick={() => setAddingSubgroup(true)}
              className="w-full py-4 flex items-center justify-center gap-2"
              style={{
                backgroundColor: "transparent",
                border: `1.5px dashed ${ORANGE}`,
                borderRadius: 18,
                color: ORANGE,
                fontSize: 13,
                fontWeight: 600,
              }}
            >
              <Plus size={16} /> 新建分组
            </button>
          </div>
        )}

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
          subgroups={groups.map((g) => g.name)}
        />
      )}

      {/* Add Subgroup modal */}
      {addingSubgroup && (
        <div
          className="absolute inset-0 z-50 flex items-end"
          style={{ backgroundColor: "rgba(45,32,26,0.45)" }}
          onClick={() => setAddingSubgroup(false)}
        >
          <div
            className="w-full px-6 pt-5 pb-7"
            onClick={(e) => e.stopPropagation()}
            style={{
              backgroundColor: WHITE,
              borderTopLeftRadius: 32,
              borderTopRightRadius: 32,
            }}
          >
            <div className="flex items-center justify-center mb-4">
              <div className="h-1 w-10 rounded-full" style={{ backgroundColor: SOFT }} />
            </div>
            <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>新建分组</p>
            <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginTop: 2 }}>
              在「{categoryName}」下新建一个分组
            </p>
            <input
              autoFocus
              value={newSubgroupName}
              onChange={(e) => setNewSubgroupName(e.target.value)}
              placeholder="例如：漫画、科幻、诗集"
              className="w-full mt-4 px-4 py-3 outline-none"
              style={{
                backgroundColor: LINEN,
                borderRadius: 14,
                color: COFFEE,
                fontSize: 14,
              }}
            />
            <div className="flex gap-2 mt-4">
              <button
                onClick={() => setAddingSubgroup(false)}
                className="flex-1 py-3"
                style={{
                  backgroundColor: LINEN,
                  color: COFFEE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                Cancel
              </button>
              <button
                disabled={!newSubgroupName.trim()}
                onClick={addSubgroup}
                className="flex-1 py-3 flex items-center justify-center gap-2"
                style={{
                  backgroundColor: newSubgroupName.trim() ? ORANGE : SOFT,
                  color: WHITE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                <Check size={16} /> Create
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete-subgroup confirmation */}
      {confirmDeleteGroup && (
        <div
          className="absolute inset-0 z-50 flex items-center justify-center px-8"
          style={{ backgroundColor: "rgba(45,32,26,0.45)" }}
          onClick={() => setConfirmDeleteGroup(null)}
        >
          <div
            className="w-full p-6"
            onClick={(e) => e.stopPropagation()}
            style={{ backgroundColor: WHITE, borderRadius: 24 }}
          >
            <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>
              Delete "{confirmDeleteGroup}"?
            </p>
            <p style={{ color: COFFEE, opacity: 0.6, fontSize: 12, marginTop: 6 }}>
              All {groups.find((g) => g.name === confirmDeleteGroup)?.books.length ?? 0} books in
              this subgroup will be removed.
            </p>
            <div className="flex gap-2 mt-5">
              <button
                onClick={() => setConfirmDeleteGroup(null)}
                className="flex-1 py-3"
                style={{
                  backgroundColor: LINEN,
                  color: COFFEE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                Cancel
              </button>
              <button
                onClick={() => removeSubgroup(confirmDeleteGroup)}
                className="flex-1 py-3"
                style={{
                  backgroundColor: "#E25555",
                  color: WHITE,
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                Delete
              </button>
            </div>
          </div>
        </div>
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
