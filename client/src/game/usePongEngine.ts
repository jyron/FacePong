// Drives the ball/paddle physics for local "Vs Computer" play entirely on the
// UI thread via a Reanimated frame callback, writing position SharedValues that
// Skia renders. Two rules keep the SharedValues "live" (and the ball actually
// animating), and they are the same rules the networked renderer follows:
//   1. Never write a SharedValue from the JS thread while a worklet reads it —
//      marshal setup writes through runOnUI.
//   2. Worklets reference individual SharedValues only, never an array/object of
//      them (a captured array gets serialized and its writes silently no-op).
//
// The collision math mirrors the authoritative server engine in
// ../../shared/engine.ts; geometry/speeds come from ../../shared/constants.ts.
import { useRef } from 'react';
import {
  useSharedValue,
  useFrameCallback,
  runOnJS,
  runOnUI,
  type SharedValue,
} from 'react-native-reanimated';
import {
  COURT,
  BALL_R,
  TOP_Y,
  BOT_Y,
  PADDLE_R,
  PADDLE_MARGIN,
  WALL_PAD,
  MAX_SPEED,
  RALLY_RAMP,
  SERVE_VY,
  SERVE_VX_SPREAD,
  PADDLE_BOUNCE,
  TICK_MS,
  EASE,
  type Slot,
} from '../../shared/constants';

// The set of SharedValues the Skia court renders. Implemented by both the local
// CPU engine (below) and the networked renderer (net/useNetGame.ts).
export interface CourtVisual {
  ballX: SharedValue<number>;
  ballY: SharedValue<number>;
  p1x: SharedValue<number>; // bottom paddle (always the local player)
  p2x: SharedValue<number>; // top paddle (opponent / CPU)
  inputX: SharedValue<number>;
  trailX: SharedValue<number>[];
  trailY: SharedValue<number>[];
  // Monotonic per-paddle hit counters — bumped once each time that paddle hits
  // the ball. The renderer watches these to fire the squash-stretch reaction.
  p1Hit: SharedValue<number>;
  p2Hit: SharedValue<number>;
  // Monotonic wall-bounce counter (left/right walls) for the wall blip + flash.
  wallHit: SharedValue<number>;
  // Live rally length — drives the ball "heating up" and the SFX pitch climb.
  rally: SharedValue<number>;
}

export interface PongEngine extends CourtVisual {
  startCpu: (toward?: Slot) => void;
  stop: () => void;
  freezePose: () => void;
  getRally: () => number;
}

const CX = COURT.W / 2;
const CY = COURT.H / 2;

