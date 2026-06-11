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

const TRAIL_OPACITY = [0.22, 0.17, 0.12, 0.08, 0.05];

// Stable JS-side dispatchers for runOnJS (module scope = same reference every
// render, so the worklet reactions never rebuild).
const paddleSfx = (slot: 'p1' | 'p2', rally: number) => sfx.paddle(slot, rally);
const wallSfx = () => sfx.wall();

// The "pop" a face does when it strikes the ball: a fast punch to 1, then an
// underdamped spring back to 0 that overshoots — the overshoot is the jiggle.
function popAnim() {
  'worklet';
  return withSequence(
    withTiming(1, { duration: 55 }),
    withSpring(0, { damping: 8, stiffness: 240, mass: 0.55 }),
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
  // Impact rings, one per paddle: t runs 0→1, x/y freeze at the contact point.
  const r1T = useSharedValue(1);
  const r1X = useSharedValue(0);
  const r2T = useSharedValue(1);
  const r2X = useSharedValue(0);

  useAnimatedReaction(
    () => p1Hit.value,
    (cur, prev) => {
      if (prev != null && cur > prev) {
        p1Pop.value = popAnim();
        pulse.value = pulseAnim();
        r1X.value = ballX.value;
        r1T.value = 0;
        r1T.value = withTiming(1, { duration: 380, easing: Easing.out(Easing.cubic) });
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
        r2X.value = ballX.value;
        r2T.value = 0;
        r2T.value = withTiming(1, { duration: 380, easing: Easing.out(Easing.cubic) });
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

            {trailX.map((tx, i) => (
              <Circle key={i} cx={tx} cy={trailY[i]} r={BALL_R} color={heat} opacity={TRAIL_OPACITY[i]}>
                <BlurMask blur={5} style="normal" />
              </Circle>
            ))}

            <Circle cx={ballX} cy={ballY} r={glowR} color={heat} opacity={0.6}>
              <BlurMask blur={10} style="normal" />
            </Circle>
            <Circle cx={ballX} cy={ballY} r={ballR} color={heat} />
            <Circle cx={hlX} cy={hlY} r={3.5} color="#ffffff" />

            <Circle cx={r2X} cy={TOP_Y + PADDLE_R} r={r2R} color={C.magenta} style="stroke" strokeWidth={r2W} opacity={r2O} />
            <Circle cx={r1X} cy={BOT_Y - PADDLE_R} r={r1R} color={C.cyan} style="stroke" strokeWidth={r1W} opacity={r1O} />

            <FacePaddle uri={faces.p2} slot="p2" x={p2x} y={TOP_Y} size={PADDLE} pop={p2Pop} />
            <FacePaddle uri={faces.p1} slot="p1" x={p1x} y={BOT_Y} size={PADDLE} pop={p1Pop} />
          </Group>
        </Canvas>
      </View>
    </GestureDetector>
  );
}

const styles = StyleSheet.create({
  root: { position: 'relative', overflow: 'hidden' },
});
