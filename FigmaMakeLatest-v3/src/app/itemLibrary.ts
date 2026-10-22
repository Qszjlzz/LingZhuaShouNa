import { displayCategory } from "./itemCategories.ts";

/** The library is local to this device; arranging it never mutates scanned spaces. */
export type LibraryItem = { id: string; name: string; category: string; image?: string; sourceID?: string; sourceSpaceID?: string; sourceSpaceName?: string };
export type LibraryFolder = { id: string; name: string; itemIDs: string[] };
export type LibraryState = { version: 1; items: LibraryItem[]; folders: LibraryFolder[]; rootOrder: string[] };
export const emptyLibrary = (): LibraryState => ({ version: 1, items: [], folders: [], rootOrder: [] });
export const itemKey = (id: string) => "item:" + id;
export const folderKey = (id: string) => "folder:" + id;
export const libraryStorageKey = (presentation: boolean) => "smartpaw-item-library-v1." + (presentation ? "presentation" : "personal");
const unique = (values: string[]) => [...new Set(values)];
const validImage = (value: unknown): value is string => typeof value === "string" && /^data:image\/(jpeg|png|webp);base64,/.test(value) && value.length < 900000;

export function normalizeLibrary(value: unknown): LibraryState {
  if (!value || typeof value !== "object") return emptyLibrary();
  const raw = value as Partial<LibraryState>;
  const itemIDs = new Set<string>();
  const items = (Array.isArray(raw.items) ? raw.items : []).filter((item) => {
    if (!item || typeof item.id !== "string" || typeof item.name !== "string" || !item.name.trim() || itemIDs.has(item.id)) return false;
    itemIDs.add(item.id); return true;
  }).map((item) => ({ ...item, name: item.name.trim(), category: typeof item.category === "string" && item.category.trim() ? item.category.trim() : "未分类", image: validImage(item.image) ? item.image : undefined }));
  const used = new Set<string>(); const folderIDs = new Set<string>();
  const folders = (Array.isArray(raw.folders) ? raw.folders : []).filter((folder) => {
    if (!folder || typeof folder.id !== "string" || folderIDs.has(folder.id) || typeof folder.name !== "string" || !folder.name.trim()) return false;
    folderIDs.add(folder.id); return true;
  }).map((folder) => ({ id: folder.id, name: folder.name.trim(), itemIDs: unique((Array.isArray(folder.itemIDs) ? folder.itemIDs : []).filter((id) => {
    if (typeof id !== "string" || !itemIDs.has(id) || used.has(id)) return false;
    used.add(id); return true;
  })) }));
  const available = [...folders.map((folder) => folderKey(folder.id)), ...items.filter((item) => !used.has(item.id)).map((item) => itemKey(item.id))];
  const order = unique((Array.isArray(raw.rootOrder) ? raw.rootOrder : []).filter((key) => available.includes(key)));
  return { version: 1, items, folders, rootOrder: [...order, ...available.filter((key) => !order.includes(key))] };
}
export function parseLibrary(raw: string | null): LibraryState { try { return normalizeLibrary(JSON.parse(raw || "null")); } catch { return emptyLibrary(); } }
export function importLibraryItems(state: LibraryState, incoming: LibraryItem[]): LibraryState {
  const known = new Set(state.items.map((item) => item.id));
  return normalizeLibrary({ ...state, items: [...state.items, ...incoming.filter((item) => !known.has(item.id))] });
}
/** Native IDs identify instances, so equal display names remain separate library items. */
export function scanLibraryItems(items: readonly { id: string; name: string; category: string }[], source: { spaceID?: string; spaceName?: string } = {}): LibraryItem[] {
  const candidates = new Map<string, LibraryItem>();
  items.forEach((item) => {
    if (!item.id || !item.name.trim()) return;
    const id = "native:" + item.id;
    if (!candidates.has(id)) candidates.set(id, { id, name: item.name, category: displayCategory(item.category || "未分类"), sourceID: item.id, sourceSpaceID: source.spaceID, sourceSpaceName: source.spaceName });
  });
  return [...candidates.values()];
}

