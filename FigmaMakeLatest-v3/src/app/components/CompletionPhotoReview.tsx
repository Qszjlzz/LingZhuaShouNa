import { useEffect, useRef, useState } from "react";
import { CheckCircle2, RotateCcw, X } from "lucide-react";
import { nativeRequest, type NativeState } from "../nativeBridge";
import { COFFEE, LINEN, ORANGE, WHITE } from "./theme";

export function useCompletionPhoto(onCommitted: (state: NativeState) => void) {
  const [preview, setPreview] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const spaceID = useRef<string | null>(null);
  const busyRef = useRef(false);
  const mounted = useRef(true);
  const enterBusy = () => {
    if (busyRef.current) return false;
    busyRef.current = true;
    if (mounted.current) setBusy(true);
    return true;
  };
  const leaveBusy = () => {
    busyRef.current = false;
    if (mounted.current) setBusy(false);
  };

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      void nativeRequest("capture.after.cancel").catch(() => undefined);
    };
  }, []);

  const choose = async (id: string) => {
    if (!enterBusy()) return;
    setError("");
    spaceID.current = id;
    try {
      await nativeRequest<NativeState>("space.select", { id });
      if (!mounted.current) return;
      const result = await nativeRequest<{ preview?: string }>("capture.open", { purpose: "after-preview", source: "photo" });
      if (!mounted.current) {
        await nativeRequest("capture.after.cancel");
        return;
      }
      if (!result.preview) throw new Error("没有读取到照片，请重新选择");
      if (mounted.current) setPreview(result.preview);
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : "完成照选择失败，请重试。";
      if (mounted.current && message !== "已取消") setError(message);
    } finally { leaveBusy(); }
  };

  const discard = async () => {
    if (!enterBusy()) return;
    setError("");
    try {
      await nativeRequest("capture.after.cancel");
      if (mounted.current) setPreview(null);
    } catch (cause) {
      if (mounted.current) setError(cause instanceof Error ? cause.message : "暂时无法取消，请重试。");
    } finally { leaveBusy(); }
  };

  const reselect = async () => {
    const id = spaceID.current;
    if (!id || !enterBusy()) return;
    setError("");
    try {
      await nativeRequest("capture.after.cancel");
      if (mounted.current) setPreview(null);
    } catch (cause) {
      if (mounted.current) setError(cause instanceof Error ? cause.message : "暂时无法重新选择，请重试。");
      leaveBusy();
      return;
    }
    leaveBusy();
    if (mounted.current) await choose(id);
  };

  const commit = async () => {
    const id = spaceID.current;
    if (!id || !enterBusy()) return;
    setError("");
    try {
      await nativeRequest<NativeState>("space.select", { id });
      if (!mounted.current) return;
      const state = await nativeRequest<NativeState>("capture.after.commit");
      if (!mounted.current) return;
      setPreview(null);
      onCommitted(state);
    } catch (cause) {
      if (mounted.current) setError(cause instanceof Error ? cause.message : "完成照保存失败，请重试。");
    } finally { leaveBusy(); }
  };

  return { preview, busy, error, choose, discard, reselect, commit };
}

export function CompletionPhotoReview({
  preview,
  busy,
  error,
  onLater,
  onReselect,
  onCommit,
}: {
  preview: string | null;
  busy: boolean;
  error: string;
  onLater: () => void;
  onReselect: () => void;
  onCommit: () => void;
}) {
  if (!preview) return null;
  return <div className="fixed inset-0 z-[100] flex items-center justify-center p-5" role="dialog" aria-modal="true" aria-label="确认完成照" style={{ backgroundColor: "rgba(30,20,15,0.58)" }}>
    <section className="w-full max-w-sm overflow-hidden rounded-[28px]" style={{ backgroundColor: LINEN, boxShadow: "0 20px 60px rgba(30,20,15,0.25)" }}>
      <header className="flex items-center justify-between px-5 py-4">
        <div><p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>整理后的照片</p><p className="mt-1" style={{ color: COFFEE, opacity: 0.6, fontSize: 12 }}>确认后才会归档这次整理</p></div>
        <button type="button" onClick={onLater} disabled={busy} aria-label="稍后完成" className="h-10 w-10 rounded-full flex items-center justify-center disabled:opacity-40" style={{ backgroundColor: WHITE, color: COFFEE }}><X size={18} /></button>
      </header>
      <img src={preview} alt="完成照预览" className="mx-5 w-[calc(100%-40px)] h-64 rounded-2xl object-cover" />
      {error && <p role="alert" className="px-5 pt-3" style={{ color: "#9A4230", fontSize: 12 }}>{error}</p>}
      <div className="p-5 flex gap-3">
        <button type="button" onClick={onReselect} disabled={busy} className="h-12 flex-1 rounded-full flex items-center justify-center gap-2 disabled:opacity-40" style={{ backgroundColor: WHITE, color: COFFEE, fontSize: 13, fontWeight: 600 }}><RotateCcw size={15} />重新选择</button>
        <button type="button" onClick={onCommit} disabled={busy} className="h-12 flex-1 rounded-full flex items-center justify-center gap-2 disabled:opacity-50" style={{ backgroundColor: ORANGE, color: WHITE, fontSize: 13, fontWeight: 600, boxShadow: "0 6px 18px rgba(250,136,58,0.28)" }}><CheckCircle2 size={16} />{busy ? "保存中…" : "确认并保存"}</button>
      </div>
    </section>
  </div>;
}
