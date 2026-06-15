import React, { useEffect } from 'react';
import { StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { HeroFace } from '../components/HeroFace';
import { NeonButton } from '../components/NeonButton';
import { ArcadeBg } from '../components/ArcadeBg';
import { chooseFaceSource } from '../faces/pickFace';
import { useFaces } from '../faces/FaceStore';
import { C, FONT } from '../theme/tokens';
import type { Mode } from '../../shared/protocol';

export function StartScreen({ best, onMode }: { best: number; onMode: (m: Mode) => void }) {
  const { faces, setFace } = useFaces();
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const [busy, setBusy] = React.useState<'p1' | 'p2' | null>(null);

  const pick = (who: 'p1' | 'p2') =>
    chooseFaceSource(
      (uri) => {
        if (uri) setFace(who, uri);
        setBusy(null);
      },
      () => setBusy(who),
    );

  return (
    <View style={styles.root}>
      <ArcadeBg width={width} height={height} />
      <View style={[styles.content, { paddingTop: insets.top + 30, paddingBottom: insets.bottom + 24 }]}>
        <View style={styles.brand}>
          <Text style={[styles.word, styles.face]}>FACE</Text>
          <Text style={[styles.word, styles.pong]}>PONG</Text>
        </View>
        <View style={styles.tag}>
          <Text style={styles.tagText}>🏓 BEST OF 5 · YOUR FACE IS THE PADDLE</Text>
        </View>

        <View style={styles.coins}>
          <HeroFace slot="p1" size={128} uri={faces.p1} busy={busy === 'p1'} onPress={() => pick('p1')} hint={faces.p1 ? 'tap to change' : 'tap to add your face'} />
          <PulseBall />
          <HeroFace slot="p2" size={128} uri={faces.p2} busy={busy === 'p2'} onPress={() => pick('p2')} hint={faces.p2 ? 'tap to change' : 'tap to add a face'} />
        </View>

        <View style={styles.actions}>
          <NeonButton label="QUICK MATCH" variant="lime" onPress={() => onMode('quick')} />
          <NeonButton label="PLAY A FRIEND" variant="cyan" onPress={() => onMode('friend')} />
          <NeonButton label="VS COMPUTER" variant="ghost" onPress={() => onMode('cpu')} />
        </View>

        <Text style={styles.hiscore}>
          Longest rally{'  '}
          <Text style={styles.hiscoreNum}>{best || 28}</Text>
        </Text>
      </View>
    </View>
  );
}

// The little "ball" between the two faces, pulsing like a serve about to
// happen.
function PulseBall() {
  const s = useSharedValue(1);
  useEffect(() => {
    s.value = withRepeat(
      withSequence(
        withTiming(1.35, { duration: 700, easing: Easing.inOut(Easing.sin) }),
        withTiming(1, { duration: 700, easing: Easing.inOut(Easing.sin) }),
      ),
      -1,
    );
  }, [s]);
  const style = useAnimatedStyle(() => ({ transform: [{ scale: s.value }] }));
  return <Animated.View style={[styles.ball, style]} />;
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg },
  content: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 34, gap: 8 },
  brand: { alignItems: 'center' },
  word: { fontFamily: FONT.display, fontSize: 60, letterSpacing: -1, textShadowOffset: { width: 0, height: 0 }, textShadowRadius: 26 },
  face: { color: C.cyan, textShadowColor: 'rgba(25,231,255,0.5)' },
  pong: { color: C.magenta, textShadowColor: 'rgba(255,46,136,0.5)', marginTop: -10 },
  tag: { marginTop: 14, borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)', backgroundColor: 'rgba(255,255,255,0.03)', borderRadius: 999, paddingHorizontal: 12, paddingVertical: 6 },
  tagText: { fontFamily: FONT.bodyBold, color: C.inkDim, fontSize: 10.5, letterSpacing: 1.2 },
  coins: { flexDirection: 'row', alignItems: 'center', gap: 8, marginVertical: 34 },
  ball: { width: 16, height: 16, borderRadius: 8, backgroundColor: C.lime, shadowColor: C.lime, shadowOpacity: 0.8, shadowRadius: 12, shadowOffset: { width: 0, height: 0 } },
  actions: { width: '100%', gap: 12 },
  hiscore: { fontFamily: FONT.body, color: C.inkDim, fontSize: 13, marginTop: 22 },
  hiscoreNum: { fontFamily: FONT.display, color: C.amber, fontSize: 13 },
});
