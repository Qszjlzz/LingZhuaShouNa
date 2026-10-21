import { useEffect, useMemo, useState } from "react";
import { ArrowLeft, Search, Sparkles, BookOpen, Plus, X, Pencil, Check } from "lucide-react";
import { AddItemModal } from "./AddItemModal";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { nativeRequest, type NativeState } from "../nativeBridge";
import { displayCategory, nativeCategory } from "../itemCategories";

type ItemCard = { id: string; title: string; tag: string; cover: string };
type Group = { name: string; books: ItemCard[] };
const COVERS = ["#A8B8CC", "#E8B894", "#C44545", "#7FA8C9", "#8B6F47", "#3A5A8C"];

export function BooksCategoryScreen({ onBack, categoryName = "书籍", nativeState, onNativeChange, onCamera }: {
  onBack: () => void;
  categoryName?: string;
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
  onCamera?: () => void;
}) {
  const storageKey = `smartpaw.emptyGroups.${categoryName}`;
  const [emptyGroups, setEmptyGroups] = useState<string[]>(() => {
    try {
      const value = JSON.parse(window.localStorage.getItem(storageKey) || "[]");
      return Array.isArray(value) ? value.filter((name): name is string => typeof name === "string") : [];
    } catch {
      return [];
    }
  });
  useEffect(() => {
    try { window.localStorage.setItem(storageKey, JSON.stringify(emptyGroups)); } catch { /* Storage may be disabled. */ }
  }, [storageKey, emptyGroups]);
  const [editing, setEditing] = useState(false);
  const [adding, setAdding] = useState(false);
  const [selectedSubgroup, setSelectedSubgroup] = useState<string | null>(null);
  const [addingSubgroup, setAddingSubgroup] = useState(false);
  const [newSubgroupName, setNewSubgroupName] = useState("");
  const [confirmDeleteGroup, setConfirmDeleteGroup] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const groups = useMemo<Group[]>(() => {
    const grouped = new Map<string, ItemCard[]>();
    (nativeState?.spaces ?? []).forEach((space) => {
      space.detectedItems.filter((item) => displayCategory(item.category || "未分类") === categoryName)
        .forEach((item, index) => {
          const zone = item.suggestedZone?.trim() || "未分组";
          const entries = grouped.get(zone) ?? [];
          entries.push({ id: item.id, title: item.name, tag: space.name, cover: COVERS[index % COVERS.length] });
          grouped.set(zone, entries);
        });
    });
    emptyGroups.forEach((name) => { if (!grouped.has(name)) grouped.set(name, []); });
    if (grouped.size === 0) grouped.set("未分组", []);
    return Array.from(grouped, ([name, books]) => ({ name, books }));
  }, [nativeState, categoryName, emptyGroups]);

  const total = groups.reduce((count, group) => count + group.books.length, 0);
  const keyword = query.trim().toLowerCase();
  const filteredGroups = groups.map((group) => ({
    ...group,
    books: group.books.filter((book) => `${book.title} ${book.tag} ${group.name}`.toLowerCase().includes(keyword)),
  })).filter((group) => !keyword || group.books.length > 0);

  const removeItem = async (id: string) => {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      await nativeRequest("item.delete", { id });
      onNativeChange?.();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "删除失败，请重试");
    } finally {
      setBusy(false);
    }
  };

  const addSubgroup = () => {
    const name = newSubgroupName.trim();
    if (!name || groups.some((group) => group.name.toLowerCase() === name.toLowerCase())) return;
    setEmptyGroups((current) => [...current, name]);
    setNewSubgroupName("");
    setAddingSubgroup(false);
  };

  const removeSubgroup = async (name: string) => {
    if (busy) return;
    const items = groups.find((group) => group.name === name)?.books ?? [];
    setConfirmDeleteGroup(null);
    setBusy(true);
    setError(null);
    try {
      for (const item of items) {
        await nativeRequest("item.zone.update", { id: item.id, suggestedZone: "未分组" });
      }
      setEmptyGroups((current) => current.filter((group) => group !== name));
      onNativeChange?.();
    } catch (cause) {
      onNativeChange?.();
      setError(cause instanceof Error ? cause.message : "分组调整失败，请重试");
    } finally {
      setBusy(false);
    }
  };

  const addItem = async (item: { name: string; subgroup: string }) => {
    await nativeRequest("item.add", { name: item.name, category: nativeCategory(categoryName), suggestedZone: item.subgroup });
    setEmptyGroups((current) => current.filter((group) => group !== item.subgroup));
    onNativeChange?.();
  };

  return (
    <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: LINEN }}>
      <div className="h-full w-full overflow-y-auto pb-32">
        <div className="px-6 pt-14 pb-2 flex items-center justify-between">
          <button onClick={onBack} aria-label="返回分类" className="h-11 w-11 rounded-full flex items-center justify-center" style={{ backgroundColor: WHITE }}><ArrowLeft size={20} color={COFFEE} /></button>
          <div><p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, textAlign: "center" }}>全部物品</p><p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>分类管理</p></div>
          <button onClick={() => setEditing((value) => !value)} disabled={busy} className="h-11 px-4 rounded-full flex items-center gap-1.5 disabled:opacity-50" style={{ backgroundColor: editing ? ORANGE : WHITE, color: editing ? WHITE : COFFEE }}>
            {editing ? <Check size={16} /> : <Pencil size={14} />}<span style={{ fontSize: 12, fontWeight: 600 }}>{editing ? "完成" : "编辑"}</span>
          </button>
        </div>

        <div className="px-6 mt-4"><div className="flex items-center gap-3 px-5 py-3.5" style={{ backgroundColor: WHITE, borderRadius: 24, boxShadow: "0 4px 20px rgba(123,92,72,0.05)" }}>
          <Search size={18} color={COFFEE} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="搜索物品" className="flex-1 min-w-0 bg-transparent outline-none" style={{ color: COFFEE, fontSize: 14 }} />
          <div className="px-2.5 py-1.5 flex items-center gap-1" style={{ backgroundColor: LINEN, borderRadius: 999 }}><Sparkles size={12} color={ORANGE} /><span style={{ color: ORANGE, fontSize: 11 }}>AI 标注</span></div>
        </div></div>

        <div className="mx-6 mt-4 p-4 flex items-center gap-3" style={{ background: `linear-gradient(135deg, ${ORANGE} 0%, #FFAA66 100%)`, borderRadius: 20 }}>
          <div className="h-10 w-10 rounded-full flex items-center justify-center" style={{ backgroundColor: "rgba(255,255,255,0.25)" }}><Sparkles size={18} color={WHITE} /></div>
          <div className="flex-1"><p style={{ color: WHITE, fontSize: 13, fontWeight: 600 }}>已收录 {total} 件{categoryName}物品</p><p style={{ color: WHITE, opacity: 0.85, fontSize: 11 }}>可搜索、添加或调整分组</p></div>
        </div>

        <div className="mx-6 mt-5 px-4 py-3 flex items-center gap-3" style={{ backgroundColor: WHITE, borderRadius: 18 }}>
          <div className="h-11 w-11 rounded-2xl flex items-center justify-center" style={{ backgroundColor: LINEN }}><BookOpen size={20} color={COFFEE} /></div>
          <div className="flex-1"><p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>{categoryName}</p><p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>{total} 件 · {groups.length} 个分组</p></div>
          {editing && <button onClick={() => setAddingSubgroup(true)} className="h-9 px-3 flex items-center gap-1 rounded-full" style={{ backgroundColor: ORANGE, color: WHITE }}><Plus size={14} /><span style={{ fontSize: 11, fontWeight: 600 }}>新建分组</span></button>}
        </div>

        {error && <p role="alert" className="mx-6 mt-3 text-xs" style={{ color: "#B44740" }}>{error}</p>}
        {total === 0 && !query && <p className="px-6 mt-5" style={{ color: COFFEE, opacity: 0.6, fontSize: 12 }}>此分类还没有物品，点击右下角添加。</p>}
        {query && filteredGroups.length === 0 && <p className="px-6 mt-5" style={{ color: COFFEE, opacity: 0.6, fontSize: 12 }}>没有匹配的物品。</p>}

        {filteredGroups.map((group) => (
          <div key={group.name} className="mt-6">
            <div className="px-6 mb-3 flex items-center justify-between"><div className="flex items-center gap-2">
              <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>{group.name}</p>
              {editing && group.name !== "未分组" && <button onClick={() => setConfirmDeleteGroup(group.name)} disabled={busy} aria-label={`移除${group.name}分组`} className="h-6 w-6 rounded-full flex items-center justify-center disabled:opacity-50" style={{ backgroundColor: "#E25555" }}><X size={12} color={WHITE} strokeWidth={3} /></button>}
            </div><span style={{ color: COFFEE, opacity: 0.5, fontSize: 11 }}>{group.books.length}</span></div>
            <div className="px-6 grid grid-cols-3 gap-3">
              {group.books.map((book) => <ItemTile key={book.id} item={book} editing={editing} disabled={busy} onRemove={() => void removeItem(book.id)} />)}
              {editing && <button onClick={() => { setSelectedSubgroup(group.name); setAdding(true); }} className="flex flex-col items-center justify-center" style={{ backgroundColor: WHITE, border: `1.5px dashed ${ORANGE}`, borderRadius: 16, minHeight: 140 }}><div className="h-9 w-9 rounded-full flex items-center justify-center" style={{ backgroundColor: ORANGE }}><Plus size={18} color={WHITE} /></div><p style={{ color: ORANGE, fontSize: 11, fontWeight: 600, marginTop: 6 }}>添加物品</p></button>}
            </div>
          </div>
        ))}
        {editing && <div className="px-6 mt-6"><button onClick={() => setAddingSubgroup(true)} className="w-full py-4 flex items-center justify-center gap-2" style={{ border: `1.5px dashed ${ORANGE}`, borderRadius: 18, color: ORANGE, fontSize: 13, fontWeight: 600 }}><Plus size={16} /> 新建分组</button></div>}
      </div>

      {!editing && <button onClick={() => { setSelectedSubgroup(null); setAdding(true); }} aria-label="添加物品" className="absolute right-5 bottom-28 h-14 w-14 rounded-full flex items-center justify-center" style={{ backgroundColor: ORANGE, boxShadow: "0 8px 24px rgba(250,136,58,0.4)" }}><Plus size={26} color={WHITE} strokeWidth={2.5} /></button>}
      {adding && <AddItemModal onClose={() => setAdding(false)} onAdd={addItem} onCamera={onCamera} subgroups={groups.map((group) => group.name)} selectedSubgroup={selectedSubgroup ?? undefined} />}

      {addingSubgroup && <div className="absolute inset-0 z-50 flex items-end" style={{ backgroundColor: "rgba(45,32,26,0.45)" }} onClick={() => setAddingSubgroup(false)}><div className="w-full px-6 pt-5 pb-7" onClick={(event) => event.stopPropagation()} style={{ backgroundColor: WHITE, borderTopLeftRadius: 32, borderTopRightRadius: 32 }}>
        <div className="flex items-center justify-center mb-4"><div className="h-1 w-10 rounded-full" style={{ backgroundColor: SOFT }} /></div><p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>新建分组</p>
        <input autoFocus value={newSubgroupName} onChange={(event) => setNewSubgroupName(event.target.value)} placeholder="输入分组名称" className="w-full mt-4 px-4 py-3 outline-none" style={{ backgroundColor: LINEN, borderRadius: 14, color: COFFEE, fontSize: 14 }} />
        <div className="flex gap-2 mt-4"><button onClick={() => setAddingSubgroup(false)} className="flex-1 py-3" style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, fontSize: 13 }}>取消</button><button disabled={!newSubgroupName.trim() || groups.some((group) => group.name.toLowerCase() === newSubgroupName.trim().toLowerCase())} onClick={addSubgroup} className="flex-1 py-3 flex items-center justify-center gap-2 disabled:opacity-50" style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, fontSize: 13 }}><Check size={16} /> 创建</button></div>
      </div></div>}

      {confirmDeleteGroup && <div className="absolute inset-0 z-50 flex items-center justify-center px-8" style={{ backgroundColor: "rgba(45,32,26,0.45)" }} onClick={() => setConfirmDeleteGroup(null)}><div className="w-full p-6" onClick={(event) => event.stopPropagation()} style={{ backgroundColor: WHITE, borderRadius: 24 }}>
        <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>移除「{confirmDeleteGroup}」分组？</p><p style={{ color: COFFEE, opacity: 0.6, fontSize: 12, marginTop: 6 }}>其中的物品会移至「未分组」，不会删除物品。</p>
        <div className="flex gap-2 mt-5"><button onClick={() => setConfirmDeleteGroup(null)} className="flex-1 py-3" style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, fontSize: 13 }}>取消</button><button onClick={() => void removeSubgroup(confirmDeleteGroup)} className="flex-1 py-3" style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, fontSize: 13 }}>移除分组</button></div>
      </div></div>}
    </div>
  );
}

