import { useState } from "react";
import { ArrowLeft, Search, UserPlus, MessageCircle, Trophy, Flame } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";

type Friend = {
  id: string;
  name: string;
  handle: string;
  initial: string;
  bg: string;
  level: number;
  spaces: number;
  streak: number;
  online?: boolean;
};

const friends: Friend[] = [
  { id: "f1", name: "Mira", handle: "@mira_organize", initial: "M", bg: "#E8B894", level: 12, spaces: 28, streak: 18, online: true },
  { id: "f2", name: "Lin Hua", handle: "@lin_kitchen", initial: "L", bg: "#B4D4C9", level: 8, spaces: 19, streak: 7, online: true },
  { id: "f3", name: "Anna Park", handle: "@anna_p", initial: "A", bg: "#D9B4C7", level: 10, spaces: 22, streak: 12 },
  { id: "f4", name: "Joon", handle: "@joon_zen", initial: "J", bg: "#A8B8CC", level: 15, spaces: 41, streak: 24 },
  { id: "f5", name: "Kai Chen", handle: "@kai", initial: "K", bg: "#C9A687", level: 5, spaces: 11, streak: 3 },
];

const requests = [
  { id: "r1", name: "Sara Wei", initial: "S", bg: "#E8D4B4", mutual: 4 },
  { id: "r2", name: "Daisy Lu", initial: "D", bg: "#D9B4C7", mutual: 2 },
];

const leaderboard = [
  { rank: 1, name: "Joon", initial: "J", bg: "#A8B8CC", value: "41 个空间" },
  { rank: 2, name: "Mira", initial: "M", bg: "#E8B894", value: "28 spaces" },
  { rank: 3, name: "我", initial: "S", bg: ORANGE, value: "12 个空间", you: true },
  { rank: 4, name: "Anna", initial: "A", bg: "#D9B4C7", value: "22 spaces" },
];

export function FriendsScreen({ onBack }: { onBack: () => void }) {
  const [tab, setTab] = useState<"friends" | "leaderboard">("friends");

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
            placeholder="搜索昵称或用户名…"
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
          Friends · {friends.length}
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
          Leaderboard
        </button>
      </div>

      {tab === "friends" ? (
        <>
          {/* Requests */}
          <div className="px-6 mt-6 mb-3 flex items-center justify-between">
            <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>
              Requests · {requests.length}
            </p>
          </div>
          <div className="px-6 space-y-2">
            {requests.map((r) => (
              <div
                key={r.id}
                className="flex items-center gap-3 p-3"
                style={{ backgroundColor: WHITE, borderRadius: 18 }}
              >
                <div
                  className="h-11 w-11 rounded-full flex items-center justify-center"
                  style={{ backgroundColor: r.bg, color: WHITE, fontSize: 15, fontWeight: 600 }}
                >
                  {r.initial}
                </div>
                <div className="flex-1 min-w-0">
                  <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{r.name}</p>
                  <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>
                    {r.mutual} mutual friends
                  </p>
                </div>
                <button
                  className="px-3 py-2"
                  style={{
                    backgroundColor: ORANGE,
                    color: WHITE,
                    borderRadius: 999,
                    fontSize: 11,
                    fontWeight: 600,
                  }}
                >
                  Accept
                </button>
                <button
                  className="px-3 py-2"
                  style={{
                    backgroundColor: LINEN,
                    color: COFFEE,
                    borderRadius: 999,
                    fontSize: 11,
                    fontWeight: 600,
                  }}
                >
                  Skip
                </button>
              </div>
            ))}
          </div>

          {/* Friends list */}
          <div className="px-6 mt-7 mb-3">
            <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>正在关注</p>
          </div>
          <div className="px-6 space-y-2">
            {friends.map((f) => (
              <div
                key={f.id}
                className="flex items-center gap-3 p-3"
                style={{
                  backgroundColor: WHITE,
                  borderRadius: 18,
                  boxShadow: "0 3px 12px rgba(123,92,72,0.04)",
                }}
              >
                <div className="relative">
                  <div
                    className="h-12 w-12 rounded-full flex items-center justify-center"
                    style={{ backgroundColor: f.bg, color: WHITE, fontSize: 16, fontWeight: 600 }}
                  >
                    {f.initial}
                  </div>
                  {f.online && (
                    <div
                      className="absolute bottom-0 right-0 h-3 w-3 rounded-full"
                      style={{ backgroundColor: "#7BB28F", border: `2px solid ${WHITE}` }}
                    />
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{f.name}</p>
                    <span
                      className="px-1.5 py-0.5"
                      style={{
                        backgroundColor: LINEN,
                        color: COFFEE,
                        borderRadius: 999,
                        fontSize: 9,
                        fontWeight: 600,
                      }}
                    >
                      Lv.{f.level}
                    </span>
                  </div>
                  <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>{f.handle}</p>
                  <div className="flex items-center gap-3 mt-1">
                    <span style={{ color: COFFEE, opacity: 0.6, fontSize: 10 }}>
                      {f.spaces} spaces
                    </span>
                    <span className="flex items-center gap-1" style={{ color: ORANGE, fontSize: 10 }}>
                      <Flame size={10} /> {f.streak}d
                    </span>
                  </div>
                </div>
                <button
                  className="h-9 w-9 rounded-full flex items-center justify-center"
                  style={{ backgroundColor: LINEN }}
                >
                  <MessageCircle size={15} color={COFFEE} />
                </button>
              </div>
            ))}
          </div>
        </>
      ) : (
        <>
          <div className="px-6 mt-5 mb-3 flex items-center gap-2">
            <Trophy size={16} color={ORANGE} />
            <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>本月热门</p>
          </div>
          <div className="px-6 space-y-2">
            {leaderboard.map((l) => (
              <div
                key={l.rank}
                className="flex items-center gap-3 p-3"
                style={{
                  backgroundColor: l.you ? ORANGE : WHITE,
                  borderRadius: 18,
                  boxShadow: "0 3px 12px rgba(123,92,72,0.04)",
                }}
              >
                <div
                  className="h-10 w-10 rounded-2xl flex items-center justify-center"
                  style={{
                    backgroundColor:
                      l.rank === 1
                        ? "#FFD58A"
                        : l.rank === 2
                        ? "#D8DEE6"
                        : l.rank === 3
                        ? "#E8B894"
                        : LINEN,
                    color: COFFEE,
                    fontSize: 15,
                    fontWeight: 600,
                  }}
                >
                  {l.rank}
                </div>
                <div
                  className="h-10 w-10 rounded-full flex items-center justify-center"
                  style={{
                    backgroundColor: l.you ? WHITE : l.bg,
                    color: l.you ? ORANGE : WHITE,
                    fontSize: 14,
                    fontWeight: 600,
                  }}
                >
                  {l.initial}
                </div>
                <p
                  className="flex-1"
                  style={{
                    color: l.you ? WHITE : COFFEE,
                    fontSize: 13,
                    fontWeight: 600,
                  }}
                >
                  {l.name}
                </p>
                <span
                  style={{
                    color: l.you ? WHITE : COFFEE,
                    opacity: l.you ? 0.9 : 0.65,
                    fontSize: 12,
                  }}
                >
                  {l.value}
                </span>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
