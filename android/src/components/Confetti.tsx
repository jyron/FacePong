import React, { useEffect, useRef } from 'react';
import { Animated, StyleSheet, View } from 'react-native';

const COLORS = ['#19e7ff', '#ff2e88', '#d4ff3d', '#7b3bff', '#ffb02e'];

export function Confetti({ width, height, count = 24 }: { width: number; height: number; count?: number }) {
  const pieces = useRef(
    Array.from({ length: count }, () => ({
      left: Math.random() * width,
      delay: Math.random() * 1200,
      dur: 1600 + Math.random() * 1600,
      color: COLORS[(Math.random() * COLORS.length) | 0],
      anim: new Animated.Value(0),
    }))
  ).current;

  useEffect(() => {
    const loops = pieces.map((p) => {
      const run = () => {
        p.anim.setValue(0);
        Animated.timing(p.anim, { toValue: 1, duration: p.dur, delay: p.delay, useNativeDriver: true }).start(({ finished }) => {
          if (finished) run();
        });
      };
      run();
      return p;
    });
    return () => loops.forEach((p) => p.anim.stopAnimation());
  }, [pieces]);

  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      {pieces.map((p, i) => {
        const translateY = p.anim.interpolate({ inputRange: [0, 1], outputRange: [-20, height + 20] });
        const rotate = p.anim.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '540deg'] });
        return (
          <Animated.View
            key={i}
            style={{ position: 'absolute', left: p.left, width: 9, height: 14, borderRadius: 2, backgroundColor: p.color, transform: [{ translateY }, { rotate }] }}
          />
        );
      })}
    </View>
  );
}