export type LibraryStorage = Pick<Storage, "getItem" | "setItem">;
export type LibrarySelectionResult = { status: "saved"; added: number; library: LibraryState } | { status: "empty" | "unavailable"; added: 0 };
/** Re-read at save time so another screen's newly saved folders/items are retained. */
export function saveLibrarySelection(storage: LibraryStorage, presentation: boolean, candidates: LibraryItem[], selectedIDs: readonly string[]): LibrarySelectionResult {
  const selected = new Set(selectedIDs);
  const incoming = candidates.filter((item) => selected.has(item.id));
  if (!incoming.length) return { status: "empty", added: 0 };
  try {
    const key = libraryStorageKey(presentation);
    const previous = parseLibrary(storage.getItem(key));
    const next = importLibraryItems(previous, incoming);
    const added = next.items.length - previous.items.length;
    if (added) storage.setItem(key, JSON.stringify(next));
    return { status: "saved", added, library: next };
  } catch { return { status: "unavailable", added: 0 }; }
}

export function createLibraryFolder(state: LibraryState, id: string, name: string, itemIDs: string[] = []): LibraryState {
  if (!name.trim() || state.folders.some((folder) => folder.id === id)) return state;
  const ids = unique(itemIDs).filter((itemID) => state.items.some((item) => item.id === itemID));
  const firstIndex = Math.max(0, Math.min(...ids.map((itemID) => state.rootOrder.indexOf(itemKey(itemID))).filter((index) => index >= 0), state.rootOrder.length));
  const rootOrder = state.rootOrder.filter((key) => !ids.some((itemID) => key === itemKey(itemID)));
  rootOrder.splice(firstIndex, 0, folderKey(id));
  return normalizeLibrary({ ...state, folders: [...state.folders.map((folder) => ({ ...folder, itemIDs: folder.itemIDs.filter((itemID) => !ids.includes(itemID)) })), { id, name: name.trim(), itemIDs: ids }], rootOrder });
}
export function moveLibraryItem(state: LibraryState, id: string, destination: string | null): LibraryState {
  if (!state.items.some((item) => item.id === id) || (destination && !state.folders.some((folder) => folder.id === destination))) return state;
  const folders = state.folders.map((folder) => ({ ...folder, itemIDs: folder.id === destination ? [...folder.itemIDs.filter((itemID) => itemID !== id), id] : folder.itemIDs.filter((itemID) => itemID !== id) }));
  const rootOrder = state.rootOrder.filter((key) => key !== itemKey(id));
  if (!destination) rootOrder.push(itemKey(id));
  return normalizeLibrary({ ...state, folders, rootOrder });
}
export function renameLibraryFolder(state: LibraryState, id: string, name: string): LibraryState {
  return name.trim() ? { ...state, folders: state.folders.map((folder) => folder.id === id ? { ...folder, name: name.trim() } : folder) } : state;
}
export function removeLibraryFolder(state: LibraryState, id: string): LibraryState {
  const folder = state.folders.find((entry) => entry.id === id); if (!folder) return state;
  return normalizeLibrary({ ...state, folders: state.folders.filter((entry) => entry.id !== id), rootOrder: state.rootOrder.flatMap((key) => key === folderKey(id) ? folder.itemIDs.map(itemKey) : [key]) });
}
export function removeLibraryItem(state: LibraryState, id: string): LibraryState {
  return normalizeLibrary({ ...state, items: state.items.filter((item) => item.id !== id) });
}
export function updateLibraryItem(state: LibraryState, id: string, patch: { name?: string; image?: string }): LibraryState {
  return normalizeLibrary({ ...state, items: state.items.map((item) => item.id === id ? { ...item, ...patch, name: patch.name?.trim() || item.name } : item) });
}
export function reorderLibrary(state: LibraryState, source: string, target: string, folderID: string | null, after = false): LibraryState {
  const order = folderID ? state.folders.find((folder) => folder.id === folderID)?.itemIDs : state.rootOrder;
  if (!order || source === target || !order.includes(source) || !order.includes(target)) return state;
  const result = order.filter((key) => key !== source); result.splice(result.indexOf(target) + (after ? 1 : 0), 0, source);
  return folderID ? { ...state, folders: state.folders.map((folder) => folder.id === folderID ? { ...folder, itemIDs: result } : folder) } : { ...state, rootOrder: result };
}