function ItemTile({ item, editing, disabled, onRemove }: { item: ItemCard; editing: boolean; disabled: boolean; onRemove: () => void }) {
  return <div className="relative flex flex-col items-center p-2" style={{ backgroundColor: WHITE, borderRadius: 16, boxShadow: "0 4px 12px rgba(123,92,72,0.04)" }}>
    <div className="w-full flex items-end justify-center" style={{ height: 88, background: `linear-gradient(160deg, ${item.cover} 0%, ${item.cover}cc 100%)`, borderRadius: 10, marginBottom: 8, position: "relative", overflow: "hidden" }}><div className="absolute left-1.5 top-1.5 bottom-1.5 w-[3px] rounded-full" style={{ backgroundColor: "rgba(0,0,0,0.18)" }} /><span style={{ color: WHITE, fontSize: 9, fontWeight: 600, padding: "4px 6px", textAlign: "center", lineHeight: 1.2 }}>{item.title.replace(/[《》]/g, "")}</span></div>
    <p className="w-full break-words" style={{ color: COFFEE, fontSize: 11, fontWeight: 500, textAlign: "center", lineHeight: 1.3 }}>{item.title}</p><span className="mt-1.5 px-2 py-0.5" style={{ backgroundColor: BLUE, color: WHITE, borderRadius: 999, fontSize: 9 }}>{item.tag}</span>
    {editing && <button onClick={onRemove} disabled={disabled} aria-label={`删除${item.title}`} className="absolute -top-1.5 -right-1.5 h-6 w-6 rounded-full flex items-center justify-center disabled:opacity-50" style={{ backgroundColor: "#E25555" }}><X size={13} color={WHITE} strokeWidth={3} /></button>}
  </div>;
}
