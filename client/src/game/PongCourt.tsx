// Renders the pong court entirely in Skia: court lines, ball + trail, and the
// two face paddles as deformable triangle meshes (FacePaddle) so each face's
// outline squashes and wobbles when it strikes the ball. A pan gesture drives
// the local paddle.
//
// Game feel ("juice") also lives here, all driven by the engine's monotonic
// hit counters so it works identically for CPU and online play:
//   • paddle hit → face pop, expanding impact ring at the contact point, ball
//     squash-pulse, sound + haptic, and (deeper in a rally) a screen shake
//     that grows with the rally
//   • wall bounce → ball pulse + knock sound
//   • the ball and its trail "heat up" from lime → amber → red as the rally
//     gets longer, matching the speed ramp in the engine
//
// IMPORTANT: worklets (useDerivedValue / Skia animated props) must capture the
// individual SharedValues directly — never the parent `engine` object, or
// Reanimated freezes it and JS-thread writes stop propagating.
import React from 'react';
import { StyleSheet, View } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import {
  Easing,
  interpolateColor,
  runOnJS,
  useAnimatedReaction,
  useDerivedValue,
  useSharedValue,
  withSequence,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { Canvas, Group, Circle, BlurMask, Line, vec } from '@shopify/react-native-skia';
import { COURT, BALL_R, PADDLE, PADDLE_R, PADDLE_MARGIN, TOP_Y, BOT_Y } from '../../shared/constants';
import { C } from '../theme/tokens';
import { sfx } from '../sfx/sfx';
import { FacePaddle } from './FacePaddle';
import type { CourtVisual } from './usePongEngine';
import type { Faces } from '../faces/FaceStore';

// Comet streak behind the ball (the look from the store promos): two dots are
// interpolated onto every trail segment, tapering in radius and opacity from
// ball-sized at the head down to a speck, so the tail reads as one continuous
// streak that curves through bounces instead of a row of separate blobs.
// Dots animate NUMBER props only (cx/cy/r) — the one Skia+Reanimated pattern
// this app has verified in release builds; object-valued animated props
// (Line p1/p2 points) silently failed to render on device.
const TRAIL_R = [10.5, 10.0, 9.6, 9.1, 8.7, 8.2, 7.8, 7.3, 6.8, 6.4, 5.9, 5.5, 5.0, 4.6, 4.1, 3.6, 3.2, 2.7, 2.3, 1.8];
const TRAIL_O = [0.5, 0.46, 0.43, 0.39, 0.36, 0.33, 0.29, 0.26, 0.23, 0.2, 0.18, 0.15, 0.13, 0.1, 0.08, 0.06, 0.045, 0.03, 0.03, 0.03];

// One streak dot at fraction `f` between two trail points. Endpoint
// SharedValues are passed individually so the derived values capture them
// directly (see worklet note at the top). `flare` (0 at rest, pulsed to 1 on a
// paddle hit) fattens every dot and brightens the whole comet, so the streak
// visibly flares the instant the ball is struck.
function TrailDot({
  ax,
  ay,
  bx,
  by,
  f,
  r,
  o,
  blur,
  color,
  flare,
}: {
  ax: { value: number };
  ay: { value: number };
  bx: { value: number };
  by: { value: number };
  f: number;
  r: number;
  o: number;
  blur: boolean;
  color: { value: string } | string;
  flare: { value: number };
}) {
  const cx = useDerivedValue(() => ax.value + (bx.value - ax.value) * f);
  const cy = useDerivedValue(() => ay.value + (by.value - ay.value) * f);
  const cr = useDerivedValue(() => r * (1 + flare.value * 0.75));
  const co = useDerivedValue(() => Math.min(0.95, o * (1 + flare.value * 2.6)));
  return (
    <Circle cx={cx} cy={cy} r={cr} color={color} opacity={co}>
      {blur ? <BlurMask blur={4} style="normal" /> : null}
    </Circle>
  );
}

// Confetti splash on paddle hits: per-burst particle palette (indexes double
// as the per-particle pseudo-random stream id).
const SPLASH_COLORS = [C.cyan, C.magenta, C.lime, C.amber, '#ffffff', C.lime, C.magenta, C.cyan];

// Deterministic per-particle pseudo-random in [0,1) from (seed, particle, k).
function splashRnd(seed: number, i: number, k: number) {
  'worklet';
  const v = Math.sin(seed * 12.9898 + i * 78.233 + k * 37.719) * 43758.5453;
  return v - Math.floor(v);
}

// One confetti particle of a paddle-hit burst. t runs 0→1 (linear); position
// eases out along a randomized direction away from the paddle face, with a
// little gravity so the burst reads as confetti, not just sparks.
function SplashDot({
  t,
  x,
  y,
  seed,
  dir,
  i,
  color,
}: {
  t: { value: number };
  x: { value: number };
  y: number;
  seed: { value: number };
  dir: 1 | -1; // -1: burst flies up (bottom paddle), 1: flies down (top paddle)
  i: number;
  color: string;
}) {
  const cx = useDerivedValue(() => {
    const e = 1 - (1 - t.value) ** 3;
    const a = dir * (Math.PI / 2) + (splashRnd(seed.value, i, 1) - 0.5) * 2.4;
    return x.value + Math.cos(a) * (34 + splashRnd(seed.value, i, 2) * 52) * e;
  });
  const cy = useDerivedValue(() => {
    const e = 1 - (1 - t.value) ** 3;
    const a = dir * (Math.PI / 2) + (splashRnd(seed.value, i, 1) - 0.5) * 2.4;
    return y + Math.sin(a) * (34 + splashRnd(seed.value, i, 2) * 52) * e + 26 * t.value * t.value;
  });
  const r = useDerivedValue(() => (2.1 + splashRnd(seed.value, i, 3) * 1.9) * (1 - t.value * 0.45));
  const o = useDerivedValue(() => (t.value >= 1 ? 0 : 0.95 * (1 - t.value)));
  return <Circle cx={cx} cy={cy} r={r} color={color} opacity={o} />;
}

// Stable JS-side dispatchers for runOnJS (module scope = same reference every
// render, so the worklet reactions never rebuild).
const paddleSfx = (slot: 'p1' | 'p2', rally: number) => sfx.paddle(slot, rally);
const wallSfx = () => sfx.wall();

// The "pop" a face does when it strikes the ball: a near-instant punch to 1,
// then a loosely-damped spring back to 0 that overshoots hard through zero —
// the overshoot (negative pop) is what makes the face rebound the opposite way
// and wobble a couple of times before settling. Low damping = big jiggle.
function popAnim() {
  'worklet';
  return withSequence(
    withTiming(1, { duration: 40 }),
    withSpring(0, { damping: 6, stiffness: 240, mass: 0.6 }),
  );
}

// Quick squash-pulse for the ball on any impact.
function pulseAnim() {
  'worklet';
  return withSequence(withTiming(1, { duration: 40 }), withTiming(0, { duration: 200 }));
}

export function PongCourt({
  engine,
  faces,
  scale,
  interactive,
}: {
  engine: CourtVisual;
  faces: Faces;
  scale: number;
  interactive: boolean;
}) {
  const W = COURT.W * scale;
  const H = COURT.H * scale;

  // Destructure the live shared values so worklets capture them directly.
  const { ballX, ballY, p1x, p2x, trailX, trailY, inputX, p1Hit, p2Hit, wallHit, rally } = engine;
  const lo = PADDLE_MARGIN;
  const hi = COURT.W - PADDLE_MARGIN;

  // View-local 0→1 "pop" amounts, fired by the engine's monotonic hit counters.
  const p1Pop = useSharedValue(0);
  const p2Pop = useSharedValue(0);
  // Ball squash-pulse (any impact) and screen-shake amplitude (court px).
  const pulse = useSharedValue(0);
  const shake = useSharedValue(0);
  // Comet-trail flare: pulsed to 1 on a paddle hit, decays to 0 — fattens and
  // brightens the whole streak so it reads as a speed burst off the paddle.
  const trailFlare = useSharedValue(0);
  // Impact rings, one per paddle: t runs 0→1, x/y freeze at the contact point.
  const r1T = useSharedValue(1);
  const r1X = useSharedValue(0);
  const r2T = useSharedValue(1);
  const r2X = useSharedValue(0);
  // Confetti splash per paddle: linear 0→1 progress + a reroll seed per burst.
  const s1T = useSharedValue(1);
  const s1Seed = useSharedValue(1);
  const s2T = useSharedValue(1);
  const s2Seed = useSharedValue(2);

  useAnimatedReaction(
    () => p1Hit.value,
    (cur, prev) => {
      if (prev != null && cur > prev) {
        p1Pop.value = popAnim();
        pulse.value = pulseAnim();
        trailFlare.value = 1;
        trailFlare.value = withTiming(0, { duration: 320, easing: Easing.out(Easing.cubic) });
        r1X.value = ballX.value;
        r1T.value = 0;
        r1T.value = withTiming(1, { duration: 380, easing: Easing.out(Easing.cubic) });
        s1Seed.value = cur; // monotonic counter = fresh particle pattern per hit
        s1T.value = 0;
        s1T.value = withTiming(1, { duration: 620 });
        if (rally.value >= 4) {
          shake.value = Math.min(2 + rally.value * 0.2, 5.5);
          shake.value = withTiming(0, { duration: 280 });
        }
        runOnJS(paddleSfx)('p1', rally.value);
      }
    },
  );
  useAnimatedReaction(
    () => p2Hit.value,
    (cur, prev) => {
      if (prev != null && cur > prev) {
        p2Pop.value = popAnim();
        pulse.value = pulseAnim();
        trailFlare.value = 1;
        trailFlare.value = withTiming(0, { duration: 320, easing: Easing.out(Easing.cubic) });
        r2X.value = ballX.value;
        r2T.value = 0;
        r2T.value = withTiming(1, { duration: 380, easing: Easing.out(Easing.cubic) });
        s2Seed.value = cur + 0.5; // offset so p1/p2 bursts never share a pattern
        s2T.value = 0;
        s2T.value = withTiming(1, { duration: 620 });
        if (rally.value >= 4) {
          shake.value = Math.min(2 + rally.value * 0.2, 5.5);
          shake.value = withTiming(0, { duration: 280 });
        }
        runOnJS(paddleSfx)('p2', rally.value);
      }
    },
  );
  useAnimatedReaction(
    () => wallHit.value,
    (cur, prev) => {
      if (prev != null && cur > prev) {
        pulse.value = pulseAnim();
        runOnJS(wallSfx)();
      }
    },
  );

  const setInput = (x: number) => {
    'worklet';
    const cx = x / scale;
    inputX.value = cx < lo ? lo : cx > hi ? hi : cx;
  };
  const pan = Gesture.Pan()
    .enabled(interactive)
    .onBegin((e) => setInput(e.x))
    .onUpdate((e) => setInput(e.x));

  // Rally heat: ball + trail shift lime → amber → red as the rally climbs,
  // in step with the engine's speed ramp.
  const heat = useDerivedValue(() =>
    interpolateColor(Math.min(rally.value, 14), [0, 7, 14], [C.lime, C.amber, '#ff4d2e']),
  );

  // Court shake: a decaying amplitude wiggled through sin so it oscillates as
  // it dies out. Applied in screen px, before the court-unit scale.
  const courtTransform = useDerivedValue(() => [
    { translateX: Math.sin(shake.value * 47) * shake.value * scale },
    { translateY: Math.cos(shake.value * 31) * shake.value * 0.6 * scale },
    { scale },
  ]);

  const ballR = useDerivedValue(() => BALL_R * (1 + pulse.value * 0.5));
  const glowR = useDerivedValue(() => (BALL_R + 3) * (1 + pulse.value * 0.8));
  const hlX = useDerivedValue(() => ballX.value - 3.5);
  const hlY = useDerivedValue(() => ballY.value - 3.5);

  // Impact rings expand + thin out + fade as t runs 0→1 (invisible at rest).
  const r1R = useDerivedValue(() => 14 + r1T.value * 64);
  const r1W = useDerivedValue(() => 0.5 + 3.5 * (1 - r1T.value));
  const r1O = useDerivedValue(() => 0.85 * (1 - r1T.value));
  const r2R = useDerivedValue(() => 14 + r2T.value * 64);
  const r2W = useDerivedValue(() => 0.5 + 3.5 * (1 - r2T.value));
  const r2O = useDerivedValue(() => 0.85 * (1 - r2T.value));

  return (
    <GestureDetector gesture={pan}>
      <View style={[styles.root, { width: W, height: H }]}>
        <Canvas style={{ width: W, height: H }}>
          <Group transform={courtTransform}>
            <Line p1={vec(COURT.W * 0.08, COURT.H / 2)} p2={vec(COURT.W * 0.92, COURT.H / 2)} color="rgba(255,255,255,0.12)" style="stroke" strokeWidth={2} />
            <Circle cx={COURT.W / 2} cy={COURT.H / 2} r={48} color="rgba(255,255,255,0.10)" style="stroke" strokeWidth={2} />

            {trailX.map((tx, i) =>
              [0.5, 1].map((f, half) => (
                <TrailDot
                  key={`${i}-${half}`}
                  ax={i === 0 ? ballX : trailX[i - 1]}
                  ay={i === 0 ? ballY : trailY[i - 1]}
                  bx={tx}
                  by={trailY[i]}
                  f={f}
                  r={TRAIL_R[i * 2 + half]}
                  o={TRAIL_O[i * 2 + half]}
                  blur={i * 2 + half < 6}
                  color={heat}
                  flare={trailFlare}
                />
              )),
            )}

            <Circle cx={ballX} cy={ballY} r={glowR} color={heat} opacity={0.6}>
              <BlurMask blur={10} style="normal" />
            </Circle>
            <Circle cx={ballX} cy={ballY} r={ballR} color={heat} />
            <Circle cx={hlX} cy={hlY} r={3.5} color="#ffffff" />

            <Circle cx={r2X} cy={TOP_Y + PADDLE_R} r={r2R} color={C.magenta} style="stroke" strokeWidth={r2W} opacity={r2O} />
            <Circle cx={r1X} cy={BOT_Y - PADDLE_R} r={r1R} color={C.cyan} style="stroke" strokeWidth={r1W} opacity={r1O} />

            <FacePaddle uri={faces.p2} slot="p2" x={p2x} y={TOP_Y} size={PADDLE} pop={p2Pop} />
            <FacePaddle uri={faces.p1} slot="p1" x={p1x} y={BOT_Y} size={PADDLE} pop={p1Pop} />

            {SPLASH_COLORS.map((c, i) => (
              <SplashDot key={`s2-${i}`} t={s2T} x={r2X} y={TOP_Y + PADDLE_R} seed={s2Seed} dir={1} i={i} color={c} />
            ))}
            {SPLASH_COLORS.map((c, i) => (
              <SplashDot key={`s1-${i}`} t={s1T} x={r1X} y={BOT_Y - PADDLE_R} seed={s1Seed} dir={-1} i={i} color={c} />
            ))}
          </Group>
        </Canvas>
      </View>
    </GestureDetector>
  );
}

const styles = StyleSheet.create({
  root: { position: 'relative', overflow: 'hidden' },
});
