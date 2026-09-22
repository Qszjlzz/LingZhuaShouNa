import { useState } from "react";
import { ArrowLeft, Search, Sparkles, BookOpen, Plus, X, Pencil, Check } from "lucide-react";
import { AddItemModal } from "./AddItemModal";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";

type Book = { id: string; title: string; tag: string; cover: string };
type Group = { name: string; books: Book[] };

const initial: Group[] = [
  {
    name: "Novel",
    books: [
      { id: "n1", title: "《活着》", tag: "已分类", cover: "#A8B8CC" },
      { id: "n2", title: "《傲慢与偏见》", tag: "已分类", cover: "#E8B894" },
      { id: "n3", title: "《简·爱》", tag: "已分类", cover: "#7FA8C9" },
    ],
  },
  {
    name: "Study",
    books: [
      { id: "s1", title: "《设计心理学》", tag: "已分类", cover: "#C44545" },
      { id: "s2", title: "《设计方法与策略》", tag: "已分类", cover: "#3A5A8C" },
      { id: "s3", title: "《设计中的设计》", tag: "已分类", cover: "#E8DED0" },
    ],
  },
  {
    name: "Philosophy",
    books: [
      { id: "p1", title: "《沉思录》", tag: "已分类", cover: "#8B6F47" },
      { id: "p2", title: "《查拉图斯特拉》", tag: "已分类", cover: "#4A4A4A" },
    ],
  },
];

export function BooksCategoryScreen({ onBack }: { onBack: () => void }) {
  const [groups, setGroups] = useState<Group[]>(initial);
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
    const newBook: Book = {
      id: `new-${Date.now()}`,
      title: item.name.startsWith("《") ? item.name : `《${item.name}》`,
      tag: "新添加",
      cover: colors[Math.floor(Math.random() * colors.length)],
    };
    setGroups((gs) =>
      gs.map((g) =>
        g.name === item.subgroup ? { ...g, books: [...g.books, newBook] } : g
      )
    );
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
              All your stuff
            </p>
            <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>Classification</p>
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
            <span style={{ fontSize: 12, fontWeight: 600 }}>{editing ? "Done" : "Edit"}</span>
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
              defaultValue="book"
              className="flex-1 bg-transparent outline-none"
              style={{ color: COFFEE, fontSize: 14 }}
            />
            <div
              className="px-2.5 py-1.5 flex items-center gap-1"
              style={{ backgroundColor: LINEN, borderRadius: 999 }}
            >
              <Sparkles size={12} color={ORANGE} />
              <span style={{ color: ORANGE, fontSize: 11 }}>AI Tag</span>
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
              AI auto-tagged 8 new items
            </p>
            <p style={{ color: WHITE, opacity: 0.85, fontSize: 11 }}>Tap to review and confirm</p>
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
            <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>Books</p>
            <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>
              {total} items · {groups.length} subgroups
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
              <span style={{ fontSize: 11, fontWeight: 600 }}>Subgroup</span>
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

        {/* "+ New Subgroup" card (edit mode) */}
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
              <Plus size={16} /> New Subgroup
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
            <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>New Subgroup</p>
            <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginTop: 2 }}>
              Create a new bookshelf under "Books"
            </p>
            <input
              autoFocus
              value={newSubgroupName}
              onChange={(e) => setNewSubgroupName(e.target.value)}
              placeholder="e.g. Manga, Sci-Fi, Poetry"
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
