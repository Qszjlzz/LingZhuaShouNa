import { useId } from "react";

type CategoryArtworkProps = {
  categoryName?: string;
  color?: string;
  size?: number;
  label?: string;
};

const clampColor = (color: string | undefined) => /^#[0-9a-f]{6}$/i.test(color ?? "") ? color! : "#D9C2A8";

function tint(hex: string, amount: number) {
  const value = hex.slice(1);
  const channels = [0, 2, 4].map((offset) => parseInt(value.slice(offset, offset + 2), 16));
  return `rgb(${channels.map((channel) => Math.round(channel * (1 - amount) + 255 * amount)).join(",")})`;
}

/** Small, content-led vector art keeps the catalog useful when no photo exists. */
export function CategoryArtwork({ categoryName = "未分类", color, size = 48, label }: CategoryArtworkProps) {
  const base = clampColor(color);
  const id = useId().replace(/:/g, "");
  const key = categoryName.toLowerCase();
  const stroke = "#7B5C48";
  const art = (() => {
    if (key.includes("书")) return <g stroke={stroke} strokeWidth="1.4" strokeLinejoin="round"><path d="M15 15h10.5c3 0 5 1.5 5 4v14H19c-2.5 0-4-1-4-3V15Z" fill="#F7EFE6" /><path d="M33 15H22.5c-3 0-5 1.5-5 4v14H29c2.5 0 4-1 4-3V15Z" fill="#B7CBE1" /><path d="M18 20h8M18 24h7M25 20h5M25 24h5" fill="none" stroke="#C9946B" strokeLinecap="round" /></g>;
    if (key.includes("服") || key.includes("衣")) return <g stroke={stroke} strokeWidth="1.3" strokeLinejoin="round"><path d="m18 17 5-3 4 3 5 3-3 6-4-2v11H17V24l-4 2-3-6 8-3Z" fill="#F6D7D3" /><path d="m23 14 2 5 2-5M18 29h11" fill="none" /></g>;
    if (key.includes("厨") || key.includes("饮")) return <g stroke={stroke} strokeWidth="1.3"><ellipse cx="24" cy="30" rx="13" ry="5" fill="#F4DFB8" /><ellipse cx="24" cy="29" rx="9" ry="3" fill="#FFF7EA" /><path d="M16 18h16l-1 8H17l-1-8Z" fill="#E8B894" /><path d="M20 18v-3c0-3 3-3 3 0v3M29 18c0-4 3-5 4-2" fill="none" strokeLinecap="round" /><circle cx="23" cy="22" r="1" fill="#7B5C48" stroke="none" /></g>;
    if (key.includes("文具")) return <g stroke={stroke} strokeWidth="1.3" strokeLinejoin="round"><path d="m17 31 11-17 4 2-11 17-6 2 2-6Z" fill="#E9A36C" /><path d="m28 14 2-3 4 2-2 3" fill="#F4D47F" /><path d="m16 32 4 1-6 2 2-3Z" fill="#F2E4CE" /><rect x="16" y="19" width="5" height="15" rx="2" transform="rotate(35 18.5 26.5)" fill="#B7CBE1" /></g>;
    if (key.includes("丢弃")) return <g stroke={stroke} strokeWidth="1.3" strokeLinejoin="round"><path d="M16 19h16l-1 16H17l-1-16Z" fill="#D8C5A9" /><path d="M14 16h20v4H14zM20 14h8" fill="none" strokeLinecap="round" /><path d="M21 23v8M27 23v8" stroke="#FFF7EA" strokeLinecap="round" /></g>;
    if (key.includes("玩") || key.includes("杂")) return <g stroke={stroke} strokeWidth="1.3" strokeLinejoin="round"><path d="M14 25c0-5 4-8 10-8s10 3 10 8v6c0 2-2 3-4 1l-3-3h-6l-3 3c-2 2-4 1-4-1v-6Z" fill="#B4D4C9" /><path d="M18 24h5M20.5 21.5v5M28 23h.1M31 26h.1" strokeLinecap="round" /></g>;
    if (key.includes("健") || key.includes("药")) return <g stroke={stroke} strokeWidth="1.3"><rect x="14" y="18" width="20" height="11" rx="5.5" transform="rotate(-25 24 24)" fill="#E7C1D2" /><path d="m22 17 5 10" fill="none" /><path d="M21 22h5M23.5 19.5v5" stroke="#FFF7EA" strokeLinecap="round" /></g>;
    if (key.includes("工")) return <g stroke={stroke} strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"><path d="m30 16 4 4-5 5-4-4 5-5Z" fill="#A8B8CC" /><path d="m26 21-11 11M15 32l-3-3 3-3 3 3-3 3Z" fill="#E8B894" /><path d="m29 17 2-2 3 3-2 2" fill="none" /></g>;
    if (key.includes("装")) return <g stroke={stroke} strokeWidth="1.3" strokeLinejoin="round"><path d="M20 17h8l-1 5v9c0 2-1 3-3 3s-3-1-3-3v-9l-1-5Z" fill="#E8D4B4" /><path d="M18 17h12M22 14h4" fill="none" strokeLinecap="round" /><path d="M16 34c2-4 5-5 8-2 3-3 6-2 8 2" fill="#B4D4C9" /></g>;
    if (key.includes("电子") || key.includes("手机")) return <g stroke={stroke} strokeWidth="1.3" strokeLinejoin="round"><rect x="17" y="12" width="14" height="23" rx="3" fill="#C9D8EA" /><rect x="19.5" y="16" width="9" height="13" rx="1" fill="#F8F1E6" /><circle cx="24" cy="32" r="1" fill="#7B5C48" stroke="none" /><path d="m21 23 2 2 4-5" fill="none" /></g>;
    return <g stroke={stroke} strokeWidth="1.3" strokeLinejoin="round"><path d="M14 22h20v12H14z" fill="#D8C5A9" /><path d="M12 22h24l-3-4H15l-3 4ZM18 18v-4h12v4" fill="#EEDFC8" /><path d="M18 26h12M18 30h8" fill="none" strokeLinecap="round" /></g>;
  })();

  return <svg width={size} height={size} viewBox="0 0 48 48" role={label ? "img" : undefined} aria-label={label} aria-hidden={label ? undefined : true} style={{ display: "block" }}>
    <defs><linearGradient id={`${id}-bg`} x1="0" y1="0" x2="1" y2="1"><stop stopColor={tint(base, 0.72)} /><stop offset="1" stopColor={tint(base, 0.42)} /></linearGradient></defs>
    <rect x="1" y="1" width="46" height="46" rx="15" fill={`url(#${id}-bg)`} />
    <circle cx="37" cy="11" r="5" fill="#FFF7EA" fillOpacity="0.6" />
    <path d="M9 37c7-4 12-2 16 1 5 3 9 2 14-2" fill="none" stroke="#FFF7EA" strokeOpacity="0.65" strokeWidth="1.4" strokeLinecap="round" />
    {art}
  </svg>;
}

