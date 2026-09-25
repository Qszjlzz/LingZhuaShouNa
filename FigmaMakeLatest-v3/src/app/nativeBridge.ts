export type NativeItem = {
  id: string; name: string; category: string; confidence: number;
  suggestedZone: string; isSelected: boolean;
};

export type NativeStep = { id: string; title: string; detail: string; zone: string; status: "pending" | "active" | "done" };
export type NativePlan = { id: string; style: string; timeBudget: number; summary: string; toolList: string[]; steps: NativeStep[] };
export type NativeSpace = { id: string; name: string; subtitle: string; detectedItems: NativeItem[]; activePlan?: NativePlan; completedPlans: NativePlan[] };
export type NativeState = {
  spaces: NativeSpace[]; selectedSpaceID?: string; scannedItems: NativeItem[];
  achievements: { id: string; title: string; subtitle: string; iconName: string }[];
  communityCases: any[]; comments: Record<string, any[]>; liked: string[]; favorites: string[];
  followedAuthors: string[]; schedules: any[]; message?: string;
};

type NativeResponse<T = unknown> = { requestId: string; status: "success" | "error" | "cancelled"; data?: T; error?: string };
type Pending = { resolve: (value: any) => void; reject: (reason: Error) => void; timer: number };
const pending = new Map<string, Pending>();

declare global {
  interface Window {
    webkit?: { messageHandlers?: { smartpaw?: { postMessage: (message: unknown) => void } } };
    __smartPawReceive?: (response: NativeResponse) => void;
  }
}

window.__smartPawReceive = (response) => {
  const request = pending.get(response.requestId);
  if (!request) return;
  window.clearTimeout(request.timer);
  pending.delete(response.requestId);
  if (response.status === "success") request.resolve(response.data);
  else request.reject(new Error(response.status === "cancelled" ? "已取消" : response.error || "原生操作失败"));
};

export function nativeRequest<T = unknown>(command: string, payload: Record<string, unknown> = {}): Promise<T> {
  const handler = window.webkit?.messageHandlers?.smartpaw;
  if (!handler) return Promise.reject(new Error("当前环境没有连接原生功能"));
  const requestId = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  return new Promise<T>((resolve, reject) => {
    const timer = window.setTimeout(() => {
      pending.delete(requestId);
      reject(new Error("原生操作超时，请重试"));
    }, command === "capture.open" ? 180000 : 60000);
    pending.set(requestId, { resolve, reject, timer });
    handler.postMessage({ requestId, command, payload });
  });
}

export async function getNativeState(): Promise<NativeState> {
  return nativeRequest<NativeState>("state.get");
}
