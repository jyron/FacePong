// Networked renderer. Connects to a Colyseus room and turns authoritative state
// into the same CourtVisual SharedValues the local engine produces, so the same
// PongCourt/PlayScreen render online play unchanged.
//
// Netcode write discipline (identical to usePongEngine):
//   • The local paddle is client-predicted from inputX (no round-trip lag).
//   • Ball + opponent paddle are interpolated toward server targets on the UI
//     thread inside a frame callback.
//   • The 20Hz onStateChange handler (JS thread) marshals new targets to the UI
//     thread via runOnUI — never writes the rendered SharedValues directly.
// Canonical server frame is p1=bottom; a p2 client flips Y so it sees itself at
// the bottom. Locally the player is always p1 (cyan, bottom); opponent is p2.
import { useEffect, useRef, useState } from 'react';
import { useSharedValue, useFrameCallback, runOnUI } from 'react-native-reanimated';
import { BALL_R, COURT, WALL_PAD } from '../../shared/constants';
import type { CourtVisual } from '../game/usePongEngine';
import type { Phase } from '../../shared/protocol';
import type { Room } from './client';

const CX = COURT.W / 2;
const CY = COURT.H / 2;

export type NetStatus = 'connecting' | 'waiting' | 'live' | 'error';

export interface NetGame {
  visual: CourtVisual;
  status: NetStatus;
  phase: Phase;
  scores: { p1: number; p2: number }; // p1 = me (cyan), p2 = opponent (magenta)
  rally: number;
  topRally: number;
  countdown: number;
  scorerSlot: '' | 'p1' | 'p2'; // local frame: 'p1' = I scored
  winnerSlot: '' | 'p1' | 'p2';
  round: number;
  oppName: string;
  code: string;
  error: string;
  leave: () => void;
}

