/**
 * Small brand-style platform glyphs, mirroring the iOS onboarding hero ring.
 * Kept as self-contained SVGs so they stay crisp at any size and need no assets.
 */

export function YouTubeGlyph({ size = 22 }: { size?: number }) {
  return (
    <svg width={size} height={size * 0.72} viewBox="0 0 28 20" aria-hidden role="img">
      <rect width="28" height="20" rx="6" fill="#FF0000" />
      <path d="M11.5 6.2 19 10l-7.5 3.8z" fill="#fff" />
    </svg>
  );
}

export function TikTokGlyph({ size = 22 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden role="img">
      <g transform="translate(-1.6 1.6)">
        <TikTokNote fill="#25F4EE" />
      </g>
      <g transform="translate(1.6 -1.6)">
        <TikTokNote fill="#FE2C55" />
      </g>
      <TikTokNote fill="#111114" />
    </svg>
  );
}

function TikTokNote({ fill }: { fill: string }) {
  return (
    <path
      d="M15.2 3.5c.3 1.7 1.4 3 3 3.3v2.4c-1.1.1-2.1-.2-3-.8v5.4c0 2.8-2.3 5-5.1 4.7-2.3-.2-4.1-2.2-4-4.5.1-2.3 2-4.1 4.3-4.1.3 0 .5 0 .8.1v2.5c-.2-.1-.5-.1-.8-.1-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2V3.5z"
      fill={fill}
    />
  );
}

export function ReelsGlyph({ size = 22 }: { size?: number }) {
  const id = "reels-grad";
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden role="img">
      <defs>
        <linearGradient id={id} x1="0" y1="1" x2="1" y2="0">
          <stop offset="0" stopColor="#FBB034" />
          <stop offset="0.5" stopColor="#F44A73" />
          <stop offset="1" stopColor="#9C45E8" />
        </linearGradient>
      </defs>
      <rect width="24" height="24" rx="7" fill={`url(#${id})`} />
      <path d="M10 8.5 16 12l-6 3.5z" fill="#fff" />
    </svg>
  );
}

/** Central ChillNote bolt mark used in the hero orbit. */
export function BoltMark({ size = 104 }: { size?: number }) {
  const id = "bolt-grad";
  return (
    <svg width={size} height={size} viewBox="0 0 104 104" aria-hidden role="img">
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#4f9bff" />
          <stop offset="1" stopColor="#1d6ff0" />
        </linearGradient>
      </defs>
      <circle cx="52" cy="52" r="52" fill={`url(#${id})`} />
      <path
        d="M58 24 38 56h12l-4 24 22-34H54z"
        fill="#fff"
        stroke="#fff"
        strokeWidth="1.5"
        strokeLinejoin="round"
      />
    </svg>
  );
}
