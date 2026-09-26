import { createRoot } from "react-dom/client";
import App from "./app/App.tsx";
import "./styles/index.css";

// 开发预览入口：?preview=confirm 单独渲染「识别确认」页，供截图对照设计稿，App 内不受影响。
if (new URLSearchParams(window.location.search).get("preview") === "confirm") {
  import("./dev/ConfirmPreview.tsx").then(({ default: ConfirmPreview }) => {
    createRoot(document.getElementById("root")!).render(<ConfirmPreview />);
  });
} else {
  boot();
}

function boot() {

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

createRoot(document.getElementById("root")!).render(<App />);
}
