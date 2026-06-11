// SVG-string twins of the <DefaultFace> avatars (faces/DefaultFace.tsx), so the
// same stylized faces can be drawn INSIDE the Skia canvas (via <ImageSVG>) for a
// player who hasn't dropped in a photo — e.g. the CPU paddle. Keep these in sync
// with DefaultFace.tsx (same 0 0 100 100 viewBox, same paths/colours).
import type { Slot } from '../../shared/constants';

const P1 = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <linearGradient id="p1bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#0c2b3a"/>
      <stop offset="1" stop-color="#0a1726"/>
    </linearGradient>
  </defs>
  <rect width="100" height="100" fill="url(#p1bg)"/>
  <ellipse cx="50" cy="55" rx="27" ry="30" fill="#ffd6a8"/>
  <path d="M23 50c0-19 13-30 27-30s27 11 27 30c0-6-3-9-7-9-2-9-13-15-20-15s-18 6-20 15c-4 0-7 3-7 9z" fill="#23314a"/>
  <rect x="28" y="48" width="44" height="11" rx="5.5" fill="#0b1320"/>
  <rect x="30" y="49.5" width="17" height="8" rx="4" fill="#19e7ff" opacity="0.85"/>
  <rect x="53" y="49.5" width="17" height="8" rx="4" fill="#19e7ff" opacity="0.85"/>
  <path d="M40 70q10 9 20 0" stroke="#b9744a" stroke-width="3.5" fill="none" stroke-linecap="round"/>
</svg>`;

const P2 = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <linearGradient id="p2bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#3a0c2a"/>
      <stop offset="1" stop-color="#260a1c"/>
    </linearGradient>
  </defs>
  <rect width="100" height="100" fill="url(#p2bg)"/>
  <ellipse cx="50" cy="55" rx="27" ry="30" fill="#e7b48f"/>
  <path d="M21 58c-2-26 14-38 29-38s31 12 29 38c-3-4-6-4-9-3 1-10-2-17-6-20-3 7-12 10-23 10-4 0-7 2-9 6-1 3-1 8 0 12-4-1-8-1-11-5z" fill="#3b1d33"/>
  <circle cx="40" cy="52" r="3.4" fill="#2a1422"/>
  <circle cx="60" cy="52" r="3.4" fill="#2a1422"/>
  <circle cx="34" cy="62" r="4" fill="#ff7ab0" opacity="0.4"/>
  <circle cx="66" cy="62" r="4" fill="#ff7ab0" opacity="0.4"/>
  <path d="M41 67q9 10 18 0" stroke="#b85b7e" stroke-width="3.5" fill="none" stroke-linecap="round"/>
</svg>`;

export const defaultFaceSvgString = (slot: Slot) => (slot === 'p1' ? P1 : P2);
