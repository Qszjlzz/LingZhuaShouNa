/**
 * 网页演示版降级桥接。
 *
 * 只做一件事：当页面不在 iOS App 里（没有 window.webkit.messageHandlers.smartpaw）时，
 * 装一个用浏览器能力实现的假桥，让界面上的功能都能点得动、拍得了照。
 *
 * 在 App 内（WKWebView）时这里什么都不做 —— 一切照旧走原生，真机拍摄不受任何影响。
 */

type Msg = { requestId: string; command: string; payload?: Record<string, unknown> };

declare global {
  interface Window {
    webkit?: { messageHandlers?: { smartpaw?: { postMessage: (m: unknown) => void } } };
    __smartPawReceive?: (response: unknown) => void;
  }
}

/** 把选中的图片压到 900px 宽的 jpeg dataURL，避免原图太大卡住界面。 */
function readImageAsDataURL(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error("读取图片失败"));
    reader.onload = () => {
      const img = new Image();
      img.onerror = () => reject(new Error("读取图片失败"));
      img.onload = () => {
        const max = 900;
        const scale = Math.min(1, max / Math.max(img.width, img.height));
        const canvas = document.createElement("canvas");
        canvas.width = Math.round(img.width * scale);
        canvas.height = Math.round(img.height * scale);
        const ctx = canvas.getContext("2d");
        if (!ctx) return reject(new Error("读取图片失败"));
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        resolve(canvas.toDataURL("image/jpeg", 0.82));
      };
      img.src = String(reader.result);
    };
    reader.readAsDataURL(file);
  });
}

/** 用浏览器的相机 / 相册选一张图。手机上会直接调起摄像头。 */
function pickPhoto(): Promise<string> {
  return new Promise((resolve, reject) => {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = "image/*";
    input.capture = "environment"; // 后置摄像头
    input.style.position = "fixed";
    input.style.left = "-9999px";
    let settled = false;
    const cleanup = () => input.remove();
    input.onchange = async () => {
      const file = input.files?.[0];
      if (!file) {
        settled = true;
        cleanup();
        reject(new Error("已取消"));
        return;
      }
      try {
        const url = await readImageAsDataURL(file);
        settled = true;
        cleanup();
        resolve(url);
      } catch (e) {
        settled = true;
        cleanup();
        reject(e instanceof Error ? e : new Error("读取图片失败"));
      }
    };
    // 用户关掉选择框（没有任何选择）时也算取消。
    input.addEventListener("cancel", () => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(new Error("已取消"));
    });
    document.body.appendChild(input);
    input.click();
  });
}

const emptyState = {
  spaces: [],
  selectedSpaceID: undefined,
  scannedItems: [],
  achievements: [],
  communityCases: [],
  comments: {},
  liked: [],
  favorites: [],
  followedAuthors: [],
  schedules: [],
  message: "网页演示版",
};

function installWebBridge() {
  if (window.webkit?.messageHandlers?.smartpaw) return; // App 内：不插手

  const reply = (m: Msg, data: unknown) => {
    window.__smartPawReceive?.({ requestId: m.requestId, status: "success", data });
  };
  const fail = (m: Msg, error: string) => {
    window.__smartPawReceive?.({ requestId: m.requestId, status: "error", error });
  };

  window.webkit = {
    messageHandlers: {
      smartpaw: {
        postMessage: (raw: unknown) => {
          const m = raw as Msg;
          const cmd = m.command;

          // 拍照：走浏览器摄像头 / 相册
          if (cmd === "camera.capture") {
            pickPhoto()
              .then((preview) => reply(m, { preview, state: emptyState }))
              .catch((e) => fail(m, e?.message ?? "已取消"));
            return;
          }
          // 取景：网页里没有实时画面，告诉页面"相机已就绪"，可以直接按快门
          if (cmd === "camera.preview.start" || cmd === "camera.preview.show") {
            return reply(m, { ok: true, reason: "" });
          }
          if (cmd === "state.get") return reply(m, emptyState);

          // 其余命令（方案生成、收藏、关注、日程、社区互动……）统一回成功，
          // 界面上各自的示例数据会照常显示。
          setTimeout(() => reply(m, { ok: true }), 20);
        },
      },
    },
  };
}

/** 桌面上打开时把界面框进一个手机尺寸的容器里，看起来跟真机一致。 */
function applyPhoneFrame() {
  if (window.innerWidth <= 520) return; // 手机浏览器：本来就是满屏
  const style = document.createElement("style");
  style.textContent = `
    html, body { background: #E8E0D6; }
    #root {
      width: 390px; height: 844px;
      max-height: calc(100vh - 48px);
      margin: 24px auto;
      overflow: hidden auto;
      border-radius: 28px;
      box-shadow: 0 24px 70px rgba(0,0,0,0.35);
      background: #F7F3EC;
      /* 让拍摄/筛选等 position:fixed 的全屏页也相对这个手机框定位，而不是铺满整个浏览器窗口 */
      transform: translateZ(0);
      position: relative;
    }
  `;
  document.head.appendChild(style);
}

installWebBridge();
applyPhoneFrame();
