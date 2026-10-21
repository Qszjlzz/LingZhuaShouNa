import { useState } from "react";
import { ArrowLeft, Bookmark, Search } from "lucide-react";
import { COFFEE, ORANGE, LINEN, WHITE } from "./theme";
import { LocalCaseCard, localCasesFromState, matchesLocalCase } from "./LocalCaseCard";
import { nativeRequest, type NativeState } from "../nativeBridge";

export function SavedPostsScreen({ onBack, nativeState, onNativeChange }: {
  onBack: () => void;
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
}) {
  const [query, setQuery] = useState("");
  const [searching, setSearching] = useState(false);
  const [pendingID, setPendingID] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const favorites = new Set(nativeState?.favorites ?? []);
  const saved = localCasesFromState(nativeState).filter((item) => favorites.has(item.id));
  const filtered = saved.filter((item) => matchesLocalCase(item, query.trim().toLowerCase()));

  const unsave = async (id: string) => {
    setPendingID(id);
    setError(null);
    try {
      await nativeRequest("community.favorite", { id });
      onNativeChange?.();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "取消收藏失败，请重试");
    } finally {
      setPendingID(null);
    }
  };

  return <div className="h-full w-full overflow-y-auto pb-32" style={{ backgroundColor: LINEN }}>
    <div className="px-6 pt-14 pb-2 flex items-center justify-between">
      <button onClick={onBack} aria-label="返回个人主页" className="h-11 w-11 rounded-full flex items-center justify-center" style={{ backgroundColor: WHITE }}><ArrowLeft size={20} color={COFFEE} /></button>
      <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>已保存</p>
      <button type="button" aria-label={searching ? "关闭搜索" : "搜索已保存内容"} onClick={() => { setSearching((value) => !value); setQuery(""); }} className="h-11 w-11 rounded-full flex items-center justify-center" style={{ backgroundColor: WHITE }}><Search size={18} color={COFFEE} /></button>
    </div>
    {searching && <div className="px-6 mt-3"><input autoFocus value={query} onChange={(event) => setQuery(event.target.value)} placeholder="搜索已保存内容…" className="w-full px-4 py-3 outline-none" style={{ backgroundColor: WHITE, color: COFFEE, borderRadius: 16, fontSize: 13 }} /></div>}
    <div className="px-6 mt-4"><div className="p-5 flex items-center gap-4" style={{ backgroundColor: WHITE, borderRadius: 22, boxShadow: "0 4px 18px rgba(123,92,72,0.06)" }}>
      <div className="h-14 w-14 rounded-2xl flex items-center justify-center" style={{ backgroundColor: ORANGE, boxShadow: "0 6px 16px rgba(250,136,58,0.3)" }}><Bookmark size={22} color={WHITE} fill={WHITE} /></div>
      <div className="flex-1"><p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>{saved.length} 条收藏</p><p style={{ color: COFFEE, opacity: 0.55, fontSize: 12 }}>本机保存的整理记录</p></div>
    </div></div>
    {error && <p role="alert" className="mx-6 mt-4 text-xs" style={{ color: "#B44740" }}>{error}</p>}
    <div className="px-6 mt-6 mb-3"><p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>收藏记录</p></div>
    <div className="px-6 space-y-3">
      {filtered.map((item) => <LocalCaseCard key={item.id} item={item} saved pending={pendingID === item.id} onToggleSave={() => void unsave(item.id)} />)}
      {filtered.length === 0 && <p className="py-10 text-center" style={{ color: COFFEE, opacity: 0.6, fontSize: 13 }}>{query ? "没有匹配的收藏记录" : "还没有收藏的整理记录"}</p>}
    </div>
  </div>;
}
