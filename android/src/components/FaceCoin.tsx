// Circular "face coin" with a neon ring glow. Shows a real photo if set,
// otherwise the stylized default avatar. Optionally tappable to pick a face.
import React from 'react';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { DefaultFace } from '../faces/DefaultFace';
import { ringColor, C, FONT } from '../theme/tokens';
import type { Slot } from '../../shared/constants';

export function FaceCoin({
  slot,
  size,
  uri,
  onPress,
  hint,
  ringWidth = 3,
  dim = false,
}: {
  slot: Slot;
  size: number;
  uri: string | null;
  onPress?: () => void;
  hint?: string;
  ringWidth?: number;
  dim?: boolean;
}) {
  const ring = ringColor(slot);
  const coin = (
    <View
      style={[
        styles.glow,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          shadowColor: ring,
          shadowRadius: size * 0.28,
          opacity: dim ? 0.6 : 1,
        },
      ]}
    >
      <View
        style={[
          styles.clip,
          { borderRadius: size / 2, borderWidth: ringWidth, borderColor: ring },
        ]}
      >
        {uri ? (
          <Image source={{ uri }} style={styles.fill} resizeMode="cover" />
        ) : (
          <DefaultFace slot={slot} />
        )}
      </View>
    </View>
  );

  if (!onPress) return coin;
  return (
    <Pressable onPress={onPress} style={styles.center}>
      {coin}
      {hint ? <Text style={styles.hint}>{hint}</Text> : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  center: { alignItems: 'center' },
  glow: {
    backgroundColor: C.surface2,
    shadowOpacity: 0.85,
    shadowOffset: { width: 0, height: 0 },
    elevation: 8,
  },
  clip: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, overflow: 'hidden', backgroundColor: C.surface2 },
  fill: { width: '100%', height: '100%' },
  hint: {
    fontFamily: FONT.body,
    color: C.inkFaint,
    fontSize: 10,
    letterSpacing: 0.8,
    marginTop: 7,
  },
});
