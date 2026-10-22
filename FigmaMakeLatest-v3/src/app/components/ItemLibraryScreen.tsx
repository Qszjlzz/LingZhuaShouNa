import { useEffect, useMemo, useRef, useState, type PointerEvent as ReactPointerEvent, type ReactNode } from "react";
import { ArrowLeft, ArrowRight, Check, Folder, FolderPlus, ImagePlus, Pencil, Plus, Search, Trash2, X } from "lucide-react";
import type { NativeState } from "../nativeBridge";
import { createLibraryFolder, folderKey, importLibraryItems, itemKey, libraryStorageKey, moveLibraryItem, parseLibrary, removeLibraryFolder, removeLibraryItem, renameLibraryFolder, reorderLibrary, scanLibraryItems, updateLibraryItem, type LibraryItem, type LibraryState } from "../itemLibrary";
import { CategoryArtwork } from "./CategoryArtwork";
import { BLUE, COFFEE, LINEN, ORANGE, SOFT, WHITE } from "./theme";

type ItemForm = { id?: string; name: string; category: string; image?: string };
type PointerDrag = { key: string; x: number; y: number; active: boolean; moved: boolean; pointer: number };
const newID = () => globalThis.crypto?.randomUUID?.() || Date.now().toString(36) + Math.random().toString(36).slice(2);

async function localImage(file: File): Promise<string> {
  if (!file.type.startsWith("image/") || file.size > 12 * 1024 * 1024) throw new Error("请选择小于 12MB 的图片");
  const url = URL.createObjectURL(file);
  try {
    const image = new Image(); image.src = url;
    await new Promise<void>((resolve, reject) => { image.onload = () => resolve(); image.onerror = () => reject(new Error("无法读取这张图片，请换一张")); });
    const scale = Math.min(1, 640 / Math.max(image.naturalWidth, image.naturalHeight));
    const canvas = document.createElement("canvas"); canvas.width = Math.max(1, Math.round(image.naturalWidth * scale)); canvas.height = Math.max(1, Math.round(image.naturalHeight * scale));
    const context = canvas.getContext("2d"); if (!context) throw new Error("当前无法处理图片");
    context.fillStyle = "#FFFFFF"; context.fillRect(0, 0, canvas.width, canvas.height); context.drawImage(image, 0, 0, canvas.width, canvas.height);
    const result = canvas.toDataURL("image/jpeg", 0.8);
    if (result.length >= 900000) throw new Error("图片仍然过大，请选择较小图片");
    return result;
  } finally { URL.revokeObjectURL(url); }
}