export function BookCoverArtwork({ title, color = "#A8B8CC", size = 88 }: { title: string; color?: string; size?: number }) {
  const base = clampColor(color);
  const id = useId().replace(/:/g, "");
  const shortTitle = title.replace(/[《》]/g, "").slice(0, 8);
  return <svg width="100%" height={size} viewBox="0 0 116 88" aria-hidden="true" style={{ display: "block" }}>
    <defs><linearGradient id={`${id}-cover`} x1="0" y1="0" x2="1" y2="1"><stop stopColor={base} /><stop offset="1" stopColor={tint(base, 0.2)} /></linearGradient></defs>
    <rect x="8" y="5" width="100" height="78" rx="8" fill={`url(#${id}-cover)`} />
    <path d="M20 5v78" stroke="#7B5C48" strokeOpacity="0.35" strokeWidth="3" />
    <path d="M28 18h61M28 23h43" stroke="#FFF7EA" strokeOpacity="0.78" strokeWidth="2" strokeLinecap="round" />
    <circle cx="83" cy="61" r="12" fill="#FFF7EA" fillOpacity="0.28" />
    <path d="M76 61c4-5 9-5 14 0-4 5-9 5-14 0Z" fill="#FFF7EA" fillOpacity="0.72" />
    <text x="29" y="44" fill="#FFF7EA" fontSize="9" fontWeight="600" fontFamily="PingFang SC, sans-serif">{shortTitle}</text>
    <path d="M29 68h37" stroke="#FFF7EA" strokeOpacity="0.72" strokeWidth="1.5" strokeLinecap="round" />
  </svg>;
}
