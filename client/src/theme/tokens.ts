// Neon-arcade theme, ported from the design bundle's FacePong.css.
export const C = {
  bg: '#07070f',
  bg2: '#0d0c1a',
  surface: '#14122a',
  surface2: '#1d1b3a',
  ink: '#f3f1ff',
  inkDim: '#a59fce',
  inkFaint: '#6a6496',

  cyan: '#19e7ff', // player 1 (bottom / local)
  magenta: '#ff2e88', // player 2 (top / opponent)
  lime: '#d4ff3d', // ball / highlight
  purple: '#7b3bff',
  amber: '#ffb02e',

  grid: 'rgba(123, 59, 255, 0.16)',
} as const;

export const FONT = {
  display: 'Bungee_400Regular', // headings / scores / buttons
  body: 'SpaceGrotesk_500Medium',
  bodyBold: 'SpaceGrotesk_700Bold',
} as const;

// Per-player accent helpers.
export const ringColor = (slot: 'p1' | 'p2') => (slot === 'p1' ? C.cyan : C.magenta);
