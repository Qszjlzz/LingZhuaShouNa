import { useState } from "react";
import { ChevronRight, Settings, Calendar, Users, Bookmark, HelpCircle, LogOut } from "lucide-react";
import { Raccoon } from "./Raccoon";
import { COFFEE, ORANGE, LINEN, WHITE, BLUE, SOFT } from "./theme";
import { MyPlansScreen } from "./MyPlansScreen";
import { SavedPostsScreen } from "./SavedPostsScreen";
import { FriendsScreen } from "./FriendsScreen";
import { BadgesScreen } from "./BadgesScreen";

const stats = [
  { label: "已追踪物品", value: "248" },
  { label: "已整理空间", value: "12" },
  { label: "已获得徽章", value: "7" },
];

const badges = ["🦝", "✨", "🏆", "🌿", "📦", "🎯", "💎"];

export function MineScreen() {
  const [openPlans, setOpenPlans] = useState(false);
  const [openSaved, setOpenSaved] = useState(false);
  const [openFriends, setOpenFriends] = useState(false);
  const [openBadges, setOpenBadges] = useState(false);

  if (openPlans) return <MyPlansScreen onBack={() => setOpenPlans(false)} />;
  if (openSaved) return <SavedPostsScreen onBack={() => setOpenSaved(false)} />;
  if (openFriends) return <FriendsScreen onBack={() => setOpenFriends(false)} />;
  if (openBadges) return <BadgesScreen onBack={() => setOpenBadges(false)} />;

  const menu: { icon: any; label: string; sub: string; onClick?: () => void }[] = [
    { icon: Calendar, label: "我的方案", sub: "3个进行中", onClick: () => setOpenPlans(true) },
    { icon: Bookmark, label: "已保存帖子", sub: "24", onClick: () => setOpenSaved(true) },
    { icon: Users, label: "好友", sub: "邀请和分享", onClick: () => setOpenFriends(true) },
    { icon: Settings, label: "设置", sub: "" },
    { icon: HelpCircle, label: "帮助与反馈", sub: "" },
    { icon: LogOut, label: "退出登录", sub: "" },
  ];

  return (
    <div className="h-full w-full overflow-y-auto pb-32" style={{ backgroundColor: WHITE }}>
      <div className="px-6 pt-14 pb-6 flex flex-col items-center text-center">
        <div
          className="h-24 w-24 rounded-full flex items-center justify-center mb-4"
          style={{
            background: `radial-gradient(circle, ${LINEN} 0%, ${SOFT} 100%)`,
            boxShadow: `0 0 0 6px rgba(250,136,58,0.08)`,
          }}
        >
          <Raccoon size={76} />
        </div>
        <p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>Sarah Chen</p>
        <p style={{ color: COFFEE, opacity: 0.55, fontSize: 13, marginTop: 4 }}>
          @sarah · 加入于 2026年3月
        </p>
        <span
          className="mt-3 px-3 py-1"
          style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, fontSize: 11 }}
        >
          等级 4 · 整理大师
        </span>
      </div>

      {/* Stats row */}
      <div className="px-6">
        <div
          className="flex items-center justify-around py-5"
          style={{ borderTop: `1px solid ${SOFT}`, borderBottom: `1px solid ${SOFT}` }}
        >
          {stats.map((s, i) => (
            <div key={s.label} className="flex items-center">
              <div className="text-center px-2">
                <p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>{s.value}</p>
                <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginTop: 2 }}>{s.label}</p>
              </div>
              {i < stats.length - 1 && (
                <div className="w-px h-10" style={{ backgroundColor: SOFT }} />
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Badges */}
      <div className="px-6 mt-7">
        <div className="flex items-center justify-between mb-3">
          <p style={{ color: COFFEE, fontSize: 15, fontWeight: 600 }}>徽章</p>
          <button onClick={() => setOpenBadges(true)} style={{ color: ORANGE, fontSize: 12 }}>
            查看全部
          </button>
        </div>
        <div className="overflow-x-auto">
          <div className="flex gap-3" style={{ width: "max-content" }}>
            {badges.map((b, i) => (
              <button
                key={i}
                onClick={() => setOpenBadges(true)}
                className="h-14 w-14 rounded-2xl flex items-center justify-center"
                style={{
                  backgroundColor: i === 0 ? ORANGE : LINEN,
                  fontSize: 24,
                  boxShadow: i === 0 ? "0 6px 16px rgba(250,136,58,0.3)" : "none",
                }}
              >
                {b}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Menu */}
      <div className="px-6 mt-8">
        {menu.map((m, i) => {
          const Icon = m.icon;
          const last = i === menu.length - 1;
          return (
            <button
              key={m.label}
              onClick={m.onClick}
              className="w-full flex items-center gap-4 py-4"
              style={{ borderBottom: last ? "none" : `1px solid ${SOFT}` }}
            >
              <div
                className="h-10 w-10 rounded-xl flex items-center justify-center"
                style={{ backgroundColor: LINEN }}
              >
                <Icon size={18} color={COFFEE} />
              </div>
              <div className="flex-1 text-left">
                <p style={{ color: COFFEE, fontSize: 14, fontWeight: 500 }}>{m.label}</p>
                {m.sub && (
                  <p style={{ color: COFFEE, opacity: 0.5, fontSize: 11, marginTop: 1 }}>{m.sub}</p>
                )}
              </div>
              <ChevronRight size={18} color={COFFEE} opacity={0.4} />
            </button>
          );
        })}
      </div>
    </div>
  );
}
