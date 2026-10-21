import { useState } from "react";
import { Bookmark, ChevronDown, ChevronUp, FolderHeart } from "lucide-react";
import type { NativeState } from "../nativeBridge";
import { COFFEE, ORANGE, SOFT, WHITE } from "./theme";

type LocalItem = { id?: string; name: string; category?: string; suggestedZone?: string };
export type LocalCase = { id: string; title: string; tags: string[]; durationText?: string; items: LocalItem[] };
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function localCasesFromState(state?: NativeState | null): LocalCase[] {
  return (state?.communityCases ?? []).filter((item) =>
    typeof item?.id === "string" && UUID_PATTERN.test(item.id) && typeof item.title === "string"
  ).map((item) => ({
    id: item.id,
    title: item.title,
    tags: Array.isArray(item.tags) ? item.tags.filter((tag: unknown) => typeof tag === "string") : [],
    durationText: typeof item.durationText === "string" ? item.durationText : undefined,
    items: Array.isArray(item.items) ? item.items.filter((value: any) => typeof value?.name === "string") : [],
  }));
}

export function matchesLocalCase(item: LocalCase, keyword: string): boolean {
  return `${item.title} ${item.tags.join(" ")} ${item.items.map((value) => value.name).join(" ")}`.toLowerCase().includes(keyword);
}

export function LocalCaseCard({ item, saved, pending, onToggleSave }: {
  item: LocalCase; saved: boolean; pending?: boolean; onToggleSave?: () => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const detailsID = `local-case-${item.id}`;
  return (
    <article className="p-5" style={{ backgroundColor: WHITE, borderRadius: 22, boxShadow: "0 4px 18px rgba(123,92,72,0.04)" }}>
      <div className="flex items-start gap-3">
        <div className="h-11 w-11 shrink-0 rounded-2xl flex items-center justify-center" style={{ backgroundColor: SOFT }}>
          <FolderHeart size={21} color={COFFEE} />
        </div>
        <div className="flex-1 min-w-0">
          <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600, lineHeight: 1.5 }}>{item.title}</p>
          <p className="mt-1" style={{ color: COFFEE, opacity: 0.6, fontSize: 11 }}>本地记录 · {item.items.length} 件物品{item.durationText ? ` · ${item.durationText}` : ""}</p>
        </div>
        {onToggleSave ? (
          <button type="button" onClick={onToggleSave} disabled={pending} aria-label={saved ? "取消收藏本地记录" : "收藏本地记录"} aria-pressed={saved}
            className="h-11 w-11 shrink-0 rounded-full flex items-center justify-center disabled:opacity-40" style={{ backgroundColor: saved ? "#FFF0E3" : SOFT }}>
            <Bookmark size={19} color={saved ? ORANGE : COFFEE} fill={saved ? ORANGE : "none"} />
          </button>
        ) : <Bookmark size={17} color={ORANGE} fill={ORANGE} className="mt-3 shrink-0" aria-label="已收藏" />}
      </div>
      {item.tags.length > 0 && <div className="flex flex-wrap gap-2 mt-3">{item.tags.map((tag, index) => <span key={`${tag}-${index}`} className="px-2.5 py-1 rounded-full" style={{ backgroundColor: SOFT, color: COFFEE, fontSize: 11 }}>{tag}</span>)}</div>}
      <button type="button" onClick={() => setExpanded(!expanded)} aria-expanded={expanded} aria-controls={detailsID}
        className="w-full flex justify-between items-center pt-4" style={{ color: COFFEE, fontSize: 12 }}>
        {expanded ? "收起物品清单" : "查看物品清单"}{expanded ? <ChevronUp size={17} /> : <ChevronDown size={17} />}
      </button>
      {expanded && <div id={detailsID} className="mt-3 pt-3" style={{ borderTop: `1px solid ${SOFT}` }}>
        {item.items.length === 0 ? <p style={{ color: COFFEE, opacity: 0.65, fontSize: 12 }}>这条本地记录没有保存物品清单。</p> :
          <ul className="space-y-3">{item.items.map((value, index) => <li key={value.id || index} className="flex justify-between gap-3" style={{ color: COFFEE, fontSize: 12 }}>
            <span>{value.name}</span><span style={{ opacity: 0.6, textAlign: "right" }}>{value.suggestedZone || value.category || ""}</span>
          </li>)}</ul>}
      </div>}
    </article>
  );
}
