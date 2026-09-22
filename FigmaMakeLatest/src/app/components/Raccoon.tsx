export function Raccoon({ size = 80 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 120 120" fill="none">
      {/* Ears */}
      <circle cx="30" cy="32" r="14" fill="#7B5C48" />
      <circle cx="90" cy="32" r="14" fill="#7B5C48" />
      <circle cx="30" cy="32" r="7" fill="#FA883A" opacity="0.5" />
      <circle cx="90" cy="32" r="7" fill="#FA883A" opacity="0.5" />
      {/* Head */}
      <ellipse cx="60" cy="62" rx="38" ry="36" fill="#A88370" />
      {/* Face mask */}
      <ellipse cx="60" cy="68" rx="32" ry="22" fill="#F6F1EB" />
      {/* Eye masks */}
      <ellipse cx="44" cy="60" rx="11" ry="13" fill="#3D2C22" />
      <ellipse cx="76" cy="60" rx="11" ry="13" fill="#3D2C22" />
      {/* Eyes */}
      <circle cx="44" cy="60" r="4" fill="#FFFFFF" />
      <circle cx="76" cy="60" r="4" fill="#FFFFFF" />
      <circle cx="44" cy="61" r="2.2" fill="#3D2C22" />
      <circle cx="76" cy="61" r="2.2" fill="#3D2C22" />
      {/* Cheeks */}
      <circle cx="34" cy="76" r="5" fill="#FA883A" opacity="0.35" />
      <circle cx="86" cy="76" r="5" fill="#FA883A" opacity="0.35" />
      {/* Nose */}
      <ellipse cx="60" cy="76" rx="4" ry="3" fill="#3D2C22" />
      {/* Mouth */}
      <path
        d="M55 82 Q60 86 65 82"
        stroke="#3D2C22"
        strokeWidth="2"
        strokeLinecap="round"
        fill="none"
      />
    </svg>
  );
}
