import React, { useEffect, useRef, useState } from 'react';
import { Animated, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { FaceCoin } from '../components/FaceCoin';
import { ArcadeBg } from '../components/ArcadeBg';
import { useFaces } from '../faces/FaceStore';
import { C, FONT } from '../theme/tokens';
import { COUNTDOWN_FROM } from '../../shared/constants';
import { sfx } from '../sfx/sfx';

const P1 = 'YOU';

// Round intro with a 3-2-1 countdown, then auto-advances to gameplay.
export function RoundScreen({
  round,
  opponentName,
  onDone,
}: {
  round: number;
  opponentName: string;
  onDone: () => void;
}) {
  const { faces } = useFaces();
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const [n, setN] = useState(COUNTDOWN_FROM);
  const pulse = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    setN(COUNTDOWN_FROM);
    sfx.tick();
    let v = COUNTDOWN_FROM;
    const id = setInterval(() => {
      v -= 1;
      if (v <= 0) {
        clearInterval(id);
        sfx.tick(true); // the GO beep
        onDone();
      } else {
        setN(v);
        sfx.tick();
      }
    }, 850);
    return () => clearInterval(id);
  }, [round, onDone]);

  useEffect(() => {
    pulse.setValue(0);
    Animated.timing(pulse, { toValue: 1, duration: 420, useNativeDriver: true }).start();
  }, [n, pulse]);

  const scale = pulse.interpolate({ inputRange: [0, 1], outputRange: [1.25, 1] });

  return (
    <View style={styles.root}>
      <ArcadeBg width={width} height={height} />
      <View style={[styles.content, { paddingTop: insets.top, paddingBottom: insets.bottom }]}>
        <Text style={styles.banner}>MATCH · BEST OF 5</Text>
        <Text style={styles.round}>ROUND {round}</Text>

        <View style={styles.vs}>
          <View style={styles.who}>
            <FaceCoin slot="p1" size={78} uri={faces.p1} />
            <Text style={[styles.name, { color: C.cyan }]}>{P1}</Text>
          </View>
          <Text style={styles.vsBadge}>VS</Text>
          <View style={styles.who}>
            <FaceCoin slot="p2" size={78} uri={faces.p2} />
            <Text style={[styles.name, { color: C.magenta }]}>{opponentName}</Text>
          </View>
        </View>

        <Animated.Text style={[styles.count, { transform: [{ scale }] }]}>{n}</Animated.Text>
        <Text style={styles.ready}>GET READY</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg },
  content: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 30 },
  banner: { fontFamily: FONT.display, fontSize: 12, letterSpacing: 4, color: C.inkDim },
  round: { fontFamily: FONT.display, fontSize: 40, color: C.lime, marginTop: 6, textShadowColor: 'rgba(212,255,61,0.5)', textShadowRadius: 18, textShadowOffset: { width: 0, height: 0 } },
  vs: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 16, marginVertical: 40 },
  who: { alignItems: 'center', gap: 10, flex: 1 },
  name: { fontFamily: FONT.bodyBold, fontSize: 14 },
  vsBadge: { fontFamily: FONT.display, fontSize: 26, color: C.lime, transform: [{ rotate: '-8deg' }], textShadowColor: 'rgba(212,255,61,0.5)', textShadowRadius: 18, textShadowOffset: { width: 0, height: 0 } },
  count: { fontFamily: FONT.display, fontSize: 120, color: C.ink, textShadowColor: 'rgba(123,59,255,0.7)', textShadowRadius: 36, textShadowOffset: { width: 0, height: 0 } },
  ready: { fontFamily: FONT.display, letterSpacing: 4, color: C.inkDim, fontSize: 14, marginTop: 14 },
});
