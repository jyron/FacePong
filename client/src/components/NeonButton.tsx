// Chunky arcade button with a solid bottom edge that depresses on press.
import React, { useRef } from 'react';
import { Animated, Pressable, StyleSheet, Text } from 'react-native';
import { C, FONT } from '../theme/tokens';

type Variant = 'lime' | 'cyan' | 'ghost';

const FACE: Record<Variant, string> = { lime: C.lime, cyan: C.cyan, ghost: 'transparent' };
const EDGE: Record<Variant, string> = { lime: '#6f9a00', cyan: '#086d80', ghost: 'transparent' };
const TEXT: Record<Variant, string> = { lime: '#08121a', cyan: '#04161b', ghost: C.inkDim };

export function NeonButton({
  label,
  onPress,
  variant = 'lime',
  small = false,
}: {
  label: string;
  onPress: () => void;
  variant?: Variant;
  small?: boolean;
}) {
  const depth = variant === 'ghost' ? 0 : 7;
  const press = useRef(new Animated.Value(0)).current;
  const translateY = press.interpolate({ inputRange: [0, 1], outputRange: [0, depth - 2] });

  const ghost = variant === 'ghost';

  return (
    <Pressable
      onPressIn={() => Animated.timing(press, { toValue: 1, duration: 60, useNativeDriver: true }).start()}
      onPressOut={() => Animated.timing(press, { toValue: 0, duration: 90, useNativeDriver: true }).start()}
      onPress={onPress}
      style={styles.wrap}
    >
      <Animated.View
        style={[
          styles.btn,
          {
            backgroundColor: FACE[variant],
            borderBottomWidth: depth,
            borderBottomColor: EDGE[variant],
            paddingVertical: small ? 13 : 17,
            transform: [{ translateY }],
          },
          ghost && styles.ghost,
        ]}
      >
        <Text
          style={[
            styles.label,
            { color: TEXT[variant], fontSize: small ? 14 : 18 },
            ghost && { letterSpacing: 1 },
          ]}
        >
          {label}
        </Text>
      </Animated.View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  wrap: { width: '100%' },
  btn: {
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 22,
  },
  ghost: { borderWidth: 2, borderColor: 'rgba(255,255,255,0.16)', borderBottomWidth: 2 },
  label: { fontFamily: FONT.display, letterSpacing: 0.6 },
});
