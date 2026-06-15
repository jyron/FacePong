// Main-screen face. Once you've dropped in a real selfie (a segmented PNG
// silhouette from faces/segment.ts) it shows the bare cutout — just the face,
// no circle — so the menu reads like the in-game paddle ("your face IS the
// paddle"). A blurred, player-coloured copy of the cutout sits behind it as a
// neon aura, matching how the paddle renders in-game. Anything else (the
// stylized default avatar, or a raw photo that never got segmented) still uses
// the circular FaceCoin.
//
// The whole face bobs gently (phase-offset per slot) so the menu feels alive,
// and a `busy` overlay covers the face while a fresh selfie is being segmented.
import React, { useEffect } from 'react';
import { ActivityIndicator, Image, Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import { FaceCoin } from './FaceCoin';
import { C, FONT, ringColor } from '../theme/tokens';
import type { Slot } from '../../shared/constants';

const isSilhouette = (uri: string | null) => !!uri && uri.startsWith('data:image/png');

export function HeroFace({
  slot,
  size,
  uri,
  onPress,
  hint,
  busy = false,
}: {
  slot: Slot;
  size: number;
  uri: string | null;
  onPress?: () => void;
  hint?: string;
  busy?: boolean;
}) {
  const ring = ringColor(slot);

  // Idle bob, phase-offset so the two faces don't move in lockstep.
  const bob = useSharedValue(0);
  useEffect(() => {
    const drift = withSequence(
      withTiming(-5, { duration: 1500, easing: Easing.inOut(Easing.sin) }),
      withTiming(5, { duration: 1500, easing: Easing.inOut(Easing.sin) }),
    );
    bob.value = withDelay(slot === 'p1' ? 0 : 750, withRepeat(drift, -1, true));
  }, [bob, slot]);
  const bobStyle = useAnimatedStyle(() => ({ transform: [{ translateY: bob.value }] }));

  const face = isSilhouette(uri) ? (
    // Bare cutout with a neon aura in the exact shape of the face: a tinted,
    // blurred, slightly enlarged copy of the same image behind the real one.
    <View style={{ width: size, height: size }}>
      <Image
        source={{ uri: uri! }}
        blurRadius={14}
        resizeMode="contain"
        style={[
          StyleSheet.absoluteFillObject,
          { tintColor: ring, opacity: 0.8, transform: [{ scale: 1.07 }] },
        ]}
      />
      <Image source={{ uri: uri! }} style={{ width: size, height: size }} resizeMode="contain" />
    </View>
  ) : (
    <FaceCoin slot={slot} size={size} uri={uri} />
  );

  return (
    <Pressable onPress={onPress} disabled={!onPress || busy} style={styles.center}>
      <Animated.View style={bobStyle}>
        <View style={busy ? styles.dimmed : null}>{face}</View>
        {busy ? (
          <View style={StyleSheet.absoluteFill}>
            <View style={styles.spinner}>
              <ActivityIndicator size="large" color={ring} />
            </View>
          </View>
        ) : null}
      </Animated.View>
      {hint ? <Text style={styles.hint}>{busy ? 'cutting out your face…' : hint}</Text> : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  center: { alignItems: 'center' },
  dimmed: { opacity: 0.35 },
  spinner: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  hint: { fontFamily: FONT.body, color: C.inkFaint, fontSize: 10, letterSpacing: 0.8, marginTop: 7 },
});
