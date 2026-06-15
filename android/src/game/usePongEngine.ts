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
  // 20 points → a long comet tail (~20 frames of travel behind the ball).
  const t0x = useSharedValue(CX);
  const t1x = useSharedValue(CX);
  const t2x = useSharedValue(CX);
  const t3x = useSharedValue(CX);
  const t4x = useSharedValue(CX);
  const t5x = useSharedValue(CX);
  const t6x = useSharedValue(CX);
  const t7x = useSharedValue(CX);
  const t8x = useSharedValue(CX);
  const t9x = useSharedValue(CX);
  const t10x = useSharedValue(CX);
  const t11x = useSharedValue(CX);
  const t12x = useSharedValue(CX);
  const t13x = useSharedValue(CX);
  const t14x = useSharedValue(CX);
  const t15x = useSharedValue(CX);
  const t16x = useSharedValue(CX);
  const t17x = useSharedValue(CX);
  const t18x = useSharedValue(CX);
  const t19x = useSharedValue(CX);
  const t0y = useSharedValue(CY);
  const t1y = useSharedValue(CY);
  const t2y = useSharedValue(CY);
  const t3y = useSharedValue(CY);
  const t4y = useSharedValue(CY);
  const t5y = useSharedValue(CY);
  const t6y = useSharedValue(CY);
  const t7y = useSharedValue(CY);
  const t8y = useSharedValue(CY);
  const t9y = useSharedValue(CY);
  const t10y = useSharedValue(CY);
  const t11y = useSharedValue(CY);
  const t12y = useSharedValue(CY);
  const t13y = useSharedValue(CY);
  const t14y = useSharedValue(CY);
  const t15y = useSharedValue(CY);
  const t16y = useSharedValue(CY);
  const t17y = useSharedValue(CY);
  const t18y = useSharedValue(CY);
  const t19y = useSharedValue(CY);
  const t20x = useSharedValue(CX);
  const t21x = useSharedValue(CX);
  const t22x = useSharedValue(CX);
  const t23x = useSharedValue(CX);
  const t24x = useSharedValue(CX);
  const t25x = useSharedValue(CX);
  const t26x = useSharedValue(CX);
  const t27x = useSharedValue(CX);
  const t28x = useSharedValue(CX);
  const t29x = useSharedValue(CX);
  const t30x = useSharedValue(CX);
  const t31x = useSharedValue(CX);
  const t20y = useSharedValue(CY);
  const t21y = useSharedValue(CY);
  const t22y = useSharedValue(CY);
  const t23y = useSharedValue(CY);
  const t24y = useSharedValue(CY);
  const t25y = useSharedValue(CY);
  const t26y = useSharedValue(CY);
  const t27y = useSharedValue(CY);
  const t28y = useSharedValue(CY);
  const t29y = useSharedValue(CY);
  const t30y = useSharedValue(CY);
  const t31y = useSharedValue(CY);
  // Arrays are built at render time only (for Skia's render map) — not captured by worklets.
  const trailX = [t0x, t1x, t2x, t3x, t4x, t5x, t6x, t7x, t8x, t9x, t10x, t11x, t12x, t13x, t14x, t15x, t16x, t17x, t18x, t19x, t20x, t21x, t22x, t23x, t24x, t25x, t26x, t27x, t28x, t29x, t30x, t31x];
  const trailY = [t0y, t1y, t2y, t3y, t4y, t5y, t6y, t7y, t8y, t9y, t10y, t11y, t12y, t13y, t14y, t15y, t16y, t17y, t18y, t19y, t20y, t21y, t22y, t23y, t24y, t25y, t26y, t27y, t28y, t29y, t30y, t31y];

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
    t31x.value = t30x.value;
    t31y.value = t30y.value;
    t30x.value = t29x.value;
    t30y.value = t29y.value;
    t29x.value = t28x.value;
    t29y.value = t28y.value;
    t28x.value = t27x.value;
    t28y.value = t27y.value;
    t27x.value = t26x.value;
    t27y.value = t26y.value;
    t26x.value = t25x.value;
    t26y.value = t25y.value;
    t25x.value = t24x.value;
    t25y.value = t24y.value;
    t24x.value = t23x.value;
    t24y.value = t23y.value;
    t23x.value = t22x.value;
    t23y.value = t22y.value;
    t22x.value = t21x.value;
    t22y.value = t21y.value;
    t21x.value = t20x.value;
    t21y.value = t20y.value;
    t20x.value = t19x.value;
    t20y.value = t19y.value;
    t19x.value = t18x.value;
    t19y.value = t18y.value;
    t18x.value = t17x.value;
    t18y.value = t17y.value;
    t17x.value = t16x.value;
    t17y.value = t16y.value;
    t16x.value = t15x.value;
    t16y.value = t15y.value;
    t15x.value = t14x.value;
    t15y.value = t14y.value;
    t14x.value = t13x.value;
    t14y.value = t13y.value;
    t13x.value = t12x.value;
    t13y.value = t12y.value;
    t12x.value = t11x.value;
    t12y.value = t11y.value;
    t11x.value = t10x.value;
    t11y.value = t10y.value;
    t10x.value = t9x.value;
    t10y.value = t9y.value;
    t9x.value = t8x.value;
    t9y.value = t8y.value;
    t8x.value = t7x.value;
    t8y.value = t7y.value;
    t7x.value = t6x.value;
    t7y.value = t6y.value;
    t6x.value = t5x.value;
    t6y.value = t5y.value;
    t5x.value = t4x.value;
    t5y.value = t4y.value;
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
      t5x.value = CX; t6x.value = CX; t7x.value = CX; t8x.value = CX; t9x.value = CX;
      t10x.value = CX; t11x.value = CX; t12x.value = CX; t13x.value = CX; t14x.value = CX;
      t15x.value = CX; t16x.value = CX; t17x.value = CX; t18x.value = CX; t19x.value = CX;
      t20x.value = CX; t21x.value = CX; t22x.value = CX; t23x.value = CX; t24x.value = CX;
      t25x.value = CX; t26x.value = CX; t27x.value = CX; t28x.value = CX; t29x.value = CX;
      t30x.value = CX; t31x.value = CX;
      t0y.value = CY; t1y.value = CY; t2y.value = CY; t3y.value = CY; t4y.value = CY;
      t5y.value = CY; t6y.value = CY; t7y.value = CY; t8y.value = CY; t9y.value = CY;
      t10y.value = CY; t11y.value = CY; t12y.value = CY; t13y.value = CY; t14y.value = CY;
      t15y.value = CY; t16y.value = CY; t17y.value = CY; t18y.value = CY; t19y.value = CY;
      t20y.value = CY; t21y.value = CY; t22y.value = CY; t23y.value = CY; t24y.value = CY;
      t25y.value = CY; t26y.value = CY; t27y.value = CY; t28y.value = CY; t29y.value = CY;
      t30y.value = CY; t31y.value = CY;
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
      ballX.value = 196; ballY.value = 300;
      p1x.value = 250; p2x.value = 196;
      t0x.value = 196; t1x.value = 193; t2x.value = 191; t3x.value = 188; t4x.value = 187;
      t5x.value = 185; t6x.value = 184; t7x.value = 183; t8x.value = 182; t9x.value = 182;
      t10x.value = 182; t11x.value = 182; t12x.value = 182; t13x.value = 183; t14x.value = 184;
      t15x.value = 186; t16x.value = 187; t17x.value = 189; t18x.value = 192; t19x.value = 194;
      t20x.value = 197; t21x.value = 201; t22x.value = 204; t23x.value = 208; t24x.value = 212;
      t25x.value = 217; t26x.value = 222; t27x.value = 227; t28x.value = 232; t29x.value = 238;
      t30x.value = 244; t31x.value = 250;
      t0y.value = 300; t1y.value = 311; t2y.value = 322; t3y.value = 333; t4y.value = 344;
      t5y.value = 355; t6y.value = 367; t7y.value = 378; t8y.value = 389; t9y.value = 401;
      t10y.value = 412; t11y.value = 423; t12y.value = 435; t13y.value = 446; t14y.value = 458;
      t15y.value = 470; t16y.value = 481; t17y.value = 493; t18y.value = 505; t19y.value = 517;
      t20y.value = 529; t21y.value = 540; t22y.value = 552; t23y.value = 564; t24y.value = 576;
      t25y.value = 589; t26y.value = 601; t27y.value = 613; t28y.value = 625; t29y.value = 637;
      t30y.value = 650; t31y.value = 662;
    })();
  };

  const getRally = () => rally.value;

  return { ballX, ballY, p1x, p2x, inputX, trailX, trailY, p1Hit, p2Hit, wallHit, rally, startCpu, stop, freezePose, getRally };
}
