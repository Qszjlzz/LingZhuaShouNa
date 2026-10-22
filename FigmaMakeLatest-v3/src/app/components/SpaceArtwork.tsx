import { useId, type CSSProperties } from "react";

export type SpaceKind = "bed" | "desk" | "kitchen" | "teatable" | "shelf" | "drawer" | "counter" | "area";
export type SpaceShape = "original" | "rectangle" | "rounded" | "circle" | "lshape";

export const SPACE_TEMPLATES: Record<SpaceKind, { label: string; w: number; h: number; color: string; description: string }> = {
  bed: { label: "床", w: 138, h: 138, color: "#CDEDEC", description: "床铺、床边" },
  desk: { label: "桌面", w: 143, h: 78, color: "#FFF19C", description: "书桌、工作桌" },
  kitchen: { label: "厨房", w: 138, h: 138, color: "#D9F7C8", description: "转角台面、料理区" },
  teatable: { label: "茶几", w: 139, h: 74, color: "#F9DDCE", description: "茶几、边桌" },
  shelf: { label: "柜架", w: 115, h: 142, color: "#DCCFEE", description: "书架、衣柜、鞋柜" },
  drawer: { label: "抽屉／盒", w: 132, h: 102, color: "#C8E9DF", description: "抽屉、收纳箱、化妆盒" },
  counter: { label: "台面", w: 145, h: 90, color: "#CEE4F5", description: "洗手台、洗衣台、操作台" },
  area: { label: "自由区域", w: 125, h: 115, color: "#F6DEB7", description: "角落、地面、阳台局部" },
};

function tint(hex: string, white: number) {
  return `rgb(${[1, 3, 5].map((i) => Math.round(parseInt(hex.slice(i, i + 2), 16) * (1 - white) + 255 * white)).join(",")})`;
}

function outline(w: number, h: number, shape: SpaceShape, kind: SpaceKind) {
  const r = shape === "rectangle" ? 3 : shape === "rounded" ? Math.min(w, h) * 0.22 : 12;
  if (shape === "circle") return `M ${w / 2},2 A ${w / 2 - 2},${h / 2 - 2} 0 1 1 ${w / 2 - 0.01},2 Z`;
  if (shape === "lshape" || (shape === "original" && kind === "kitchen")) {
    const arm = Math.min(w * 0.49, h * 0.51);
    return `M 14,2 H ${w - 14} Q ${w - 2},2 ${w - 2},14 V ${arm - 10} Q ${w - 2},${arm + 2} ${w - 14},${arm + 2} H ${arm + 12} Q ${arm},${arm + 2} ${arm},${arm + 14} V ${h - 14} Q ${arm},${h - 2} ${arm - 12},${h - 2} H 14 Q 2,${h - 2} 2,${h - 14} V 14 Q 2,2 14,2 Z`;
  }
  return `M ${r + 2},2 H ${w - r - 2} Q ${w - 2},2 ${w - 2},${r + 2} V ${h - r - 2} Q ${w - 2},${h - 2} ${w - r - 2},${h - 2} H ${r + 2} Q 2,${h - 2} 2,${h - r - 2} V ${r + 2} Q 2,2 ${r + 2},2 Z`;
}

