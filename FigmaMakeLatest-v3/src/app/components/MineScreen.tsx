import { useState } from "react";
import { ChevronRight, Settings, FolderKanban, Users, Bookmark, HelpCircle, LogOut, Lock, Play, GalleryVerticalEnd, LoaderCircle } from "lucide-react";
import profileAvatar from "../../assets/profile-avatar.png";
import { COFFEE, ORANGE, LINEN, WHITE, BLUE, SOFT } from "./theme";
import { SavedPostsScreen } from "./SavedPostsScreen";
import { FriendsScreen } from "./FriendsScreen";
import { BadgesScreen, badgesFromState } from "./BadgesScreen";
import { AISettingsScreen } from "./AISettingsScreen";
import type { NativeState } from "../nativeBridge";
import { plansFromState } from "../projectPlans";

export function MineScreen({ nativeState, onNativeChange, onOpenProjects, onPresentationModeChange, onBrowseFlow }: {
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
  onOpenProjects?: () => void;
  onPresentationModeChange?: (enabled: boolean) => Promise<void>;
  onBrowseFlow?: () => void;
} = {}) {
  const [openSaved, setOpenSaved] = useState(false);
  const [openFriends, setOpenFriends] = useState(false);
  const [openBadges, setOpenBadges] = useState(false);
  const [initialBadgeId, setInitialBadgeId] = useState<string | null>(null);
  const [openSettings, setOpenSettings] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [changingMode, setChangingMode] = useState(false);
  const isBrowserPreview = !nativeState && !window.webkit?.messageHandlers?.smartpaw;
  const isPresentationMode = nativeState?.isPresentationMode ?? isBrowserPreview;
  const badges = badgesFromState(nativeState);
  const earnedBadges = badges.filter((badge) => !badge.locked);
  const displayedBadges = earnedBadges.length ? earnedBadges : badges;
  const stats = [
    { label: "已追踪物品", value: isPresentationMode ? 248 : nativeState ? nativeState.profileStats?.trackedItemCount ?? nativeState.spaces.reduce((count, space) => count + space.detectedItems.length, 0) : 0 },
    { label: "已整理空间", value: isPresentationMode ? 12 : nativeState ? nativeState.profileStats?.organizedSpaceCount ?? nativeState.spaces.filter((space) => space.completedPlans.length > 0).length : 0 },
    { label: "已获得徽章", value: earnedBadges.length },
  ];

  const openBadge = (id: string | null) => {
    setInitialBadgeId(id);
    setOpenBadges(true);
  };

  const showNotice = (message: string) => {
    setNotice(message);
    window.setTimeout(() => setNotice((current) => current === message ? null : current), 1800);
  };

  const changeMode = async (enabled: boolean) => {
    if (enabled === isPresentationMode || changingMode || !onPresentationModeChange) return;
    setChangingMode(true);
    try { await onPresentationModeChange(enabled); }
    catch (cause) { showNotice(cause instanceof Error ? cause.message : "数据切换失败，请重试"); }
    finally { setChangingMode(false); }
  };

  if (openSaved) return <SavedPostsScreen nativeState={nativeState} onNativeChange={onNativeChange} onBack={() => setOpenSaved(false)} />;
  if (openFriends) return <FriendsScreen nativeState={nativeState} onNativeChange={onNativeChange} onBack={() => setOpenFriends(false)} />;
  if (openBadges) return <BadgesScreen nativeState={nativeState} initialBadgeId={initialBadgeId} onBack={() => setOpenBadges(false)} />;
  if (openSettings) return <AISettingsScreen onBack={() => setOpenSettings(false)} />;

  const menu: { icon: any; label: string; sub: string; onClick?: () => void }[] = [
    // The bottom tab is named “项目”, while the personal-page entry keeps the
    // Figma label “我的计划” and opens the same project/plan route.
    { icon: FolderKanban, label: "我的计划", sub: `${nativeState || isBrowserPreview ? plansFromState(nativeState).length : 0} 个计划`, onClick: onOpenProjects },
    { icon: Bookmark, label: "已保存帖子", sub: nativeState ? String(nativeState.favorites.length) : isBrowserPreview ? "24" : "0", onClick: () => setOpenSaved(true) },
    { icon: Users, label: "好友", sub: "邀请和分享", onClick: () => setOpenFriends(true) },
    { icon: Settings, label: "设置", sub: "云端识别与方案", onClick: () => setOpenSettings(true) },
    { icon: HelpCircle, label: "帮助与反馈", sub: "", onClick: () => showNotice("本地演示暂未接入帮助与反馈") },
    { icon: LogOut, label: "退出登录", sub: "", onClick: () => showNotice("本地版本未接入账号登录") },
  ];

  return (
    <div className="h-full w-full overflow-y-auto pb-32" style={{ backgroundColor: WHITE }}>
      <div className="px-6 pt-14 pb-6 flex flex-col items-center text-center">
        <div className="relative h-32 w-32 mb-4">
          <img src={profileAvatar} alt="Sarah 的浣熊头像" className="absolute -inset-2 h-36 w-36 max-w-none" />
        </div>
        <p style={{ color: COFFEE, fontSize: 22, fontWeight: 600 }}>Sarah Chen</p>
        <p style={{ color: COFFEE, opacity: 0.55, fontSize: 13, marginTop: 4 }}>
          @sarah · 于 2026 年 5 月加入
        </p>
        <span
          className="mt-3 px-3 py-1"
          style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, fontSize: 11 }}
        >
          4 级 · 整洁大师
        </span>
      </div>

      {/* Stats row */}
      <div className="px-6">
        {isPresentationMode && (
          <p className="text-center mb-2" style={{ color: COFFEE, opacity: 0.5, fontSize: 10 }}>样例数据</p>
        )}
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
          <button onClick={() => openBadge(null)} style={{ color: ORANGE, fontSize: 12 }}>
            查看全部
          </button>
        </div>
        <div className="overflow-x-auto">
          <div className="flex gap-3" style={{ width: "max-content" }}>
            {displayedBadges.map((b, i) => (
              <button
                key={b.id}
                aria-label={`${b.name}${b.locked ? "，尚未解锁" : "，已获得"}`}
                onClick={() => openBadge(b.id)}
                className="relative h-14 w-14 rounded-2xl flex items-center justify-center"
                style={{
                  backgroundColor: i === 0 && !b.locked ? ORANGE : LINEN,
                  fontSize: 24,
                  boxShadow: i === 0 && !b.locked ? "0 6px 16px rgba(250,136,58,0.3)" : "none",
                }}
              >
                <span style={{ filter: b.locked ? "grayscale(1)" : "none", opacity: b.locked ? 0.45 : 1 }}>{b.emoji}</span>
                {b.locked && <Lock size={12} color={COFFEE} className="absolute bottom-1 right-1" />}
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
        {onPresentationModeChange && (
          <div className="flex items-center gap-4 py-4" style={{ borderTop: `1px solid ${SOFT}` }}>
            <div className="h-10 w-10 rounded-xl flex items-center justify-center" style={{ backgroundColor: LINEN }}>
              {changingMode ? <LoaderCircle size={18} color={COFFEE} className="animate-spin" /> : <GalleryVerticalEnd size={18} color={COFFEE} />}
            </div>
            <p className="flex-1 text-left" style={{ color: COFFEE, fontSize: 14, fontWeight: 500 }}>展示数据</p>
            <div className="flex p-0.5 rounded-lg" role="group" aria-label="数据来源" style={{ backgroundColor: LINEN }}>
              {[{ label: "样例", enabled: true }, { label: "我的数据", enabled: false }].map((mode) => (
                <button
                  key={mode.label}
                  type="button"
                  aria-pressed={isPresentationMode === mode.enabled}
                  disabled={changingMode}
                  onClick={() => { void changeMode(mode.enabled); }}
                  className="px-3 py-2 rounded-md"
                  style={{ backgroundColor: isPresentationMode === mode.enabled ? WHITE : "transparent", color: COFFEE, fontSize: 11, fontWeight: isPresentationMode === mode.enabled ? 600 : 400, opacity: changingMode ? 0.6 : 1 }}
                >
                  {mode.label}
                </button>
              ))}
            </div>
          </div>
        )}
        {isPresentationMode && onBrowseFlow && (
          <button type="button" onClick={onBrowseFlow} className="w-full flex items-center gap-4 py-4" style={{ borderTop: `1px solid ${SOFT}` }}>
            <div className="h-10 w-10 rounded-xl flex items-center justify-center" style={{ backgroundColor: LINEN }}><Play size={18} color={COFFEE} /></div>
            <p className="flex-1 text-left" style={{ color: COFFEE, fontSize: 14, fontWeight: 500 }}>浏览整理流程</p>
            <ChevronRight size={18} color={COFFEE} opacity={0.4} />
          </button>
        )}
      </div>
      {notice && <div className="fixed bottom-24 left-1/2 -translate-x-1/2 z-50 px-4 py-2 rounded-full" style={{ backgroundColor: COFFEE, color: WHITE, fontSize: 12 }} role="status">{notice}</div>}
    </div>
  );
}
