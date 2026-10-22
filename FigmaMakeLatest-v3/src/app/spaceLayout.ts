import type { SpaceKind, SpaceShape } from "./components/SpaceArtwork";

export type SpaceLayout = {
  skin: SpaceKind;
  shape: SpaceShape;
  width: number;
  height: number;
  x: number;
  y: number;
  rot: number;
  scale: number;
  vivid: string;
};

export const SPACE_KINDS: SpaceKind[] = ["bed", "desk", "kitchen", "teatable", "shelf", "drawer", "counter", "area"];
export const SPACE_SHAPES: SpaceShape[] = ["original", "rectangle", "rounded", "circle", "lshape"];
export const MAP_SIZE = { width: 358, height: 408 };
const finite = (value: unknown, fallback: number) => typeof value === "number" && Number.isFinite(value) ? value : fallback;
const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(max, value));
const record = (value: unknown): value is Record<string, unknown> => !!value && typeof value === "object" && !Array.isArray(value);

export function spaceKind(value: unknown, fallback: SpaceKind): SpaceKind {
  return SPACE_KINDS.includes(value as SpaceKind) ? value as SpaceKind : fallback;
}

export function inferSpaceKind(name: string): SpaceKind {
  if (/厨房|kitchen/i.test(name)) return "kitchen";
  if (/抽屉|drawer/i.test(name)) return "drawer";
  if (/床|卧室|bed/i.test(name)) return "bed";
  if (/书架|衣柜|柜|架|shelf|closet/i.test(name)) return "shelf";
  if (/洗手|洗漱|浴室|台面|料理|counter/i.test(name)) return "counter";
  if (/茶|客厅|沙发|living/i.test(name)) return "teatable";
  if (/桌|书房|餐|desk/i.test(name)) return "desk";
  return "area";
}

export function spaceFootprint(layout: Pick<SpaceLayout, "width" | "height" | "scale" | "rot">) {
  const width = layout.width * layout.scale;
  const height = layout.height * layout.scale;
  return Math.abs(layout.rot % 180) === 90 ? { width: height, height: width } : { width, height };
}

export function normalizeSpaceLayout(value: unknown, fallback: SpaceLayout, board = MAP_SIZE): SpaceLayout {
  const source = record(value) ? value : {};
  const rot = ((Math.round(finite(source.rot, fallback.rot) / 90) * 90) % 360 + 360) % 360;
  const result: SpaceLayout = {
    skin: spaceKind(source.skin, fallback.skin),
    shape: SPACE_SHAPES.includes(source.shape as SpaceShape) ? source.shape as SpaceShape : fallback.shape,
    width: clamp(finite(source.width, fallback.width), 56, 240),
    height: clamp(finite(source.height, fallback.height), 56, 240),
    scale: clamp(finite(source.scale, fallback.scale), 0.72, 1.45),
    x: finite(source.x, fallback.x),
    y: finite(source.y, fallback.y),
    rot,
    vivid: typeof source.vivid === "string" && /^#[0-9a-f]{6}$/i.test(source.vivid) ? source.vivid : fallback.vivid,
  };
  const legacyColors: Partial<Record<SpaceKind, string>> = { bed: "#A6B2D6", kitchen: "#A9B486", teatable: "#DFA6B0" };
  if (!source.skin && !source.shape && !source.width && result.vivid.toUpperCase() === legacyColors[fallback.skin]) result.vivid = fallback.vivid;
  // Keep the rotated shape inside the board, including old enlarged layouts.
  const footprint = spaceFootprint(result);
  const fit = Math.min(1, Math.max(board.width - 12, 1) / footprint.width, Math.max(board.height - 12, 1) / footprint.height);
  result.width *= fit;
  result.height *= fit;
  const bounds = spaceFootprint(result);
  result.x = clamp(result.x, 6, Math.max(6, board.width - bounds.width - 6));
  result.y = clamp(result.y, 6, Math.max(6, board.height - bounds.height - 6));
  return result;
}

export function parseSpaceLayouts(raw: string | null): Record<string, Record<string, unknown>> {
  try {
    const parsed: unknown = JSON.parse(raw || "{}");
    if (!record(parsed)) return {};
    return Object.fromEntries(Object.entries(parsed).filter(([id, value]) => id !== "__proto__" && id !== "constructor" && id !== "prototype" && record(value)));
  } catch { return {}; }
}

export function pointerDelta(clientX: number, clientY: number, startX: number, startY: number, logicalWidth: number, logicalHeight: number, rectWidth: number, rectHeight: number) {
  const sx = rectWidth > 0 ? logicalWidth / rectWidth : 1;
  const sy = rectHeight > 0 ? logicalHeight / rectHeight : 1;
  return { x: (clientX - startX) * sx, y: (clientY - startY) * sy };
}
