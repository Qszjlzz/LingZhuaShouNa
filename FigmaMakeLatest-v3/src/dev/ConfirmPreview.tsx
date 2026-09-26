/**
 * 开发预览：在浏览器里单渲染「识别确认」页（ConfirmStep），
 * 用 mock 的 native bridge 返回示例识别结果，方便截图对照设计稿。
 * 访问 http://localhost:4173/?preview=confirm 即可看到，不影响 App 内主流程。
 */
import { useEffect, useState } from "react";
import { ConfirmStep, type CapturedAsset } from "../app/components/ShootFlow";

const DEMO_PHOTO =
  "https://images.unsplash.com/photo-1768548273848-ebab6f26b48c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080";

// —— mock 原生桥：让 nativeRequest 在浏览器里走通 ——
(window as unknown as { webkit?: unknown }).webkit = {
  messageHandlers: {
    smartpaw: {
      postMessage: (msg: { requestId: string; command: string }) => {
        const reply = (data: unknown) =>
          setTimeout(
            () =>
              (
                window as unknown as {
                  __smartPawReceive?: (r: unknown) => void;
                }
              ).__smartPawReceive?.({
                requestId: msg.requestId,
                status: "success",
                data,
              }),
            60,
          );
        if (msg.command === "scan.await") reply({});
        else if (msg.command === "items.save") reply({});
        else if (msg.command === "state.get")
          reply({
            scannedItems: [
              { id: "d1", name: "编程书", category: "书籍", confidence: 0.91, suggestedZone: "书架", isSelected: true },
              { id: "d2", name: "数据线", category: "电子产品", confidence: 0.88, suggestedZone: "充电站", isSelected: true },
              { id: "d3", name: "马克杯", category: "杯子", confidence: 0.84, suggestedZone: "厨房台面", isSelected: true },
              { id: "d4", name: "玩偶", category: "玩偶杂物", confidence: 0.42, suggestedZone: "收纳箱", isSelected: true },
              { id: "d5", name: "台灯", category: "电子产品", confidence: 0.79, suggestedZone: "充电站", isSelected: true },
            ],
            scanDiagnostics: { 通道: "本地 YOLO + 云端", 模型: "演示数据" },
          });
        else reply({});
      },
    },
  },
};

export default function ConfirmPreview() {
  const [assets] = useState<CapturedAsset[]>([
    { id: "a1", kind: "photo", src: DEMO_PHOTO, label: "照片 1" },
  ]);
  const [scale, setScale] = useState(1);

  useEffect(() => {
    const fit = () => setScale(Math.min(1, window.innerHeight / 844));
    fit();
    window.addEventListener("resize", fit);
    return () => window.removeEventListener("resize", fit);
  }, []);

  return (
    <div
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: "#2a2622",
        overflow: "hidden",
      }}
    >
      <div
        style={{
          width: 390,
          height: 844,
          transform: `scale(${scale})`,
          transformOrigin: "center center",
          borderRadius: 24,
          overflow: "hidden",
          boxShadow: "0 20px 60px rgba(0,0,0,0.5)",
          position: "relative",
        }}
      >
        <ConfirmStep assets={assets} onBack={() => {}} onNext={() => {}} />
      </div>
    </div>
  );
}