export function usePongEngine(onScore: (slot: Slot) => void): PongEngine {
  const ballX = useSharedValue(CX);
  const ballY = useSharedValue(CY);
  const vx = useSharedValue(0);
  const vy = useSharedValue(0);
  const p1x = useSharedValue(CX);
  const p2x = useSharedValue(CX);
  const inputX = useSharedValue(CX);
  const rally = useSharedValue(0);
  const acc = useSharedValue(0);
  const running = useSharedValue(false);
  const p1Hit = useSharedValue(0);
  const p2Hit = useSharedValue(0);
  const wallHit = useSharedValue(0);

  // Trail ring buffer as individual SharedValues (never indexed inside worklets).
  const t0x = useSharedValue(CX);
  const t1x = useSharedValue(CX);
  const t2x = useSharedValue(CX);
  const t3x = useSharedValue(CX);
  const t4x = useSharedValue(CX);
  const t0y = useSharedValue(CY);
  const t1y = useSharedValue(CY);
  const t2y = useSharedValue(CY);
  const t3y = useSharedValue(CY);
  const t4y = useSharedValue(CY);
  // Arrays are built at render time only (for Skia's render map) — not captured by worklets.
  const trailX = [t0x, t1x, t2x, t3x, t4x];
  const trailY = [t0y, t1y, t2y, t3y, t4y];

  const onScoreRef = useRef(onScore);
  onScoreRef.current = onScore;
  const emitScore = useRef((slot: Slot) => onScoreRef.current(slot)).current;

  const frame = useFrameCallback((info) => {
    'worklet';
    if (!running.value) return;
    let dt = info.timeSincePreviousFrame ?? TICK_MS;
    if (dt > 100) dt = 100;
    acc.value += dt;

    const lo = PADDLE_MARGIN;
    const hi = COURT.W - PADDLE_MARGIN;
    let scored = 0; // 0 none, 1 p1, 2 p2

    while (acc.value >= TICK_MS) {
      acc.value -= TICK_MS;

      const np1 = p1x.value + (inputX.value - p1x.value) * 0.45;
      p1x.value = np1 < lo ? lo : np1 > hi ? hi : np1;
      const k = vy.value < 0 ? EASE.toward * 0.9 : EASE.away;
      const np2 = p2x.value + (ballX.value - p2x.value) * k;
      p2x.value = np2 < lo ? lo : np2 > hi ? hi : np2;

      ballX.value += vx.value;
      ballY.value += vy.value;

      // Bounces mirror the position across the contact plane instead of
      // clamping to it — a clamp eats the sub-tick remainder and reads as a
      // one-frame stall on every impact (mirrors shared/engine.ts).
      if (ballX.value < BALL_R + WALL_PAD) {
        ballX.value = 2 * (BALL_R + WALL_PAD) - ballX.value;
        vx.value = Math.abs(vx.value);
        wallHit.value += 1;
      } else if (ballX.value > COURT.W - BALL_R - WALL_PAD) {
        ballX.value = 2 * (COURT.W - BALL_R - WALL_PAD) - ballX.value;
        vx.value = -Math.abs(vx.value);
        wallHit.value += 1;
      }

      if (vy.value < 0 && ballY.value - BALL_R < TOP_Y + PADDLE_R && ballY.value - BALL_R > TOP_Y - PADDLE_R) {
        const dx = ballX.value - p2x.value;
        if (Math.abs(dx) < PADDLE_R + BALL_R) {
          ballY.value = 2 * (TOP_Y + PADDLE_R + BALL_R) - ballY.value; // mirror, not clamp
          vy.value = Math.abs(vy.value) * RALLY_RAMP;
          vx.value = (dx / PADDLE_R) * PADDLE_BOUNCE;
          rally.value += 1;
          p2Hit.value += 1;
        }
      }
      if (vy.value > 0 && ballY.value + BALL_R > BOT_Y - PADDLE_R && ballY.value + BALL_R < BOT_Y + PADDLE_R) {
        const dx = ballX.value - p1x.value;
        if (Math.abs(dx) < PADDLE_R + BALL_R) {
          ballY.value = 2 * (BOT_Y - PADDLE_R - BALL_R) - ballY.value; // mirror, not clamp
          vy.value = -Math.abs(vy.value) * RALLY_RAMP;
          vx.value = (dx / PADDLE_R) * PADDLE_BOUNCE;
          rally.value += 1;
          p1Hit.value += 1;
        }
      }

      if (ballY.value < -BALL_R - 24) scored = 1;
      else if (ballY.value > COURT.H + BALL_R + 24) scored = 2;

      const sp = Math.hypot(vx.value, vy.value);
      if (sp > MAX_SPEED) {
        vx.value *= MAX_SPEED / sp;
        vy.value *= MAX_SPEED / sp;
      }
      if (scored) break;
    }

    // trail shift — individual SVs (oldest first)
    t4x.value = t3x.value;
    t4y.value = t3y.value;
    t3x.value = t2x.value;
    t3y.value = t2y.value;
    t2x.value = t1x.value;
    t2y.value = t1y.value;
    t1x.value = t0x.value;
    t1y.value = t0y.value;
    t0x.value = ballX.value;
    t0y.value = ballY.value;

    if (scored) {
      running.value = false;
      runOnJS(emitScore)(scored === 1 ? 'p1' : 'p2');
    }
  }, false);

  // ---- JS control surface: all SharedValue writes marshaled to the UI thread ----
  const startCpu = (toward: Slot = 'p2') => {
    const vyDir = toward === 'p1' ? SERVE_VY : -SERVE_VY;
    const vxr = (Math.random() * 2 - 1) * SERVE_VX_SPREAD;
    frame.setActive(true);
    runOnUI((vyd: number, vx0: number) => {
      'worklet';
      ballX.value = CX;
      ballY.value = CY;
      vx.value = vx0;
      vy.value = vyd;
      p1x.value = inputX.value;
      p2x.value = CX;
      rally.value = 0;
      acc.value = 0;
      t0x.value = CX; t1x.value = CX; t2x.value = CX; t3x.value = CX; t4x.value = CX;
      t0y.value = CY; t1y.value = CY; t2y.value = CY; t3y.value = CY; t4y.value = CY;
      running.value = true;
    })(vyDir, vxr);
  };

  const stop = () => {
    frame.setActive(false);
    runOnUI(() => {
      'worklet';
      running.value = false;
    })();
  };

  const freezePose = () => {
    frame.setActive(false);
    runOnUI(() => {
      'worklet';
      running.value = false;
      ballX.value = 150; ballY.value = 560;
      p1x.value = 132; p2x.value = 250;
      t0x.value = 150; t1x.value = 176; t2x.value = 200; t3x.value = 222; t4x.value = 244;
      t0y.value = 560; t1y.value = 512; t2y.value = 470; t3y.value = 432; t4y.value = 398;
    })();
  };

  const getRally = () => rally.value;

  return { ballX, ballY, p1x, p2x, inputX, trailX, trailY, p1Hit, p2Hit, wallHit, rally, startCpu, stop, freezePose, getRally };
}
