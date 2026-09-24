import { useState } from "react";
import { ArrowLeft, Search, UserPlus, MessageCircle, Trophy, Flame } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { nativeRequest, type NativeState } from "../nativeBridge";

const avatarColors = ["#E8B894", "#B4D4C9", "#D9B4C7", "#A8B8CC", "#C9A687", "#E8D4B4"];

type Author = {
  name: string;
  initial: string;
  bg: string;
  cases: number;
  likes: number;
  following: boolean;
};

export function FriendsScreen({
  onBack,
  nativeState,
  onNativeChange,
}: {
  onBack: () => void;
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
}) {
  const [tab, setTab] = useState<"friends" | "leaderboard">("friends");
  const [keyword, setKeyword] = useState("");

  const followed = nativeState?.followedAuthors ?? [];
  const cases = nativeState?.communityCases ?? [];

  // 作者全部来自原生社区案例，关注关系来自原生 followedAuthors（会持久化）
  const authors: Author[] = Array.from(new Set(cases.map((c) => c.author))).map((name, index) => ({
    name,
    initial: String(name || "?").slice(0, 1),
    bg: avatarColors[index % avatarColors.length],
    cases: cases.filter((c) => c.author === name).length,
    likes: cases.filter((c) => c.author === name).reduce((sum, c) => sum + (c.likes ?? 0), 0),
    following: followed.includes(name),
  }));

  // 已关注的作者可能不在当前案例列表里，也要展示出来
  const extra: Author[] = followed
    .filter((name) => !authors.some((a) => a.name === name))
    .map((name, index) => ({
      name,
      initial: String(name || "?").slice(0, 1),
      bg: avatarColors[index % avatarColors.length],
      cases: 0,
      likes: 0,
      following: true,
    }));

  const all = [...authors, ...extra];
  const matched = keyword.trim()
    ? all.filter((a) => a.name.toLowerCase().includes(keyword.trim().toLowerCase()))
    : all;
  const followingList = matched.filter((a) => a.following);
  const suggested = matched.filter((a) => !a.following);
  const leaderboard = [...all].sort((a, b) => b.likes - a.likes).slice(0, 5);

  const toggleFollow = (name: string) => {
    void nativeRequest("community.follow", { author: name })
      .then(() => onNativeChange?.())
      .catch(() => undefined);
  };

  return (
    <div className="h-full w-full overflow-y-auto pb-10" style={{ backgroundColor: LINEN }}>
      <div className="px-6 pt-14 pb-2 flex items-center justify-between">
        <button
          onClick={onBack}
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ArrowLeft size={20} color={COFFEE} />
        </button>
        <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>好友</p>
        <button
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: ORANGE, boxShadow: "0 6px 16px rgba(250,136,58,0.3)" }}
        >
          <UserPlus size={18} color={WHITE} />
        </button>
      </div>

      {/* Search */}
      <div className="px-6 mt-4">
        <div
          className="flex items-center gap-3 px-5 py-3"
          style={{
            backgroundColor: WHITE,
            borderRadius: 20,
            boxShadow: "0 4px 16px rgba(123,92,72,0.04)",
          }}
        >
          <Search size={16} color={COFFEE} />
          <input
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            placeholder="搜索社区作者…"
            className="flex-1 bg-transparent outline-none"
            style={{ color: COFFEE, fontSize: 13 }}
          />
        </div>
      </div>

      {/* Tabs */}
      <div className="px-6 mt-5 flex gap-2">
        <button
          onClick={() => setTab("friends")}
          className="flex-1 py-2.5"
          style={{
            backgroundColor: tab === "friends" ? COFFEE : WHITE,
            color: tab === "friends" ? WHITE : COFFEE,
            borderRadius: 14,
            fontSize: 12,
            fontWeight: 600,
          }}
        >
          关注 · {followingList.length}
        </button>
        <button
          onClick={() => setTab("leaderboard")}
          className="flex-1 py-2.5"
          style={{
            backgroundColor: tab === "leaderboard" ? COFFEE : WHITE,
            color: tab === "leaderboard" ? WHITE : COFFEE,
            borderRadius: 14,
            fontSize: 12,
            fontWeight: 600,
          }}
        >
          热门榜
        </button>
      </div>

      {tab === "friends" ? (
        <>
          {/* Following */}
          <div className="px-6 mt-6 mb-3 flex items-center justify-between">
            <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>已关注 · {followingList.length}</p>
          </div>
          <div className="px-6 space-y-2">
            {followingList.length === 0 && (
              <div className="p-5 text-center" style={{ backgroundColor: WHITE, borderRadius: 18 }}>
                <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>
                  还没有关注作者，在社区详情页点关注即可同步
                </p>
              </div>
            )}
            {followingList.map((f) => (
              <AuthorRow key={f.name} author={f} onToggle={() => toggleFollow(f.name)} />
            ))}
          </div>

          {/* Suggested */}
          {suggested.length > 0 && (
            <>
              <div className="px-6 mt-7 mb-3">
                <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>推荐关注</p>
              </div>
              <div className="px-6 space-y-2">
                {suggested.map((f) => (
                  <AuthorRow key={f.name} author={f} onToggle={() => toggleFollow(f.name)} />
                ))}
              </div>
            </>
          )}
        </>
      ) : (
        <>
          <div className="px-6 mt-5 mb-3 flex items-center gap-2">
            <Trophy size={16} color={ORANGE} />
            <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>社区热门作者</p>
          </div>
          <div className="px-6 space-y-2">
            {leaderboard.length === 0 && (
              <div className="p-5 text-center" style={{ backgroundColor: WHITE, borderRadius: 18 }}>
                <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>暂无社区数据</p>
              </div>
            )}
            {leaderboard.map((l, index) => (
              <div
                key={l.name}
                className="flex items-center gap-3 p-3"
                style={{
                  backgroundColor: l.following ? ORANGE : WHITE,
                  borderRadius: 18,
                  boxShadow: "0 3px 12px rgba(123,92,72,0.04)",
                }}
              >
                <div
                  className="h-10 w-10 rounded-2xl flex items-center justify-center"
                  style={{
                    backgroundColor:
                      index === 0 ? "#FFD58A" : index === 1 ? "#D8DEE6" : index === 2 ? "#E8B894" : LINEN,
                    color: COFFEE,
                    fontSize: 15,
                    fontWeight: 600,
                  }}
                >
                  {index + 1}
                </div>
                <div
                  className="h-10 w-10 rounded-full flex items-center justify-center"
                  style={{
                    backgroundColor: l.following ? WHITE : l.bg,
                    color: l.following ? ORANGE : WHITE,
                    fontSize: 14,
                    fontWeight: 600,
                  }}
                >
                  {l.initial}
                </div>
                <p
                  className="flex-1"
                  style={{ color: l.following ? WHITE : COFFEE, fontSize: 13, fontWeight: 600 }}
                >
                  {l.name}
                </p>
                <span
                  className="flex items-center gap-1"
                  style={{
                    color: l.following ? WHITE : COFFEE,
                    opacity: l.following ? 0.9 : 0.65,
                    fontSize: 12,
                  }}
                >
                  <Flame size={11} /> {l.likes}
                </span>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

function AuthorRow({ author, onToggle }: { author: Author; onToggle: () => void }) {
  return (
    <div
      className="flex items-center gap-3 p-3"
      style={{
        backgroundColor: WHITE,
        borderRadius: 18,
        boxShadow: "0 3px 12px rgba(123,92,72,0.04)",
      }}
    >
      <div
        className="h-12 w-12 rounded-full flex items-center justify-center"
        style={{ backgroundColor: author.bg, color: WHITE, fontSize: 16, fontWeight: 600 }}
      >
        {author.initial}
      </div>
      <div className="flex-1 min-w-0">
        <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{author.name}</p>
        <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>
          {author.cases} 个方案 · 获赞 {author.likes}
        </p>
      </div>
      <button
        onClick={onToggle}
        className="h-9 w-9 rounded-full flex items-center justify-center"
        style={{ backgroundColor: author.following ? ORANGE : LINEN }}
        aria-label={author.following ? `取消关注${author.name}` : `关注${author.name}`}
      >
        {author.following ? (
          <MessageCircle size={15} color={WHITE} />
        ) : (
          <UserPlus size={15} color={COFFEE} />
        )}
      </button>
    </div>
  );
}
