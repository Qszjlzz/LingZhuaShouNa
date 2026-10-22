export type CameraPreviewStartResult = { ok: boolean; reason?: string };

/** Retries native preview startup only while the owning capture screen is mounted. */
export async function startCameraPreviewWithRetry(options: {
  isActive: () => boolean;
  start: () => Promise<CameraPreviewStartResult>;
  stop: () => void;
  sleep?: (milliseconds: number) => Promise<void>;
  attempts?: number;
}): Promise<CameraPreviewStartResult | null> {
  const sleep = options.sleep ?? ((milliseconds) => new Promise<void>((resolve) => setTimeout(resolve, milliseconds)));
  const attempts = options.attempts ?? 3;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    if (!options.isActive()) return null;
    try {
      const result = await options.start();
      if (!options.isActive()) {
        if (result.ok) options.stop();
        return null;
      }
      if (result.ok || result.reason === "denied") return result;
    } catch {
      if (!options.isActive()) return null;
    }
    if (!options.isActive()) return null;
    await sleep(600);
    if (!options.isActive()) return null;
  }

  return { ok: false, reason: "unavailable" };
}