/** The map is made of editable vector geometry; no bitmap or embedded image is used. */
export function SpaceArtwork({ kind, shape = "original", width, height, color, label, className, style }: {
  kind: SpaceKind;
  shape?: SpaceShape;
  width?: number;
  height?: number;
  color?: string;
  label?: string;
  className?: string;
  style?: CSSProperties;
}) {
  const template = SPACE_TEMPLATES[kind];
  const frameW = Number.isFinite(width) ? Math.max(56, width!) : template.w;
  const frameH = Number.isFinite(height) ? Math.max(56, height!) : template.h;
  const w = template.w;
  const h = template.h;
  const base = color && /^#[0-9a-f]{6}$/i.test(color) ? color : template.color;
  const id = useId().replace(/:/g, "");
  const path = outline(frameW, frameH, shape, kind);
  const lshape = kind === "kitchen";
  const contentH = Math.max(24, h - 25);
  const contentW = Math.max(24, w - 23);
  const x = 11;
  const y = 22;
  let artBox = { x: 0, y: 0, width: frameW, height: frameH };
  if (shape === "circle") {
    const top = Math.max(frameH * 0.1465, 22);
    artBox = { x: frameW * 0.1465, y: top, width: frameW * 0.707, height: Math.max(14, frameH * 0.8535 - top) };
  } else if (shape === "lshape" && kind !== "kitchen") {
    const arm = Math.min(frameW * 0.49, frameH * 0.51);
    const vertical = { x: 5, y: 21, width: Math.max(12, arm - 10), height: frameH - 27 };
    const horizontal = { x: 5, y: 21, width: frameW - 10, height: Math.max(10, arm - 26) };
    artBox = Math.min(vertical.width / w, vertical.height / h) >= Math.min(horizontal.width / w, horizontal.height / h) ? vertical : horizontal;
  }
  const fit = Math.min(artBox.width / w, artBox.height / h);
  const bodyTransform = lshape && (shape === "original" || shape === "lshape")
    ? `scale(${frameW / w} ${frameH / h})`
    : `translate(${artBox.x + (artBox.width - w * fit) / 2} ${artBox.y + (artBox.height - h * fit) / 2}) scale(${fit})`;
  const body = (() => {
    if (kind === "bed") {
      const bx = w * 0.31;
      const by = h * 0.17;
      const bw = w * 0.54;
      const bh = h * 0.73;
      return <>
        <path d={`M 12,${h * 0.56} V 20 H ${w - 12}`} stroke="#C5E1E7" strokeWidth="3" fill="none" strokeLinecap="round" />
        <rect x={bx} y={by} width={bw} height={bh} rx="5" fill="#B7CBF3" />
        <rect x={bx + bw * 0.32} y={by + 3} width={bw * 0.38} height={bh * 0.13} rx="5" fill="#9DAFD2" />
        <path d={`M ${bx},${by + bh * 0.24} L ${bx + bw * 0.97},${by + bh * 0.16} L ${bx + bw * 1.02},${by + bh * 0.9} L ${bx},${by + bh * 0.93} Z`} fill="#9DB2D3" />
        <path d={`M ${bx},${by + bh * 0.24} L ${bx + bw * 0.97},${by + bh * 0.16} L ${bx + bw * 0.16},${by + bh * 0.33} Z`} fill="#CDDDFB" />
        <rect x={w * 0.11} y={h * 0.18} width={w * 0.19} height={h * 0.105} rx="5" fill="#D8D9D9" />
        <path d={`M ${w * 0.13},${h * 0.18} C ${w * 0.17},${h * 0.24} ${w * 0.26},${h * 0.17} ${w * 0.29},${h * 0.21}`} stroke="white" strokeWidth="0.7" fill="none" />
        <rect x={w * 0.27} y={h * 0.2} width="3" height="10" rx="1.5" fill="white" />
        <path d={`M ${w * 0.17},${h * 0.59} C ${w * 0.05},${h * 0.59} ${w * 0.07},${h * 0.87} ${w * 0.23},${h * 0.94} C ${w * 0.35},${h * 1.01} ${w * 0.4},${h * 0.92} ${w * 0.5},${h * 0.85} C ${w * 0.65},${h * 0.7} ${w * 0.37},${h * 0.58} ${w * 0.17},${h * 0.59} Z`} fill="#96C2FF" fillOpacity="0.55" />
        <path d={`M ${w * 0.24},${h * 0.65} l 5,0 M ${w * 0.24},${h * 0.68} l 5,-1`} stroke="#89ADE2" strokeWidth="3" strokeLinecap="round" opacity="0.6" />
      </>;
    }
    if (kind === "desk") {
      const top = h * 0.33;
      const dh = h * 0.4;
      return <>
        <path d={`M 13,20 H ${w - 9} V ${h - 13}`} stroke="#FFEB86" strokeWidth="3.4" fill="none" strokeLinecap="round" />
        <circle cx={w * 0.46} cy={top + dh - 2} r={dh * 0.4} fill="#EED6AD" opacity="0.7" />
        <rect x={w * 0.12} y={top} width={w * 0.64} height={dh} rx="5" fill="#A47F5D" />
        <rect x={w * 0.76} y={top} width={w * 0.12} height={dh} rx="5" fill="#968471" />
        <rect x={w * 0.135} y={top + 2} width={w * 0.12} height={dh * 0.53} rx="4" fill="#FFFFE8" />
        <rect x={w * 0.18} y={top + 7} width="8" height="4" rx="1" fill="#FFE0CA" />
        <rect x={w * 0.186} y={top + 11} width="8" height="5" rx="1" fill="#FFF0D3" />
        <path d={`M ${w * 0.15},${top + 4} l 1,-0.5`} stroke="#A48D76" strokeWidth="3" strokeLinecap="round" />
        {[0, 1, 2, 3].map((n) => <rect key={n} x={w * 0.67 + n * 2.1} y={top + 1} width="1.6" height={dh * (n > 1 ? 0.8 : 0.65)} fill={["#7F7853", "#D69551", "#ABBEBC", "#E8DECA"][n]} />)}
        <path d={`M ${w * 0.79},${top + 5} q 0,-19 7,-2 q 5,-16 6,5`} stroke="#DDC06D" strokeWidth="0.6" fill="none" />
        <rect x={w * 0.775} y={top + 5} width="13" height="9" rx="5" fill="#DCA33E" />
      </>;
    }
    if (kind === "kitchen") {
      const arm = Math.min(w * 0.49, h * 0.51);
      const inner = 20;
      const end = w - 18;
      const run = lshape ? arm - 4 : h - 14;
      return <>
        <path d={`M 12,${h * 0.72} V 22 H ${w - 12}`} stroke="#D2E8C6" strokeWidth="3.5" fill="none" strokeLinecap="round" />
        <path d={`M ${inner},28 H ${end} V ${Math.min(run - 12, 51)} H ${arm - 10} V ${h - 12} H ${inner} Z`} fill="#D9DADA" />
        <rect x={w - 48} y="30" width="25" height="19" rx="5" fill="#BFC1C0" />
        <path d={`M ${w - 51},31 l 13,5`} stroke="#ABAAA6" strokeWidth="1.2" />
        <circle cx={w - 35} cy="40" r="1.5" fill="#AAA9A5" />
        <rect x={w - 26} y="38" width="3.5" height="5" rx="1" fill="#FFF8EC" transform={`rotate(20 ${w - 24} 40)`} />
        <rect x={w - 61} y="29.5" width="7" height="5" rx="2" fill="#E3EE11" />
        <rect x="22" y={h * 0.34} width="11" height="16" rx="2" fill="#D6D27D" />
        <circle cx="34" cy={h * 0.34} r="3.2" fill="#B8EBC0" />
        <rect x="39" y={h * 0.34} width="4" height="6" rx="2" fill="#A29C9A" />
        <ellipse cx="48" cy={h * 0.35} rx="3" ry="2" fill="#C5DD9E" />
        <rect x="26" y={h * 0.55} width={Math.max(17, arm - 38)} height={h * 0.31} rx="6" fill="#BFC0BF" />
        {[0.64, 0.78].map((v) => <g key={v}><circle cx={arm * 0.62} cy={h * v} r={Math.min(7.2, arm * 0.13)} fill="#ADA9A8" /><path d={`M ${arm * 0.62 - 7},${h * v} h 3 M ${arm * 0.62 + 4},${h * v} h 3 M ${arm * 0.62},${h * v - 7} v 3 M ${arm * 0.62},${h * v + 4} v 3`} stroke="#989493" strokeWidth="0.8" /></g>)}
      </>;
    }
    if (kind === "teatable") return <>
      <path d={`M 12,${h - 18} H ${w - 9} V 21`} stroke="#F3D1C3" strokeWidth="3" fill="none" strokeLinecap="round" />
      <rect x="9" y={h * 0.36} width={w - 25} height={h * 0.24} rx="5" fill="#EBCFE0" />
      {[0.42, 0.54].map((v) => <g key={v}><circle cx="18" cy={h * v} r="3.2" fill="#BDA3C8" /><circle cx="18" cy={h * v} r="2.2" fill="#9681A7" /></g>)}
      <g transform={`translate(${w - 27} ${h * 0.49})`} stroke="#A8AD8C" strokeWidth="0.4">
        <path d="M -5,5 Q -1,-3 7,-3 M -3,2 Q 3,0 10,4" fill="none" />
        <path d="M -2,1 Q -9,-9 -8,-3 Q -7,1 -2,1 M -2,1 Q 0,-9 3,-6 Q 6,-3 -2,1" fill="#B5BA98" />
        <path d="M 0,1 Q 8,-4 8,-1 Q 7,1 0,1 M 0,2 Q 7,9 9,6 Q 8,3 0,2" fill="#D3D2AD" />
        <path d="M -1,1 Q -7,8 -8,4 L -4,5 Z" fill="#BBB79A" />
      </g>
    </>;
    if (kind === "shelf") return <>
      <rect x={x + 4} y={y} width={contentW - 8} height={contentH - 5} rx="4" fill="#C6B5D1" />
      {[0, 1, 2].map((row) => <g key={row} transform={`translate(${x + 8} ${y + 6 + row * (contentH - 14) / 3})`}>
        <rect width={contentW - 16} height={(contentH - 23) / 3} rx="2" fill="#F4EDF7" />
        {[0, 1, 2, 3].map((n) => <rect key={n} x={4 + n * 6} y="3" width="4.5" height={(contentH - 35) / 3} rx="1" fill={["#B5C6DC", "#E0B6A2", "#C4CEA5", "#CAB3CD"][(n + row) % 4]} />)}
        <rect x={contentW - 41} y="7" width="18" height={Math.max(8, (contentH - 47) / 3)} rx="2" fill="#D4C3A8" />
        <path d={`M ${contentW - 35},11 h 6`} stroke="#F6EEE4" strokeWidth="2" strokeLinecap="round" />
      </g>)}
    </>;
    if (kind === "drawer") return <>
      <rect x={x} y={y} width={contentW} height={contentH - 4} rx="6" fill="#ADC5B8" />
      <rect x={x + 4} y={y + 4} width={contentW * 0.32} height={contentH - 12} rx="3" fill="#E3F0E5" />
      <rect x={x + contentW * 0.39} y={y + 4} width={contentW * 0.57} height={(contentH - 16) * 0.5} rx="3" fill="#F4E9D7" />
      <rect x={x + contentW * 0.39} y={y + contentH * 0.52} width={contentW * 0.57} height={(contentH - 16) * 0.5} rx="3" fill="#E9DAE9" />
      {[0, 1, 2].map((n) => <rect key={n} x={x + 8 + n * 5} y={y + 10} width="3" height={contentH * 0.58} rx="1.5" fill={["#9CAFC4", "#D3A68F", "#C2B694"][n]} />)}
      <ellipse cx={x + contentW * 0.55} cy={y + contentH * 0.27} rx="8" ry="5" fill="#D7B8A4" />
      <rect x={x + contentW * 0.48} y={y + contentH * 0.65} width={contentW * 0.3} height="8" rx="3" fill="#BAA5C8" />
    </>;
    if (kind === "counter") return <>
      <rect x={x} y={y} width={contentW} height={contentH - 5} rx="5" fill="#E2E3DE" />
      <rect x={x + contentW * 0.32} y={y + 6} width={contentW * 0.47} height={contentH - 18} rx="9" fill="#BCCED5" />
      <rect x={x + contentW * 0.37} y={y + 10} width={contentW * 0.37} height={contentH - 26} rx="7" fill="#D8E6EA" />
      <path d={`M ${x + contentW * 0.55},${y + 14} v -9 q 0,-6 6,-6 h 3`} stroke="#99A9AD" strokeWidth="2.5" fill="none" strokeLinecap="round" />
      <rect x={x + 5} y={y + 8} width="9" height={contentH * 0.48} rx="3" fill="#C6D2AE" />
      <rect x={x + 7} y={y + 4} width="5" height="6" rx="1" fill="#A0B28F" />
      <rect x={x + contentW - 16} y={y + 7} width="10" height={contentH * 0.65} rx="3" fill="#DDBEAA" />
      <path d={`M ${x + contentW - 13},${y + 10} v ${contentH * 0.5}`} stroke="#F5E3D7" strokeWidth="1" />
    </>;
    return <>
      <rect x={x + 2} y={y + 1} width={contentW - 4} height={contentH - 7} rx="7" fill="none" stroke="#CFB98F" strokeWidth="1" strokeDasharray="3 3" />
      <rect x={w * 0.17} y={h * 0.38} width={w * 0.36} height={h * 0.34} rx="5" fill="#CDB38E" />
      <rect x={w * 0.21} y={h * 0.42} width={w * 0.28} height={h * 0.1} rx="2" fill="#F2E4CE" />
      <rect x={w * 0.6} y={h * 0.6} width={w * 0.2} height={h * 0.18} rx="3" fill="#B7C5A5" />
      <rect x={w * 0.61} y={h * 0.36} width={w * 0.18} height={h * 0.18} rx="4" fill="#BBC6D6" />
    </>;
  })();

  return <svg xmlns="http://www.w3.org/2000/svg" viewBox={`0 0 ${frameW} ${frameH}`} width={width === undefined ? "100%" : frameW} height={height === undefined ? "100%" : frameH} className={className} style={{ overflow: "visible", ...style }} role={label ? "img" : undefined} aria-label={label ? `${label}区域图案` : undefined} aria-hidden={label ? undefined : true} data-space-artwork={kind}>
    <defs>
      <linearGradient id={`${id}-fill`} x1="0" y1="0" x2="1" y2="1"><stop stopColor={tint(base, 0.65)} /><stop offset="0.6" stopColor={tint(base, 0.8)} /><stop offset="1" stopColor={tint(base, 0.58)} /></linearGradient>
      <filter id={`${id}-edge`} x="-25%" y="-25%" width="150%" height="150%" colorInterpolationFilters="sRGB">
        <feDropShadow dx="0" dy="2.5" stdDeviation="2" floodColor={base} floodOpacity="0.8" />
        <feDropShadow dx="0" dy="3" stdDeviation="3.5" floodColor="#7B5C48" floodOpacity="0.08" />
      </filter>
      <filter id={`${id}-inner`} x="-10%" y="-10%" width="120%" height="120%" colorInterpolationFilters="sRGB">
        <feGaussianBlur in="SourceAlpha" stdDeviation="1.6" result="blur" />
        <feComposite in="SourceAlpha" in2="blur" operator="out" result="edge" />
        <feFlood floodColor={base} floodOpacity="0.55" /><feComposite in2="edge" operator="in" /><feMerge><feMergeNode in="SourceGraphic" /><feMergeNode /></feMerge>
      </filter>
      <clipPath id={`${id}-clip`}><path d={path} /></clipPath>
    </defs>
    <path d={path} fill={`url(#${id}-fill)`} stroke="white" strokeOpacity="0.95" strokeWidth="1.5" filter={`url(#${id}-edge)`} />
    <path d={path} fill="transparent" filter={`url(#${id}-inner)`} />
    <g clipPath={`url(#${id}-clip)`}><g transform={bodyTransform}>{body}</g></g>
    {label && <text x={shape === "circle" ? frameW / 2 : 10} y="16" textAnchor={shape === "circle" ? "middle" : "start"} fill="#7B5C48" fontFamily="PingFang SC, -apple-system, BlinkMacSystemFont, sans-serif" fontWeight="400" fontSize="11" letterSpacing="0">{label}</text>}
  </svg>;
}
