import React, { useEffect, useRef } from 'react';
import { StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { sfx } from '../sfx/sfx';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { PongCourt } from '../game/PongCourt';
import { FaceCoin } from '../components/FaceCoin';
import { ScoreChip } from '../components/ScoreChip';
import { Confetti } from '../components/Confetti';
import { NeonButton } from '../components/NeonButton';
import { useFaces } from '../faces/FaceStore';
import { C, FONT } from '../theme/tokens';
import { COURT, type Slot } from '../../shared/constants';
import type { PongEngine } from '../game/usePongEngine';

const NAME: Record<Slot, string> = { p1: 'YOU', p2: '' };

// Point-won overlay over a frozen court.
export function PointScreen({
  engine,
  scorer,
  scorerName,
  scores,
  matchPointNext,
  onNext,
  onSkipToMatch,
  autoNextMs,
}: {
  engine: PongEngine;
  scorer: Slot;
  scorerName: string;
  scores: { p1: number; p2: number };
  matchPointNext: boolean;
  onNext: () => void;
  onSkipToMatch: () => void;
  autoNextMs?: number; // solo flow: auto-advance to keep the loop tight
}) {
  const { faces } = useFaces();
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const scale = Math.min(width / COURT.W, height / COURT.H);
  const isCyan = scorer === 'p1';
  const name = scorer === 'p1' ? NAME.p1 : scorerName;

  useEffect(() => {
    sfx.point(isCyan);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Auto-advance (CPU mode) — the button stays as a "skip the wait" tap.
  const onNextRef = useRef(onNext);
  onNextRef.current = onNext;
  useEffect(() => {
    if (!autoNextMs) return;
    const id = setTimeout(() => onNextRef.current(), autoNextMs);
    return () => clearTimeout(id);
  }, [autoNextMs]);

  return (
    <View style={styles.root}>
      <View style={[styles.courtWrap, { width: COURT.W * scale, height: COURT.H * scale }]}>
        <PongCourt engine={engine} faces={faces} scale={scale} interactive={false} />
      </View>

      {isCyan && <Confetti width={width} height={height} />}

      <View style={[styles.overlay, { paddingTop: insets.top, paddingBottom: insets.bottom }]}>
        <Text style={[styles.point, !isCyan && styles.pointLost]}>{isCyan ? 'POINT!' : 'OUCH!'}</Text>
        <View style={styles.by}>
          <FaceCoin slot={scorer} size={56} uri={faces[scorer]} />
          <Text style={[styles.name, { color: isCyan ? C.cyan : C.magenta, textShadowColor: isCyan ? 'rgba(25,231,255,0.55)' : 'rgba(255,46,136,0.55)' }]}>{name}</Text>
          <Text style={styles.delta}>+1</Text>
        </View>

        <View style={styles.scoreRow}>
          <FaceCoin slot="p1" size={34} uri={faces.p1} ringWidth={2} />
          <ScoreChip p1={scores.p1} p2={scores.p2} size={34} />
          <FaceCoin slot="p2" size={34} uri={faces.p2} ringWidth={2} />
        </View>

        <Text style={styles.foot}>{matchPointNext ? 'Match point next' : `${name} serves next`}</Text>

        <View style={styles.actions}>
          <NeonButton label="NEXT POINT" variant="cyan" onPress={onNext} />
          <NeonButton label="JUMP TO MATCH END" variant="ghost" small onPress={onSkipToMatch} />
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg, alignItems: 'center', justifyContent: 'center' },
  courtWrap: { overflow: 'hidden' },
  overlay: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(7,7,15,0.62)', alignItems: 'center', justifyContent: 'center', paddingHorizontal: 30 },
  point: { fontFamily: FONT.display, fontSize: 64, color: C.lime, textShadowColor: 'rgba(212,255,61,0.5)', textShadowRadius: 18, textShadowOffset: { width: 0, height: 0 } },
  pointLost: { color: C.magenta, textShadowColor: 'rgba(255,46,136,0.5)' },
  by: { flexDirection: 'row', alignItems: 'center', gap: 12, marginTop: 16 },
  name: { fontFamily: FONT.bodyBold, fontSize: 16, textShadowRadius: 16, textShadowOffset: { width: 0, height: 0 } },
  delta: { fontFamily: FONT.display, color: C.lime, fontSize: 18 },
  scoreRow: { flexDirection: 'row', alignItems: 'center', gap: 12, marginTop: 26 },
  foot: { fontFamily: FONT.body, color: C.inkDim, fontSize: 13, marginTop: 24 },
  actions: { width: '100%', marginTop: 30, gap: 11 },
});
