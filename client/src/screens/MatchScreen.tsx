import React, { useEffect, useRef } from 'react';
import { Animated, Easing, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { FaceCoin } from '../components/FaceCoin';
import { ScoreChip } from '../components/ScoreChip';
import { NeonButton } from '../components/NeonButton';
import { ArcadeBg } from '../components/ArcadeBg';
import { Confetti } from '../components/Confetti';
import { sfx } from '../sfx/sfx';
import { useFaces } from '../faces/FaceStore';
import { C, FONT } from '../theme/tokens';
import type { Slot } from '../../shared/constants';

export function MatchScreen({
  winner,
  winnerName,
  scores,
  stats,
  onShare,
  onRematch,
  onHome,
}: {
  winner: Slot;
  winnerName: string;
  scores: { p1: number; p2: number };
  stats: { topRally: number; aces: number; time: string };
  onShare: () => void;
  onRematch: () => void;
  onHome: () => void;
}) {
  const { faces } = useFaces();
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const spin = useRef(new Animated.Value(0)).current;
  const isCyan = winner === 'p1';

  useEffect(() => {
    Animated.loop(Animated.timing(spin, { toValue: 1, duration: 14000, easing: Easing.linear, useNativeDriver: true })).start();
  }, [spin]);

  useEffect(() => {
    if (isCyan) sfx.fanfare();
    else sfx.point(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  const rotate = spin.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '360deg'] });

  return (
    <View style={styles.root}>
      <ArcadeBg width={width} height={height} />
      {isCyan && <Confetti width={width} height={height} />}
      <View style={[styles.content, { paddingTop: insets.top + 16, paddingBottom: insets.bottom + 16 }]}>
        <Text style={styles.crown}>👑</Text>
        <Text style={styles.game}>GAME!</Text>

        <View style={styles.coinWrap}>
          <Animated.View style={[styles.ray, { transform: [{ rotate }] }]} />
          <FaceCoin slot={winner} size={132} uri={faces[winner]} />
        </View>
        <Text style={[styles.winName, { color: isCyan ? C.cyan : C.magenta, textShadowColor: isCyan ? 'rgba(25,231,255,0.55)' : 'rgba(255,46,136,0.55)' }]}>
          {winnerName} WINS
        </Text>

        <View style={styles.score}>
          <ScoreChip p1={scores.p1} p2={scores.p2} size={40} reversed={!isCyan} />
        </View>

        <View style={styles.stats}>
          <Stat v={String(stats.topRally)} k="Top Rally" color={C.lime} />
          <Stat v={String(stats.aces)} k="Aces" color={C.cyan} />
          <Stat v={stats.time} k="Time" color={C.amber} />
        </View>

        <View style={styles.actions}>
          <NeonButton label="SHARE THE WIN" variant="lime" onPress={onShare} />
          <NeonButton label="REMATCH" variant="cyan" onPress={onRematch} />
          <NeonButton label="MAIN MENU" variant="ghost" onPress={onHome} />
        </View>
      </View>
    </View>
  );
}

function Stat({ v, k, color }: { v: string; k: string; color: string }) {
  return (
    <View style={styles.stat}>
      <Text style={[styles.statV, { color }]}>{v}</Text>
      <Text style={styles.statK}>{k}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg },
  content: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 28 },
  crown: { fontSize: 40, marginBottom: 4 },
  game: { fontFamily: FONT.display, fontSize: 44, color: C.lime, textShadowColor: 'rgba(212,255,61,0.5)', textShadowRadius: 18, textShadowOffset: { width: 0, height: 0 } },
  coinWrap: { marginVertical: 22, alignItems: 'center', justifyContent: 'center' },
  ray: { position: 'absolute', width: 210, height: 210, borderRadius: 105, borderWidth: 2, borderColor: 'rgba(255,176,46,0.22)', borderStyle: 'dashed' },
  winName: { fontFamily: FONT.display, fontSize: 22, marginTop: 8, textShadowRadius: 16, textShadowOffset: { width: 0, height: 0 } },
  score: { marginVertical: 14 },
  stats: { flexDirection: 'row', gap: 10, marginVertical: 18 },
  stat: { flex: 1, maxWidth: 100, backgroundColor: 'rgba(255,255,255,0.04)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)', borderRadius: 14, paddingVertical: 12, alignItems: 'center' },
  statV: { fontFamily: FONT.display, fontSize: 20 },
  statK: { fontFamily: FONT.body, fontSize: 10, letterSpacing: 1, color: C.inkFaint, marginTop: 4, textTransform: 'uppercase' },
  actions: { width: '100%', gap: 11 },
});
