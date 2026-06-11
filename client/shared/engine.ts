// ============================================================================
// FacePong — SINGLE SOURCE OF TRUTH for ball physics + collisions + scoring.
// Pure TypeScript, no framework/native deps, so it is imported verbatim by:
//   • the Expo client  -> runs it locally for "Vs Computer" mode
//   • the Colyseus server -> runs it authoritatively for online modes
// Paddle CENTER x positions (p1x = bottom/local, p2x = top/opponent) are set by
// the caller each tick (from finger input, AI, or a remote player); step()
// advances the ball one fixed tick and reports scoring/bounce events.
// ============================================================================
import {
  COURT,
  BALL_R,
  TOP_Y,
  BOT_Y,
  PADDLE_R,
  WALL_PAD,
  MAX_SPEED,
  RALLY_RAMP,
  SERVE_VY,
  SERVE_VX_SPREAD,
  PADDLE_BOUNCE,
  clampPaddleX,
} from './constants';
import type { Slot } from './constants';

export interface EngineState {
  ballX: number;
  ballY: number;
  vx: number;
  vy: number;
  p1x: number; // bottom paddle center (local player / cyan)
  p2x: number; // top paddle center (opponent / magenta)
  rally: number;
}

export interface StepResult {
  scored: null | Slot; // which player won the point this tick
  bounced: boolean; // a paddle was hit this tick
}

export function createEngineState(): EngineState {
  return {
    ballX: COURT.W / 2,
    ballY: COURT.H / 2,
    vx: 0,
    vy: 0,
    p1x: COURT.W / 2,
    p2x: COURT.W / 2,
    rally: 0,
  };
}

// Serve the ball from center toward a slot's side. p1 = bottom (vy > 0).
export function serve(s: EngineState, toward: Slot): void {
  s.ballX = COURT.W / 2;
  s.ballY = COURT.H / 2;
  s.vx = (Math.random() * 2 - 1) * SERVE_VX_SPREAD;
  s.vy = toward === 'p1' ? SERVE_VY : -SERVE_VY;
  s.rally = 0;
}

// AI / bot target: track the ball horizontally.
export function aiTargetX(s: EngineState): number {
  return clampPaddleX(s.ballX);
}

// Advance the ball exactly one fixed tick using the current paddle centers.
export function step(s: EngineState): StepResult {
  let scored: null | Slot = null;
  let bounced = false;

  s.ballX += s.vx;
  s.ballY += s.vy;

  // left / right walls
  if (s.ballX < BALL_R + WALL_PAD) {
    s.ballX = BALL_R + WALL_PAD;
    s.vx = Math.abs(s.vx);
  } else if (s.ballX > COURT.W - BALL_R - WALL_PAD) {
    s.ballX = COURT.W - BALL_R - WALL_PAD;
    s.vx = -Math.abs(s.vx);
  }

  // top paddle (p2) — ball travelling up
  if (s.vy < 0 && s.ballY - BALL_R < TOP_Y + PADDLE_R && s.ballY - BALL_R > TOP_Y - PADDLE_R) {
    const dx = s.ballX - s.p2x;
    if (Math.abs(dx) < PADDLE_R + BALL_R) {
      s.ballY = TOP_Y + PADDLE_R + BALL_R;
      s.vy = Math.abs(s.vy) * RALLY_RAMP; // each return is a touch faster (clamped below)
      s.vx = (dx / PADDLE_R) * PADDLE_BOUNCE;
      s.rally += 1;
      bounced = true;
    }
  }

  // bottom paddle (p1) — ball travelling down
  if (s.vy > 0 && s.ballY + BALL_R > BOT_Y - PADDLE_R && s.ballY + BALL_R < BOT_Y + PADDLE_R) {
    const dx = s.ballX - s.p1x;
    if (Math.abs(dx) < PADDLE_R + BALL_R) {
      s.ballY = BOT_Y - PADDLE_R - BALL_R;
      s.vy = -Math.abs(s.vy) * RALLY_RAMP; // each return is a touch faster (clamped below)
      s.vx = (dx / PADDLE_R) * PADDLE_BOUNCE;
      s.rally += 1;
      bounced = true;
    }
  }

  // out of bounds -> the opposite player scores
  if (s.ballY < -BALL_R - 24) {
    scored = 'p1'; // passed the top paddle, bottom player wins the point
  } else if (s.ballY > COURT.H + BALL_R + 24) {
    scored = 'p2';
  }

  // clamp speed
  const sp = Math.hypot(s.vx, s.vy);
  if (sp > MAX_SPEED) {
    s.vx *= MAX_SPEED / sp;
    s.vy *= MAX_SPEED / sp;
  }

  return { scored, bounced };
}
