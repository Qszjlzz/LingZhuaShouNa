import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from "react";
import { createPortal } from "react-dom";
import { Check, FolderPlus, X } from "lucide-react";
import type { NativeItem } from "../nativeBridge";
import { libraryStorageKey, parseLibrary, saveLibrarySelection, scanLibraryItems, type LibraryState } from "../itemLibrary";
import { COFFEE, LINEN, ORANGE, SOFT, WHITE } from "./theme";

type ScanLibraryImportProps = {
  items: NativeItem[];
  sourceSpaceID?: string;
  sourceSpaceName?: string;
  isPresentationMode: boolean;
  buttonLabel?: string;
};

/** A local library copy; this control never changes scan selection or native records. */
export function ScanLibraryImport({ items, sourceSpaceID, sourceSpaceName, isPresentationMode, buttonLabel = "选择物品入库" }: ScanLibraryImportProps) {
  const candidates = useMemo(() => scanLibraryItems(items, { spaceID: sourceSpaceID, spaceName: sourceSpaceName }), [items, sourceSpaceID, sourceSpaceName]);
  const storageKey = libraryStorageKey(isPresentationMode);
  const [open, setOpen] = useState(false);
  const [stored, setStored] = useState<LibraryState>(() => parseLibrary(null));
  const [chosen, setChosen] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const opener = useRef<HTMLButtonElement>(null);
  const dialog = useRef<HTMLDivElement>(null);
  const storedIDs = new Set(stored.items.map((item) => item.id));
  const selectedIDs = chosen.filter((id) => candidates.some((item) => item.id === id) && !storedIDs.has(id));
  useEffect(() => { setOpen(false); setChosen([]); setError(null); setNotice(null); }, [storageKey]);
  const show = () => {
    setChosen([]); setError(null); setNotice(null);
    try { setStored(parseLibrary(localStorage.getItem(storageKey))); }
    catch { setStored(parseLibrary(null)); setError("无法读取本机物品库。请确认浏览器存储可用后重试；尚未保存任何物品。"); }
    setOpen(true);
  };
  const close = () => { setOpen(false); opener.current?.focus(); };
  const save = () => {
    try {
      const result = saveLibrarySelection(localStorage, isPresentationMode, candidates, selectedIDs);
      if (result.status === "unavailable") { setError("本机空间不足或存储不可用，所选物品尚未保存。请释放空间后重试。"); return; }
      if (result.status === "empty") { setError("请先勾选至少一件尚未入库的物品。"); return; }
      setStored(result.library); setChosen([]); setError(null);
      setNotice(result.added ? "已在本机物品库保存 " + result.added + " 件物品，可到「分类 → 自由整理」查看。" : "所选物品已在本机物品库，无需重复添加。");
      close();
    } catch { setError("本机存储不可用，所选物品尚未保存。请稍后重试。"); }
  };
  const modalKey = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.key === "Escape") { event.preventDefault(); close(); return; }
    if (event.key !== "Tab") return;
    const controls = dialog.current?.querySelectorAll<HTMLElement>("button:not(:disabled), input:not(:disabled), [tabindex='0']");
    if (!controls?.length) return;
    const first = controls[0]; const last = controls[controls.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  };
  return <div className="min-w-0" data-testid="scan-library-import">
    <button ref={opener} type="button" onClick={show} className="min-h-11 w-full px-4 py-3 rounded-2xl flex items-center justify-center gap-2" style={{ backgroundColor: WHITE, border: "1px solid " + SOFT, color: COFFEE, fontSize: 12 }}><FolderPlus size={16} color={ORANGE} />{buttonLabel}</button>
    <p className="mt-1.5 px-1" style={{ color: COFFEE, opacity: 0.55, fontSize: 10, lineHeight: 1.5 }}>可只选部分物品；本机保存，暂未同步云端。</p>
    {notice && <p role="status" className="mt-2 px-1" style={{ color: COFFEE, fontSize: 11, lineHeight: 1.6 }}>{notice}</p>}
    {open && createPortal(<div className="fixed inset-0 z-[120] flex items-end justify-center" style={{ backgroundColor: "rgba(45,32,26,0.45)" }} onClick={close}>
      <div ref={dialog} role="dialog" aria-modal="true" aria-label="选择识别物品入库" onKeyDown={modalKey} onClick={(event) => event.stopPropagation()} className="w-full max-w-[430px] max-h-[85dvh] flex flex-col rounded-t-[28px] px-5 pt-4 pb-6" style={{ backgroundColor: WHITE }}>
        <div className="flex items-center justify-between gap-2 mb-3"><h2 style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>选择识别物品入库</h2><button autoFocus type="button" aria-label="关闭入库选择" onClick={close} className="h-10 w-10 shrink-0 rounded-full flex items-center justify-center" style={{ backgroundColor: LINEN }}><X size={17} color={COFFEE} /></button></div>
        <p style={{ color: COFFEE, opacity: 0.65, fontSize: 12, lineHeight: 1.7 }}>只加入你勾选的物品，已入库的不会重复添加；不会修改原扫描记录。</p>
        <div className="mt-3 min-h-0 overflow-y-auto space-y-2 pr-1">{candidates.map((item, index) => { const saved = storedIDs.has(item.id); return <label key={item.id} className="flex min-h-14 items-center gap-3 p-3 rounded-xl" style={{ backgroundColor: LINEN, opacity: saved ? 0.6 : 1 }}><input type="checkbox" disabled={saved} checked={saved || selectedIDs.includes(item.id)} aria-label={"入库" + item.name + "（" + (index + 1) + "）"} onChange={(event) => setChosen((values) => event.target.checked ? [...values, item.id] : values.filter((id) => id !== item.id))} className="h-4 w-4 shrink-0" style={{ accentColor: ORANGE }} /><div className="min-w-0 flex-1"><p className="break-words" style={{ color: COFFEE, fontSize: 13 }}>{item.name}</p><p className="break-words" style={{ color: COFFEE, opacity: 0.6, fontSize: 10 }}>{item.category}{item.sourceSpaceName ? " · " + item.sourceSpaceName : ""}{saved ? " · 已入库" : ""}</p></div>{saved && <Check size={15} color={COFFEE} />}</label>; })}</div>
        {!candidates.length && <p className="py-8 text-center" style={{ color: COFFEE, fontSize: 12 }}>还没有可入库的识别物品，请先完成照片识别。</p>}
        {error && <p role="alert" className="mt-3 rounded-xl p-3" style={{ backgroundColor: "#FFF0ED", color: "#B44740", fontSize: 12, lineHeight: 1.6 }}>{error}</p>}
        <button type="button" disabled={!selectedIDs.length} onClick={save} className="mt-4 min-h-12 w-full shrink-0 rounded-full py-3 disabled:opacity-40" style={{ backgroundColor: ORANGE, color: WHITE, fontSize: 13, fontWeight: 600 }}>保存到本机物品库（{selectedIDs.length}）</button>
        <p className="mt-2 text-center" style={{ color: COFFEE, opacity: 0.5, fontSize: 10 }}>本机保存，暂未同步云端</p>
      </div>
    </div>, document.body)}
  </div>;
}
