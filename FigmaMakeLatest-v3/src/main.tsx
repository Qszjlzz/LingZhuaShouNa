import { createRoot } from "react-dom/client";
import App from "./app/App.tsx";
import "./styles/index.css";

// 键盘弹出时 WKWebView 不会自动把输入框顶到可见位置，
// 结果就是下半屏被键盘盖住、内容看起来整体上移。这里统一在聚焦后滚一次。
document.addEventListener(
  "focusin",
  () => {
    const active = document.activeElement as HTMLElement | null;
    if (!active || !active.isConnected) return;
    if (!/^(input|textarea|select)$/i.test(active.tagName)) return;
    window.setTimeout(() => {
      active.scrollIntoView({ block: "center", behavior: "smooth" });
    }, 300);
  },
  true,
);

// 键盘收起后把页面滚回顶部，避免残留偏移。
document.addEventListener(
  "focusout",
  () => {
    window.setTimeout(() => {
      const active = document.activeElement as HTMLElement | null;
      if (active && /^(input|textarea|select)$/i.test(active.tagName)) return;
      document.scrollingElement?.scrollTo({ top: 0 });
    }, 200);
  },
  true,
);

createRoot(document.getElementById("root")!).render(<App />);