export function useNetGame(opts: {
  connect: () => Promise<Room>;
  myFaceDataUri: string | null;
  onOppFace: (dataUri: string) => void;
}): NetGame {
  const ballX = useSharedValue(CX);
  const ballY = useSharedValue(CY);
  const p1x = useSharedValue(CX);
  const p2x = useSharedValue(CX);
  const inputX = useSharedValue(CX);
  const tgtBallX = useSharedValue(CX);
  const tgtBallY = useSharedValue(CY);
  const tgtP2x = useSharedValue(CX);

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
  const trailX = [t0x, t1x, t2x, t3x, t4x];
  const trailY = [t0y, t1y, t2y, t3y, t4y];
  const p1Hit = useSharedValue(0);
  const p2Hit = useSharedValue(0);
  const wallHit = useSharedValue(0);
  const rallySV = useSharedValue(0);
  const inWallZone = useSharedValue(false);

  const mySlot = useRef<'p1' | 'p2'>('p1');
  const prevRally = useRef(0);
  const prevPhase = useRef<Phase>('waiting');
  const roomRef = useRef<Room | null>(null);
  const onOppFaceRef = useRef(opts.onOppFace);
  onOppFaceRef.current = opts.onOppFace;

  const [net, setNet] = useState<Omit<NetGame, 'visual' | 'leave'>>({
    status: 'connecting',
    phase: 'waiting',
    scores: { p1: 0, p2: 0 },
    rally: 0,
    topRally: 0,
    countdown: 0,
    scorerSlot: '',
    winnerSlot: '',
    round: 1,
    oppName: '',
    code: '',
    error: '',
  });

  useFrameCallback(() => {
    'worklet';
    p1x.value = inputX.value; // client-side prediction of my paddle
    p2x.value += (tgtP2x.value - p2x.value) * 0.35;
    ballX.value += (tgtBallX.value - ballX.value) * 0.4;
    ballY.value += (tgtBallY.value - ballY.value) * 0.4;
    // The server doesn't broadcast wall bounces, so detect them locally: the
    // interpolated ball entering a near-wall band counts once per visit.
    const nearWall =
      ballX.value < BALL_R + WALL_PAD + 12 || ballX.value > COURT.W - BALL_R - WALL_PAD - 12;
    if (nearWall && !inWallZone.value) wallHit.value += 1;
    inWallZone.value = nearWall;
    t4x.value = t3x.value; t4y.value = t3y.value;
    t3x.value = t2x.value; t3y.value = t2y.value;
    t2x.value = t1x.value; t2y.value = t1y.value;
    t1x.value = t0x.value; t1y.value = t0y.value;
    t0x.value = ballX.value; t0y.value = ballY.value;
  }, true);

  useEffect(() => {
    let active = true;
    let inputTimer: ReturnType<typeof setInterval> | undefined;
    let room: Room | null = null;

    (async () => {
      try {
        room = await opts.connect();
        if (!active) {
          room.leave();
          return;
        }
        roomRef.current = room;

        if (opts.myFaceDataUri) room.send('face', { data: opts.myFaceDataUri });
        room.onMessage('face', (m: { slot?: string; data?: string }) => {
          if (m?.data) onOppFaceRef.current(m.data);
        });

        room.onStateChange((state: any) => {
          const me = state.players.get(room!.sessionId);
          if (me) mySlot.current = me.slot;
          let opp: any;
          state.players.forEach((p: any) => {
            if (p.sessionId !== room!.sessionId) opp = p;
          });

          const flip = mySlot.current === 'p2';
          const bx = state.ballX;
          const by = flip ? COURT.H - state.ballY : state.ballY;
          const ox = opp ? opp.x : CX;
          // On a phase change the ball teleports server-side (e.g. back to
          // center for the countdown) — snap the rendered ball + trail there
          // instead of lerping it across the court, which read as a phantom
          // mid-court bounce.
          const snap = state.phase !== prevPhase.current;
          prevPhase.current = state.phase;
          runOnUI((bx2: number, by2: number, ox2: number, snap2: boolean) => {
            'worklet';
            tgtBallX.value = bx2;
            tgtBallY.value = by2;
            tgtP2x.value = ox2;
            if (snap2) {
              ballX.value = bx2;
              ballY.value = by2;
              t0x.value = bx2; t1x.value = bx2; t2x.value = bx2; t3x.value = bx2; t4x.value = bx2;
              t0y.value = by2; t1y.value = by2; t2y.value = by2; t3y.value = by2; t4y.value = by2;
              inWallZone.value = true; // re-arm wall blip detection quietly
            }
          })(bx, by, ox, snap);

          // A rally bump means a paddle just hit the ball. Pick the paddle by
          // which half it's in (by is already flipped to the local frame, where
          // my paddle is at the bottom) and pulse that hit counter.
          if (state.rally > prevRally.current) {
            const bottom = by >= CY;
            runOnUI((b: boolean, bx2: number, by2: number) => {
              'worklet';
              if (b) p1Hit.value += 1;
              else p2Hit.value += 1;
              // Snap the rendered ball to the post-bounce server position: the
              // lerp trails the target by a few frames, and across a velocity
              // reversal that trailing rounds the corner — the ball visibly
              // mushes into the paddle instead of bouncing crisply. The hit's
              // pop/ring/confetti land on the same frame, masking the snap.
              ballX.value = bx2;
              ballY.value = by2;
            })(bottom, bx, by);
          }
          prevRally.current = state.rally;
          runOnUI((r: number) => {
            'worklet';
            rallySV.value = r;
          })(state.rally);

          const meScore = me ? me.score : 0;
          const oppScore = opp ? opp.score : 0;
          const toLocal = (slot: string): '' | 'p1' | 'p2' =>
            slot ? (slot === mySlot.current ? 'p1' : 'p2') : '';

          setNet({
            status: state.players.size < 2 ? 'waiting' : 'live',
            phase: state.phase as Phase,
            scores: { p1: meScore, p2: oppScore },
            rally: state.rally,
            topRally: state.topRally,
            countdown: state.countdown,
            scorerSlot: toLocal(state.scorerSlot),
            winnerSlot: toLocal(state.winnerSlot),
            round: state.round,
            oppName: opp ? opp.name : '',
            code: state.code,
            error: '',
          });
        });

        room.onLeave(() => {
          if (active) setNet((n) => ({ ...n, status: 'error', error: 'Disconnected' }));
        });

        // 60Hz to match the server tick: the server bounces the ball off ITS
        // copy of the paddle, so stale input makes contact look offset from
        // the locally-predicted (instant) paddle.
        inputTimer = setInterval(() => {
          roomRef.current?.send('input', { x: inputX.value });
        }, 1000 / 60);
      } catch (e: any) {
        if (active) setNet((n) => ({ ...n, status: 'error', error: e?.message || 'Could not connect' }));
      }
    })();

    return () => {
      active = false;
      if (inputTimer) clearInterval(inputTimer);
      roomRef.current?.leave();
      roomRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return {
    visual: { ballX, ballY, p1x, p2x, inputX, trailX, trailY, p1Hit, p2Hit, wallHit, rally: rallySV },
    ...net,
    leave: () => roomRef.current?.leave(),
  };
}
