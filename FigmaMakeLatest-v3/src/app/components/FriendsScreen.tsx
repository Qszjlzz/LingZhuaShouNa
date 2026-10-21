import { useState } from "react";
import { ArrowLeft, Search, UserPlus, UserMinus } from "lucide-react";
import { COFFEE, ORANGE, LINEN, WHITE } from "./theme";
import { nativeRequest, type NativeState } from "../nativeBridge";

export function FriendsScreen({ onBack, nativeState, onNativeChange }: {
  onBack: () => void;
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
}) {
  const [query, setQuery] = useState("");
  const [newAuthor, setNewAuthor] = useState("");
  const [adding, setAdding] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const authors = (nativeState?.followedAuthors ?? []).filter((name) => name.toLowerCase().includes(query.trim().toLowerCase()));

  const toggleFollow = async (author: string) => {
    if (pending) return;
    setPending(true);
    setError(null);
    try {
      await nativeRequest("community.follow", { author });
      onNativeChange?.();
      setAdding(false);
      setNewAuthor("");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "关注操作失败，请重试");
    } finally {
      setPending(false);
    }
  };

  return <div className="h-full w-full overflow-y-auto pb-32" style={{ backgroundColor: LINEN }}>
    <div className="px-6 pt-14 pb-2 flex items-center justify-between">
      <button onClick={onBack} aria-label="返回个人主页" className="h-11 w-11 rounded-full flex items-center justify-center" style={{ backgroundColor: WHITE }}><ArrowLeft size={20} color={COFFEE} /></button>
      <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>正在关注</p>
      <button onClick={() => setAdding((value) => !value)} aria-label="关注作者" className="h-11 w-11 rounded-full flex items-center justify-center" style={{ backgroundColor: ORANGE, boxShadow: "0 6px 16px rgba(250,136,58,0.3)" }}><UserPlus size={18} color={WHITE} /></button>
    </div>

    <div className="px-6 mt-4"><div className="flex items-center gap-3 px-5 py-3" style={{ backgroundColor: WHITE, borderRadius: 20, boxShadow: "0 4px 16px rgba(123,92,72,0.04)" }}><Search size={16} color={COFFEE} /><input placeholder="搜索关注的作者…" className="flex-1 min-w-0 bg-transparent outline-none" style={{ color: COFFEE, fontSize: 13 }} value={query} onChange={(event) => setQuery(event.target.value)} /></div></div>

    {adding && <div className="px-6 mt-4"><div className="p-4" style={{ backgroundColor: WHITE, borderRadius: 18 }}>
      <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>关注作者</p>
      <div className="flex gap-2 mt-3"><input value={newAuthor} onChange={(event) => setNewAuthor(event.target.value)} placeholder="输入作者名称" className="flex-1 min-w-0 px-3 py-2 outline-none" style={{ backgroundColor: LINEN, borderRadius: 12, color: COFFEE, fontSize: 13 }} /><button disabled={!newAuthor.trim() || newAuthor.trim() === "我" || pending || (nativeState?.followedAuthors ?? []).includes(newAuthor.trim())} onClick={() => void toggleFollow(newAuthor.trim())} className="px-4 disabled:opacity-50" style={{ backgroundColor: ORANGE, borderRadius: 12, color: WHITE, fontSize: 12 }}>关注</button></div>
    </div></div>}

    {error && <p role="alert" className="mx-6 mt-4 text-xs" style={{ color: "#B44740" }}>{error}</p>}
    <div className="px-6 mt-6 mb-3 flex items-center justify-between"><p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>关注列表</p><span style={{ color: COFFEE, opacity: 0.55, fontSize: 12 }}>{nativeState?.followedAuthors.length ?? 0}</span></div>
    <div className="px-6 space-y-2">
      {authors.map((author) => <div key={author} className="flex items-center gap-3 p-3" style={{ backgroundColor: WHITE, borderRadius: 18, boxShadow: "0 3px 12px rgba(123,92,72,0.04)" }}>
        <div className="h-12 w-12 rounded-full flex items-center justify-center" style={{ backgroundColor: "#B4D4C9", color: COFFEE, fontSize: 16, fontWeight: 600 }}>{author.slice(0, 1).toUpperCase()}</div>
        <div className="flex-1 min-w-0"><p className="truncate" style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{author}</p><p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>已关注</p></div>
        <button onClick={() => void toggleFollow(author)} disabled={pending} aria-label={`取消关注${author}`} className="h-9 w-9 rounded-full flex items-center justify-center disabled:opacity-50" style={{ backgroundColor: LINEN }}><UserMinus size={16} color={COFFEE} /></button>
      </div>)}
      {authors.length === 0 && <p className="py-10 text-center" style={{ color: COFFEE, opacity: 0.6, fontSize: 13 }}>{query ? "没有匹配的作者" : "还没有关注的作者"}</p>}
    </div>
  </div>;
}
