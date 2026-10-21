const displayToNative: Record<string, string> = {
  服饰: "衣物",
  玩具: "玩偶杂物",
  工具: "收纳工具",
};

const nativeToDisplay: Record<string, string> = Object.fromEntries(
  Object.entries(displayToNative).map(([display, native]) => [native, display]),
);

export function displayCategory(category: string): string {
  return nativeToDisplay[category] ?? category;
}

export function nativeCategory(category: string): string {
  return displayToNative[category] ?? category;
}
