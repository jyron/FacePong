import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { C, FONT } from '../theme/tokens';

// Two neon numbers separated by a dash. p1 = cyan (left), p2 = magenta (right).
export function ScoreChip({
  p1,
  p2,
  size = 30,
  reversed = false,
}: {
  p1: number;
  p2: number;
  size?: number;
  reversed?: boolean;
}) {
  const left = reversed
    ? { v: p2, color: C.magenta, glow: 'rgba(255,46,136,0.6)' }
    : { v: p1, color: C.cyan, glow: 'rgba(25,231,255,0.6)' };
  const right = reversed
    ? { v: p1, color: C.cyan, glow: 'rgba(25,231,255,0.6)' }
    : { v: p2, color: C.magenta, glow: 'rgba(255,46,136,0.6)' };

  return (
    <View style={styles.row}>
      <Text style={[styles.v, { fontSize: size, color: left.color, textShadowColor: left.glow }]}>{left.v}</Text>
      <Text style={[styles.dash, { fontSize: size * 0.72 }]}>·</Text>
      <Text style={[styles.v, { fontSize: size, color: right.color, textShadowColor: right.glow }]}>{right.v}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center' },
  v: {
    fontFamily: FONT.display,
    minWidth: 30,
    textAlign: 'center',
    textShadowOffset: { width: 0, height: 0 },
    textShadowRadius: 16,
  },
  dash: { fontFamily: FONT.display, color: C.inkFaint, marginHorizontal: 8 },
});
