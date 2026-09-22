import { useEffect, useState } from "react";
import { ChevronRight, Settings, Calendar, Users, Bookmark, HelpCircle, LogOut } from "lucide-react";
import { Raccoon } from "./Raccoon";
import { COFFEE, ORANGE, LINEN, WHITE, BLUE, SOFT } from "./theme";
import { MyPlansScreen } from "./MyPlansScreen";
import { SavedPostsScreen } from "./SavedPostsScreen";
import { FriendsScreen } from "./FriendsScreen";
import { BadgesScreen } from "./BadgesScreen";
import type { NativeState } from "../nativeBridge";
import { nativeRequest } from "../nativeBridge";

const stats = [
  { label: "已追踪物品", value: "248" },
  { label: "已整理空间", value: "12" },
  { label: "已获得徽章", value: "7" },
];

const badges = ["🦝", "✨", "🏆", "🌿", "📦", "🎯", "💎"];

// 与 BadgesScreen 相同的 SF Symbol → 图形映射
const iconEmoji: Record<string, string> = {
  "camera.viewfinder": "📷",
  "photo.on.rectangle.angled": "🖼️",
  "square.on.square": "🧩",
  tag: "🏷️",
  timer: "⏱️",
  sparkles: "✨",
  flame: "🔥",
  leaf: "🌿",
  "cube.box": "📦",
  target: "🎯",
  "checkmark.seal": "🏅",
  trophy: "🏆",
};

