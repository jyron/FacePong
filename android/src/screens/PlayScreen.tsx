import React, { useEffect, useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import Animated, { FadeOut, ZoomIn } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { sfx } from '../sfx/sfx';
import { PongCourt } from '../game/PongCourt';
import { FaceCoin } from '../components/FaceCoin';
import { ScoreChip } from '../components/ScoreChip';
import { useFaces, type Faces } from '../faces/FaceStore';
import { C, FONT } from '../theme/tokens';
import { COURT } from '../../shared/constants';
import type { CourtVisual } from '../game/usePongEngine';

const P1 = 'YOU';

export function PlayScreen({
  engine,
  faces: facesProp,
  scores,
  round,
  rally,
  opponentName,
  onQuit,
}: {
  engine: CourtVisual;
  // Online play passes its own faces (p2 = the remote opponent's face); local
  // CPU play falls back to the persistent FaceStore pair.
  faces?: Faces;
  scores: { p1: number; p2: number };
  round: number;
  rally: number;
  opponentName: string;
  onQuit: () => void;
}) {
  const { faces: storeFaces } = useFaces();
  const faces = facesProp ?? storeFaces;
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const scale = Math.min(width / COURT.W, height / COURT.H);
  const courtW = COURT.W * scale;
  const courtH = COURT.H * scale;

  // Celebrate every 5th rally with a flash badge + coin sound. The badge keys
  // off the milestone value so each one re-mounts (replaying the zoom-in).
  const [milestone, setMilestone] = useState(0);
  const lastMilestone = useRef(0);
  useEffect(() => {
    if (rally === 0) lastMilestone.current = 0;
    if (rally > 0 && rally % 5 === 0 && rally !== lastMilestone.current) {
      lastMilestone.current = rally;
      setMilestone(rally);
      sfx.milestone();
    }
  }, [rally]);
  useEffect(() => {
    if (!milestone) return;
    const id = setTimeout(() => setMilestone(0), 1100);
    return () => clearTimeout(id);
  }, [milestone]);
  const milestoneColor = milestone >= 15 ? '#ff4d2e' : milestone >= 10 ? C.amber : C.lime;

  return (
    <View style={styles.root}>
      <View style={[styles.courtWrap, { width: courtW, height: courtH }]}>
        <PongCourt engine={engine} faces={faces} scale={scale} interactive />
      </View>

      <View style={styles.watermark} pointerEvents="none">
        <Text style={styles.wmNum}>{String(rally).padStart(2, '0')}</Text>
        <Text style={styles.wmLabel}>RALLY</Text>
      </View>

      <View style={[styles.hud, { top: insets.top + 8 }]} pointerEvents="none">
        <View style={styles.side}>
          <FaceCoin slot="p2" size={30} uri={faces.p2} ringWidth={2} />
          <Text style={styles.nm}>{opponentName}</Text>
        </View>
        <ScoreChip p1={scores.p1} p2={scores.p2} size={28} reversed />
        <View style={styles.side}>
          <Text style={styles.nm}>{P1}</Text>
          <FaceCoin slot="p1" size={30} uri={faces.p1} ringWidth={2} />
        </View>
      </View>

      <View style={[styles.serveTag, { top: insets.top + 52 }]} pointerEvents="none">
        <Text style={styles.serveText}>{rally > 1 ? `RALLY · ${rally}` : `ROUND ${round} · FACE-OFF`}</Text>
      </View>

      {milestone > 0 && (
        <Animated.View
          key={milestone}
          entering={ZoomIn.springify().damping(11).stiffness(220)}
          exiting={FadeOut.duration(250)}
          style={styles.milestone}
          pointerEvents="none"
        >
          <Text style={[styles.milestoneText, { color: milestoneColor, textShadowColor: milestoneColor }]}>
            RALLY x{milestone}
          </Text>
        </Animated.View>
      )}

      <Pressable style={[styles.quit, { top: insets.top + 6 }]} onPress={onQuit} hitSlop={12}>
        <Text style={styles.quitText}>✕</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg, alignItems: 'center', justifyContent: 'center' },
  courtWrap: { overflow: 'hidden' },
  watermark: { position: 'absolute', top: '46%', alignItems: 'center' },
  wmNum: { fontFamily: FONT.display, fontSize: 64, color: 'rgba(255,255,255,0.05)' },
  wmLabel: { fontFamily: FONT.bodyBold, fontSize: 11, letterSpacing: 4, color: 'rgba(255,255,255,0.08)' },
  hud: { position: 'absolute', left: 0, right: 0, paddingHorizontal: 20, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  side: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  nm: { fontFamily: FONT.bodyBold, fontSize: 12, color: C.inkDim },
  serveTag: { position: 'absolute', alignSelf: 'center', borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)', backgroundColor: 'rgba(255,255,255,0.03)', borderRadius: 999, paddingHorizontal: 12, paddingVertical: 5 },
  milestone: { position: 'absolute', top: '36%', alignSelf: 'center' },
  milestoneText: { fontFamily: FONT.display, fontSize: 34, letterSpacing: 1, textShadowRadius: 22, textShadowOffset: { width: 0, height: 0 } },
  serveText: { fontFamily: FONT.bodyBold, color: C.inkDim, fontSize: 10.5, letterSpacing: 1.2 },
  quit: { position: 'absolute', right: 16, width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center', backgroundColor: 'rgba(255,255,255,0.06)' },
  quitText: { color: C.inkDim, fontSize: 16, fontFamily: FONT.bodyBold },
});
