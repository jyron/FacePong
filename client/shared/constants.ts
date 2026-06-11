// ============================================================================
// FacePong — SINGLE SOURCE OF TRUTH for game geometry + physics.
// Imported by BOTH the Expo client (rendering / local CPU game) and the
// Colyseus server (authoritative simulation). Never duplicate these values.
// Court space is a fixed logical 390 x 844 grid; clients scale it to device.
// All positions/velocities are in court units; velocities are per-tick.
// ============================================================================

export const COURT = { W: 390, H: 844 } as const;

export const PADDLE = 88; // paddle (face coin) diameter
export const PADDLE_R = PADDLE / 2;
export const BALL_R = 10;

export const TOP_Y = 168; // top paddle center y (opponent)
export const BOT_Y = 676; // bottom paddle center y (local player)

export const WALL_PAD = 6; // ball inset from left/right walls
export const PADDLE_MARGIN = PADDLE_R + 8; // clamp for paddle center x

export const MAX_SPEED = 9.2; // max ball speed (units/tick)
export const RALLY_RAMP = 1.045; // ball speeds up this much per paddle hit (to MAX_SPEED)
export const SERVE_VY = 6.2; // vertical serve speed
export const SERVE_VX_SPREAD = 2.4; // random horizontal spread on serve
export const PADDLE_BOUNCE = 5.2; // how much paddle hit offset bends vx

export const TARGET_SCORE = 5; // first to this score wins the match
export const COUNTDOWN_FROM = 3; // round countdown start

export const TICK_HZ = 60;
export const TICK_MS = 1000 / TICK_HZ;

// Paddle smoothing (AI opponent + remote-paddle interpolation).
export const EASE = { toward: 0.09, away: 0.03 } as const;

// Player slots. p1 = bottom/local (cyan), p2 = top/opponent (magenta).
export const SLOT = { p1: 'p1', p2: 'p2' } as const;
export type Slot = (typeof SLOT)[keyof typeof SLOT];

export function clampPaddleX(x: number): number {
  const min = PADDLE_MARGIN;
  const max = COURT.W - PADDLE_MARGIN;
  return x < min ? min : x > max ? max : x;
}