export function MineScreen({ nativeState, onNativeChange }: { nativeState?: NativeState | null; onNativeChange?: () => void }) {
  const [openPlans, setOpenPlans] = useState(false);
  const [openSaved, setOpenSaved] = useState(false);
  const [openFriends, setOpenFriends] = useState(false);
  const [openBadges, setOpenBadges] = useState(false);
  const [openSettings, setOpenSettings] = useState(false);
  const [endpoint, setEndpoint] = useState("https://api.openai.com/v1/responses");
  const [model, setModel] = useState("gpt-4.1-mini");
  const [apiKey, setApiKey] = useState("");
  const [settingsMessage, setSettingsMessage] = useState("");
  const [settingsLoading, setSettingsLoading] = useState(false);

  useEffect(() => {
    if (!openSettings) return;
    setSettingsLoading(true);
    nativeRequest<{ isEnabled: boolean; endpoint: string; model: string; hasAPIKey: boolean }>("llm.settings.get")
      .then((settings) => {
        setEndpoint(settings.endpoint);
        setModel(settings.model);
        setApiKey("");
        setSettingsMessage(settings.hasAPIKey ? "已读取设备中的 API Key" : "尚未配置 API Key");
      })
      .catch((error) => setSettingsMessage(error instanceof Error ? error.message : "无法读取 AI 设置"))
      .finally(() => setSettingsLoading(false));
  }, [openSettings]);

  if (openPlans) return <MyPlansScreen nativeState={nativeState} onNativeChange={onNativeChange} onBack={() => setOpenPlans(false)} />;
  if (openSaved) return <SavedPostsScreen nativeState={nativeState} onNativeChange={onNativeChange} onBack={() => setOpenSaved(false)} />;
  if (openFriends) return <FriendsScreen nativeState={nativeState} onNativeChange={onNativeChange} onBack={() => setOpenFriends(false)} />;
  if (openBadges) return <BadgesScreen nativeState={nativeState} onBack={() => setOpenBadges(false)} />;
  if (openSettings) return <div className="h-full w-full overflow-y-auto px-6 pt-14 pb-32" style={{ backgroundColor: WHITE }}>
    <button onClick={() => setOpenSettings(false)} style={{ color: ORANGE, fontSize: 13 }}>返回</button>
    <h1 style={{ color: COFFEE, fontSize: 24, fontWeight: 700, marginTop: 18 }}>AI 设置</h1>
    <p style={{ color: COFFEE, opacity: 0.55, fontSize: 12, marginTop: 6 }}>用于整理方案和聊天。API Key 只保存在设备钥匙串。</p>
    <label style={{ display: "block", color: COFFEE, fontSize: 12, marginTop: 26 }}>Endpoint</label>
    <input value={endpoint} onChange={(e) => setEndpoint(e.target.value)} className="w-full mt-2 px-3 py-3 outline-none" style={{ backgroundColor: LINEN, borderRadius: 12, color: COFFEE }} />
    <label style={{ display: "block", color: COFFEE, fontSize: 12, marginTop: 16 }}>Model</label>
    <input value={model} onChange={(e) => setModel(e.target.value)} className="w-full mt-2 px-3 py-3 outline-none" style={{ backgroundColor: LINEN, borderRadius: 12, color: COFFEE }} />
    <label style={{ display: "block", color: COFFEE, fontSize: 12, marginTop: 16 }}>API Key</label>
    <input value={apiKey} onChange={(e) => setApiKey(e.target.value)} type="password" placeholder="输入后保存，留空则沿用已保存 Key" className="w-full mt-2 px-3 py-3 outline-none" style={{ backgroundColor: LINEN, borderRadius: 12, color: COFFEE }} />
    <div className="flex gap-2 mt-6">
      <button disabled={settingsLoading} onClick={async () => {
        setSettingsLoading(true);
        try {
          const result = await nativeRequest<{ state: string }>("llm.test", { endpoint, model, apiKey: apiKey || undefined });
          setSettingsMessage(result.state);
        } catch (error) {
          setSettingsMessage(error instanceof Error ? error.message : "连接测试失败");
        } finally { setSettingsLoading(false); }
      }} className="flex-1 py-3" style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, opacity: settingsLoading ? 0.6 : 1 }}>测试连接</button>
      <button disabled={settingsLoading} onClick={async () => {
        setSettingsLoading(true);
        try {
          await nativeRequest("llm.settings.save", { isEnabled: true, endpoint, model, apiKey: apiKey || undefined });
          setSettingsMessage("已保存，聊天和整理方案会使用这套配置");
        } catch (error) {
          setSettingsMessage(error instanceof Error ? error.message : "保存失败");
        } finally { setSettingsLoading(false); }
      }} className="flex-1 py-3" style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, opacity: settingsLoading ? 0.6 : 1 }}>保存</button>
    </div>
    {settingsMessage && <p style={{ color: COFFEE, fontSize: 12, marginTop: 14 }}>{settingsMessage}</p>}
  </div>;

  const liveStats = [
    { label: "已追踪物品", value: String(nativeState?.spaces.reduce((sum, space) => sum + space.detectedItems.length, 0) ?? 0) },
    { label: "已整理空间", value: String(nativeState?.spaces.filter((space) => space.completedPlans.length > 0).length ?? 0) },
    { label: "已获得徽章", value: String(nativeState?.achievements.length ?? 0) },
  ];
  const badgeEmojis = (nativeState?.achievements ?? []).map(
    (achievement) => iconEmoji[achievement.iconName] ?? "🎖️"
  );
  const activePlans = nativeState?.spaces.filter((space) => space.activePlan).length ?? 0;
  const menu: { icon: any; label: string; sub: string; onClick?: () => void }[] = [
    { icon: Calendar, label: "我的方案", sub: `${activePlans}个进行中`, onClick: () => setOpenPlans(true) },
    { icon: Bookmark, label: "已保存帖子", sub: String(nativeState?.favorites.length ?? 0), onClick: () => setOpenSaved(true) },
    { icon: Users, label: "好友", sub: "邀请和分享", onClick: () => setOpenFriends(true) },
    { icon: Settings, label: "设置", sub: "AI 与应用设置", onClick: () => setOpenSettings(true) },
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
        <p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>小爪用户</p>
        <p style={{ color: COFFEE, opacity: 0.55, fontSize: 13, marginTop: 4 }}>
          本地账户 · 数据保存在这台设备
        </p>
        <span
          className="mt-3 px-3 py-1"
          style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, fontSize: 11 }}
        >
          已解锁 {nativeState?.achievements.length ?? 0} 枚徽章
        </span>
      </div>

      {/* Stats row */}
      <div className="px-6">
        <div
          className="flex items-center justify-around py-5"
          style={{ borderTop: `1px solid ${SOFT}`, borderBottom: `1px solid ${SOFT}` }}
        >
          {liveStats.map((s, i) => (
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
            {badgeEmojis.map((b, i) => (
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