export function ItemLibraryScreen({ nativeState, onBack }: { nativeState?: NativeState | null; onBack: () => void }) {
  const storageKey = libraryStorageKey(nativeState?.isPresentationMode ?? true);
  const [library, setLibrary] = useState<LibraryState>(() => { try { return parseLibrary(localStorage.getItem(storageKey)); } catch { return parseLibrary(null); } });
  const [folderID, setFolderID] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [query, setQuery] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [importing, setImporting] = useState(false);
  const [chosen, setChosen] = useState<string[]>([]);
  const [itemForm, setItemForm] = useState<ItemForm | null>(null);
  const [folderForm, setFolderForm] = useState<{ id?: string; name: string } | null>(null);
  const [movingID, setMovingID] = useState<string | null>(null);
  const [removingFolder, setRemovingFolder] = useState<string | null>(null);
  const [imageBusy, setImageBusy] = useState(false);
  const [dragging, setDragging] = useState<string | null>(null);
  const [dropHint, setDropHint] = useState<{ key: string; combine: boolean } | null>(null);
  const pointer = useRef<PointerDrag | null>(null);
  const holdTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const suppressClick = useRef(false);
  const currentFolder = library.folders.find((folder) => folder.id === folderID);
  const keyword = query.trim().toLowerCase();
  const ordered = currentFolder ? currentFolder.itemIDs.map(itemKey) : library.rootOrder;
  const itemsByID = new Map(library.items.map((item) => [item.id, item]));
  const candidates = useMemo(() => {
    const values = new Map<string, LibraryItem>();
    (nativeState?.spaces ?? []).forEach((space) => scanLibraryItems(space.detectedItems, { spaceID: space.id, spaceName: space.name }).forEach((item) => values.set(item.id, item)));
    scanLibraryItems(nativeState?.scannedItems ?? [], { spaceID: nativeState?.selectedSpaceID, spaceName: "最近识别" }).forEach((item) => { if (!values.has(item.id)) values.set(item.id, item); });
    return [...values.values()];
  }, [nativeState]);
  const clearHold = () => { if (holdTimer.current) clearTimeout(holdTimer.current); holdTimer.current = null; };
  const cancelDrag = () => { clearHold(); pointer.current = null; setDragging(null); setDropHint(null); };
  useEffect(() => () => { if (holdTimer.current) clearTimeout(holdTimer.current); }, []);
  useEffect(() => { if (!editing) cancelDrag(); }, [editing]);
  const commit = (next: LibraryState): boolean => {
    try { localStorage.setItem(storageKey, JSON.stringify(next)); setLibrary(next); setError(null); return true; }
    catch { setError("本机空间不足或存储不可用，修改尚未保存。请减少自定义图片后重试。"); return false; }
  };
  const visible = ordered.filter((key) => {
    if (!keyword) return true;
    if (key.startsWith("folder:")) { const folder = library.folders.find((entry) => folderKey(entry.id) === key); return folder && (folder.name.toLowerCase().includes(keyword) || folder.itemIDs.some((id) => itemsByID.get(id)?.name.toLowerCase().includes(keyword))); }
    const item = itemsByID.get(key.slice(5)); return item && (item.name + " " + item.category).toLowerCase().includes(keyword);
  });
  const targetAt = (x: number, y: number) => {
    const target = document.elementFromPoint(x, y)?.closest<HTMLElement>("[data-library-key]");
    if (!target) return null;
    const rect = target.getBoundingClientRect();
    return { key: target.dataset.libraryKey!, combine: x > rect.left + rect.width * 0.22 && x < rect.right - rect.width * 0.22 && y > rect.top + 8 && y < rect.bottom - 24, after: x > rect.left + rect.width / 2 };
  };
  const pointerDown = (event: ReactPointerEvent<HTMLDivElement>, key: string) => {
    if (event.button !== 0 || (event.target as HTMLElement).closest("button,input,label,select")) return;
    clearHold(); suppressClick.current = false;
    const element = event.currentTarget;
    pointer.current = { key, x: event.clientX, y: event.clientY, active: editing, moved: false, pointer: event.pointerId };
    if (editing) event.currentTarget.setPointerCapture(event.pointerId);
    else holdTimer.current = setTimeout(() => { if (!pointer.current) return; pointer.current.active = true; suppressClick.current = true; setEditing(true); element.setPointerCapture(event.pointerId); }, 480);
  };
  const pointerMove = (event: ReactPointerEvent<HTMLDivElement>) => {
    const drag = pointer.current; if (!drag || drag.pointer !== event.pointerId) return;
    const moved = Math.hypot(event.clientX - drag.x, event.clientY - drag.y) > 8;
    if (!drag.active) { if (moved) { clearHold(); pointer.current = null; } return; }
    if (!moved && !drag.moved) return;
    drag.moved = true; suppressClick.current = true; setDragging(drag.key);
    const target = targetAt(event.clientX, event.clientY); setDropHint(target && target.key !== drag.key ? target : null);
  };
  const pointerUp = (event: ReactPointerEvent<HTMLDivElement>) => {
    clearHold(); const drag = pointer.current;
    if (drag?.active && drag.moved) {
      const target = targetAt(event.clientX, event.clientY);
      if (target && target.key !== drag.key) {
        let next = library;
        if (target.key === "root" && drag.key.startsWith("item:")) next = moveLibraryItem(library, drag.key.slice(5), null);
        else if (!currentFolder && drag.key.startsWith("item:") && target.key.startsWith("folder:")) next = moveLibraryItem(library, drag.key.slice(5), target.key.slice(7));
        else if (!currentFolder && drag.key.startsWith("item:") && target.key.startsWith("item:") && target.combine) next = createLibraryFolder(library, newID(), "新文件夹", [target.key.slice(5), drag.key.slice(5)]);
        else next = reorderLibrary(library, currentFolder ? drag.key.slice(5) : drag.key, currentFolder ? target.key.slice(5) : target.key, currentFolder?.id ?? null, target.after);
        commit(next);
      }
    }
    cancelDrag();
  };
  const activate = (key: string) => {
    if (suppressClick.current) { suppressClick.current = false; return; }
    if (key.startsWith("folder:")) { setFolderID(key.slice(7)); setQuery(""); }
    else { const item = itemsByID.get(key.slice(5)); if (item) setItemForm({ id: item.id, name: item.name, category: item.category, image: item.image }); }
  };
  const shift = (key: string, direction: number) => {
    const index = ordered.indexOf(key); const target = ordered[index + direction];
    if (target) commit(reorderLibrary(library, currentFolder ? key.slice(5) : key, currentFolder ? target.slice(5) : target, currentFolder?.id ?? null, direction > 0));
  };
  const saveItem = () => {
    if (!itemForm?.name.trim() || imageBusy) return;
    const id = itemForm.id || "manual:" + newID();
    let next = itemForm.id ? updateLibraryItem(library, id, { name: itemForm.name, image: itemForm.image }) : importLibraryItems(library, [{ ...itemForm, id, name: itemForm.name.trim() }]);
    if (!itemForm.id && currentFolder) next = moveLibraryItem(next, id, currentFolder.id);
    if (commit(next)) setItemForm(null);
  };
  const importSelected = () => {
    let next = importLibraryItems(library, candidates.filter((item) => chosen.includes(item.id)));
    if (currentFolder) chosen.forEach((id) => { next = moveLibraryItem(next, id, currentFolder.id); });
    if (commit(next)) { setImporting(false); setChosen([]); }
  };
  const modalOpen = importing || itemForm || folderForm || movingID || removingFolder;
  const orderedItems = (id: string) => { const item = itemsByID.get(id); return item ? <ItemArtwork item={item} small /> : null; };

  return <div className="relative h-full w-full overflow-hidden" style={{ backgroundColor: LINEN }}>
    <style>{"@keyframes libraryWiggle {0%,100%{transform:rotate(-0.8deg)}50%{transform:rotate(0.8deg)}} @media(prefers-reduced-motion:reduce){.library-wiggle{animation:none!important}}"}</style>
    <div className="h-full overflow-y-auto pb-32">
      <div className="px-6 pt-14 pb-2 flex items-center gap-2">
        <button aria-label={currentFolder ? "返回自由整理" : "返回分类"} onClick={() => currentFolder ? (setFolderID(null), setQuery("")) : onBack()} className="h-11 w-11 shrink-0 rounded-full flex items-center justify-center" style={{ backgroundColor: WHITE }}><ArrowLeft size={20} color={COFFEE} /></button>
        <div className="flex-1 min-w-0 text-center"><p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>我的物品库 · 本机保存</p><h1 className="truncate" style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>{currentFolder?.name ?? "自由整理"}</h1></div>
        <button onClick={() => setEditing(!editing)} className="h-11 px-3 rounded-full flex gap-1 items-center" style={{ backgroundColor: editing ? ORANGE : WHITE, color: editing ? WHITE : COFFEE, fontSize: 12 }}><Check size={14} />{editing ? "完成" : "整理"}</button>
      </div>
      <div className="mx-6 mt-4 px-4 py-3 flex items-center gap-2" style={{ backgroundColor: WHITE, borderRadius: 20 }}><Search size={17} color={COFFEE} /><input aria-label="搜索物品库" placeholder="搜索物品或文件夹" value={query} onChange={(event) => setQuery(event.target.value)} className="min-w-0 flex-1 bg-transparent outline-none" style={{ color: COFFEE, fontSize: 13 }} /></div>
      <div className="px-6 mt-4 flex flex-wrap gap-2">
        <Action onClick={() => { setChosen([]); setImporting(true); }}><Plus size={14} />选择识别物品</Action>
        <Action onClick={() => setItemForm({ name: "", category: "未分类" })}><ImagePlus size={14} />手动添加</Action>
        {currentFolder ? <Action onClick={() => setFolderForm({ id: currentFolder.id, name: currentFolder.name })}><Pencil size={14} />改名</Action> : <Action onClick={() => setFolderForm({ name: "" })}><FolderPlus size={14} />新建文件夹</Action>}
        {currentFolder && editing && <Action onClick={() => setRemovingFolder(currentFolder.id)}><Trash2 size={14} />解散文件夹</Action>}
      </div>
      <p className="px-6 mt-3" style={{ color: COFFEE, opacity: 0.6, fontSize: 11, lineHeight: 1.6 }}>{editing ? "拖到物品中央建夹，拖到边缘调序；也可用箭头和移动按钮。" : "长按物品进入整理，可跨类别自由建夹。"}</p>
      {error && <p role="alert" className="mx-6 mt-3 text-xs" style={{ color: "#B44740" }}>{error}</p>}
      <p className="px-6 mt-3 mb-3" style={{ color: COFFEE, fontSize: 12 }}>{currentFolder ? currentFolder.itemIDs.length + " 件物品" : library.items.length + " 件物品 · " + library.folders.length + " 个文件夹"}</p>
      <div className="px-6 grid grid-cols-4 gap-x-2 gap-y-4">
        {visible.map((key, index) => {
          const isFolder = key.startsWith("folder:"); const folder = isFolder ? library.folders.find((entry) => folderKey(entry.id) === key) : undefined; const item = !isFolder ? itemsByID.get(key.slice(5)) : undefined;
          if (!folder && !item) return null;
          const title = folder?.name ?? item!.name;
          return <div key={key} data-library-key={key} data-testid={"library-tile-" + key} role="button" tabIndex={0} aria-label={(isFolder ? "文件夹 " : "物品 ") + title} onKeyDown={(event) => { if (event.target !== event.currentTarget) return; if (event.key === "Enter" || event.key === " ") { event.preventDefault(); activate(key); } }} onClick={() => activate(key)} onContextMenu={(event) => event.preventDefault()} onPointerDown={(event) => pointerDown(event, key)} onPointerMove={pointerMove} onPointerUp={pointerUp} onPointerCancel={cancelDrag} className={"relative min-w-0 select-none " + (editing ? "library-wiggle" : "")} style={{ touchAction: editing ? "none" : "pan-y", WebkitUserSelect: "none", animation: editing && !modalOpen && !dragging ? "libraryWiggle 260ms ease-in-out infinite" : undefined, animationDelay: (index % 3) * -80 + "ms", opacity: dragging === key ? 0.4 : 1, outline: dropHint?.key === key ? "2px solid " + ORANGE : undefined, borderRadius: 16, padding: 2 }}>
            <div className="aspect-square w-full rounded-2xl flex items-center justify-center overflow-hidden" style={{ backgroundColor: WHITE, boxShadow: "0 4px 12px rgba(123,92,72,0.04)" }}>{folder ? <div className="grid grid-cols-2 grid-rows-2 gap-1 p-2 w-full h-full" style={{ backgroundColor: "#D9C2A844" }}>{folder.itemIDs.length ? folder.itemIDs.slice(0, 4).map((id) => <div key={id} className="overflow-hidden rounded-md flex justify-center items-center" style={{ backgroundColor: WHITE }}>{orderedItems(id)}</div>) : <Folder color={COFFEE} size={28} />}</div> : <ItemArtwork item={item!} />}</div>
            <p className="mt-1.5 text-center break-words" style={{ color: COFFEE, fontSize: 11, lineHeight: 1.3 }}>{title}</p><p className="mt-0.5 text-center truncate" style={{ color: COFFEE, opacity: 0.5, fontSize: 9 }}>{folder ? folder.itemIDs.length + " 件" : item!.category}</p>
            {editing && <div className="mt-1 flex justify-center gap-0.5" onPointerDown={(event) => event.stopPropagation()} onClick={(event) => event.stopPropagation()}><button aria-label={title + "向前移动"} disabled={ordered.indexOf(key) === 0} onClick={() => shift(key, -1)} className="p-0.5 disabled:opacity-25" style={{ color: COFFEE }}><ArrowLeft size={12} /></button>{item && <button aria-label={"移动" + title} onClick={() => setMovingID(item.id)} className="px-0 whitespace-nowrap" style={{ color: ORANGE, fontSize: 9 }}>移动</button>}<button aria-label={title + "向后移动"} disabled={ordered.indexOf(key) === ordered.length - 1} onClick={() => shift(key, 1)} className="p-0.5 disabled:opacity-25" style={{ color: COFFEE }}><ArrowRight size={12} /></button></div>}
          </div>;
        })}
      </div>
      {visible.length === 0 && <p className="px-6 py-8 text-center" style={{ color: COFFEE, opacity: 0.6, fontSize: 12 }}>{keyword ? "没有匹配的物品或文件夹" : "选择要入库的物品，或手动添加名称和图片。"}</p>}
      {currentFolder && editing && <div data-library-key="root" className="mx-6 mt-6 rounded-2xl border border-dashed p-4 text-center" style={{ borderColor: ORANGE, color: ORANGE, fontSize: 12 }}>拖到这里移出文件夹</div>}
      <p className="px-6 mt-6" style={{ color: COFFEE, opacity: 0.45, fontSize: 10 }}>文件夹与图片保存在本机。整理和移出不会修改原扫描记录；暂未同步云端。</p>
    </div>

    {importing && <Sheet title="选择要入库的物品" onClose={() => setImporting(false)}>
      <p style={{ color: COFFEE, opacity: 0.65, fontSize: 12 }}>只加入你勾选的物品，已入库的物品不会重复添加。</p>
      <div className="mt-3 space-y-2">{candidates.map((item) => { const stored = library.items.some((entry) => entry.id === item.id); return <label key={item.id} className="flex items-center gap-3 p-3 rounded-xl" style={{ backgroundColor: LINEN, opacity: stored ? 0.5 : 1 }}><input type="checkbox" disabled={stored} checked={stored || chosen.includes(item.id)} onChange={(event) => setChosen((values) => event.target.checked ? [...values, item.id] : values.filter((id) => id !== item.id))} aria-label={"入库" + item.name} /><div className="min-w-0 flex-1"><p className="break-words" style={{ color: COFFEE, fontSize: 13 }}>{item.name}</p><p style={{ color: COFFEE, opacity: 0.6, fontSize: 10 }}>{item.category} · {item.sourceSpaceName}{stored ? " · 已入库" : ""}</p></div></label>; })}</div>
      {candidates.length === 0 && <p className="py-6 text-center text-xs" style={{ color: COFFEE }}>还没有识别物品，可先手动添加或返回拍摄。</p>}
      <Primary disabled={!chosen.length} onClick={importSelected}>加入物品库（{chosen.length}）</Primary>
    </Sheet>}
    {folderForm && <Sheet title={folderForm.id ? "文件夹改名" : "新建文件夹"} onClose={() => setFolderForm(null)}><label className="text-xs" style={{ color: COFFEE }}>文件夹名称<input autoFocus maxLength={40} placeholder="输入文件夹名称" value={folderForm.name} onChange={(event) => setFolderForm({ ...folderForm, name: event.target.value })} className="mt-2 w-full p-3 rounded-xl outline-none" style={{ backgroundColor: LINEN, color: COFFEE }} /></label><Primary disabled={!folderForm.name.trim()} onClick={() => { const next = folderForm.id ? renameLibraryFolder(library, folderForm.id, folderForm.name) : createLibraryFolder(library, newID(), folderForm.name); if (commit(next)) setFolderForm(null); }}>{folderForm.id ? "保存名称" : "创建文件夹"}</Primary></Sheet>}
    {itemForm && <Sheet title={itemForm.id ? "编辑物品" : "手动添加物品"} onClose={() => !imageBusy && setItemForm(null)}>
      <label className="block text-xs" style={{ color: COFFEE }}>物品名称<input autoFocus maxLength={80} placeholder="输入物品名称" value={itemForm.name} onChange={(event) => setItemForm({ ...itemForm, name: event.target.value })} className="mt-2 w-full p-3 rounded-xl outline-none" style={{ backgroundColor: LINEN, color: COFFEE }} /></label>
      <label className="mt-3 block text-xs" style={{ color: COFFEE }}>参考分类<input disabled={!!itemForm.id} maxLength={30} value={itemForm.category} onChange={(event) => setItemForm({ ...itemForm, category: event.target.value })} className="mt-2 w-full p-3 rounded-xl outline-none disabled:opacity-50" style={{ backgroundColor: LINEN, color: COFFEE }} /></label>
      <label className="mt-4 p-3 rounded-xl flex items-center gap-3" style={{ backgroundColor: LINEN, color: COFFEE, fontSize: 12 }}>{itemForm.image ? <img src={itemForm.image} alt="自定义物品图片预览" className="w-14 h-14 rounded-lg object-contain" /> : <ImagePlus size={28} color={ORANGE} />}<span>{imageBusy ? "正在处理图片…" : "添加或更换图片"}</span><input type="file" accept="image/*" disabled={imageBusy} aria-label="选择物品图片" className="min-w-0 w-20 text-[10px]" onChange={async (event) => { const file = event.target.files?.[0]; if (!file) return; setImageBusy(true); setError(null); try { const image = await localImage(file); setItemForm((form) => form ? { ...form, image } : null); } catch (cause) { setError(cause instanceof Error ? cause.message : "图片读取失败"); } finally { setImageBusy(false); } }} /></label>
      {itemForm.image && <button className="mt-2 text-xs" style={{ color: COFFEE }} onClick={() => setItemForm({ ...itemForm, image: undefined })}>移除自定义图片</button>}
      <Primary disabled={!itemForm.name.trim() || imageBusy} onClick={saveItem}>保存物品</Primary>
      {itemForm.id && <div className="flex gap-3 mt-3"><Action onClick={() => { setMovingID(itemForm.id!); setItemForm(null); }}>移动到…</Action><Action onClick={() => { if (commit(removeLibraryItem(library, itemForm.id!))) setItemForm(null); }}>从本机物品库移除</Action></div>}
    </Sheet>}
    {movingID && <Sheet title="移动物品" onClose={() => setMovingID(null)}><div className="space-y-2"><button className="w-full p-3 text-left rounded-xl" style={{ color: COFFEE, backgroundColor: LINEN, fontSize: 13 }} onClick={() => { if (commit(moveLibraryItem(library, movingID, null))) setMovingID(null); }}>自由整理首页（移出文件夹）</button>{library.folders.map((folder) => <button key={folder.id} className="w-full p-3 text-left rounded-xl" style={{ color: COFFEE, backgroundColor: LINEN, fontSize: 13 }} onClick={() => { if (commit(moveLibraryItem(library, movingID, folder.id))) setMovingID(null); }}>{folder.name} · {folder.itemIDs.length} 件</button>)}</div></Sheet>}
    {removingFolder && <Sheet title="解散文件夹？" onClose={() => setRemovingFolder(null)}><p style={{ color: COFFEE, fontSize: 13 }}>物品会回到自由整理首页，不会删除任何物品。</p><Primary onClick={() => { if (commit(removeLibraryFolder(library, removingFolder))) { setRemovingFolder(null); setFolderID(null); } }}>确认解散</Primary></Sheet>}
    {error && modalOpen && <p role="alert" className="absolute left-6 right-6 bottom-6 z-[90] p-3 rounded-xl text-xs" style={{ backgroundColor: "#FFF0ED", color: "#B44740" }}>{error}</p>}
  </div>;
}
function ItemArtwork({ item, small = false }: { item: LibraryItem; small?: boolean }) { return item.image ? <img src={item.image} alt={item.name} draggable={false} className="w-full h-full object-contain pointer-events-none" /> : <div className="pointer-events-none"><CategoryArtwork categoryName={item.category} color={BLUE} size={small ? 25 : 48} /></div>; }
function Action({ children, onClick }: { children: ReactNode; onClick: () => void }) { return <button onClick={onClick} className="px-3 py-2 rounded-full flex items-center gap-1" style={{ color: COFFEE, backgroundColor: WHITE, border: "1px solid " + SOFT, fontSize: 11 }}>{children}</button>; }
function Primary({ children, onClick, disabled = false }: { children: ReactNode; onClick: () => void; disabled?: boolean }) { return <button disabled={disabled} onClick={onClick} className="w-full mt-4 py-3 rounded-full flex justify-center items-center gap-1 disabled:opacity-40" style={{ backgroundColor: ORANGE, color: WHITE, fontSize: 13, fontWeight: 600 }}>{children}</button>; }
function Sheet({ title, children, onClose }: { title: string; children: ReactNode; onClose: () => void }) { return <div className="absolute inset-0 z-[80] flex items-end" style={{ backgroundColor: "rgba(45,32,26,0.45)" }} onClick={onClose}><div role="dialog" aria-modal="true" aria-label={title} className="w-full max-h-[82%] overflow-y-auto px-6 pt-5 pb-7" onClick={(event) => event.stopPropagation()} style={{ backgroundColor: WHITE, borderTopLeftRadius: 28, borderTopRightRadius: 28 }}><div className="mb-4 flex items-center justify-between gap-2"><h2 style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>{title}</h2><button aria-label="关闭弹窗" onClick={onClose} className="h-9 w-9 shrink-0 rounded-full flex items-center justify-center" style={{ backgroundColor: LINEN }}><X size={16} color={COFFEE} /></button></div>{children}</div></div>; }
