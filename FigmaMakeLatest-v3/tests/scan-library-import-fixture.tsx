import { createRoot } from "react-dom/client";
import { useState } from "react";
import { ScanLibraryImport } from "../src/app/components/ScanLibraryImport";
import { ItemLibraryScreen } from "../src/app/components/ItemLibraryScreen";
import type { NativeItem, NativeState } from "../src/app/nativeBridge";
import "../src/styles/index.css";
const items: NativeItem[] = [{ id: "pen-a", name: "黑色笔", category: "文具", confidence: 1, suggestedZone: "笔筒", isSelected: true }, { id: "pen-b", name: "黑色笔", category: "文具", confidence: 1, suggestedZone: "笔筒", isSelected: true }, { id: "cup", name: "水杯", category: "饮品", confidence: 1, suggestedZone: "桌面", isSelected: false }];
function Fixture() {
  const [presentation, setPresentation] = useState(false);
  const [library, setLibrary] = useState(false);
  const visible = location.search.includes("empty") ? [] : items;
  const native: NativeState = { isPresentationMode: presentation, selectedSpaceID: "desk", scannedItems: visible, spaces: [{ id: "desk", name: "AI 测试桌面", subtitle: "测试数据", detectedItems: visible, completedPlans: [] }], achievements: [], communityCases: [], comments: {}, liked: [], favorites: [], followedAuthors: [], schedules: [] };
  if (library) return <div style={{ position: "fixed", inset: 0 }}><ItemLibraryScreen nativeState={native} onBack={() => setLibrary(false)} /></div>;
  return <main style={{ maxWidth: 430, padding: 20, margin: "0 auto", color: "#7B5C48" }}><h1 style={{ fontSize: 18, margin: "36px 0 20px" }}>识别物品入库 · 开发测试</h1><p style={{ marginBottom: 20 }}>AI 测试夹具；没有手机、云同步或真实拍摄。</p><ScanLibraryImport items={visible} sourceSpaceID="desk" sourceSpaceName="AI 测试桌面" isPresentationMode={presentation} /><button style={{ padding: 12, marginTop: 20 }} onClick={() => setLibrary(true)}>打开自由整理</button><button style={{ padding: 12 }} onClick={() => setPresentation(!presentation)}>切换为{presentation ? "个人" : "演示"}模式</button><p data-testid="fixture-mode">{presentation ? "演示" : "个人"}模式</p></main>;
}
createRoot(document.getElementById("root")!).render(<Fixture />);
