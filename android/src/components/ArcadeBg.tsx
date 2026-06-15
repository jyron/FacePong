// Full-bleed neon backdrop: faint purple grid + vignette, drawn in Skia.
import React from 'react';
import { StyleSheet } from 'react-native';
import { Canvas, Line, vec, Rect, RadialGradient } from '@shopify/react-native-skia';
import { C } from '../theme/tokens';

export function ArcadeBg({ width, height, grid = true }: { width: number; height: number; grid?: boolean }) {
  const step = 39;
  const vLines: number[] = [];
  const hLines: number[] = [];
  if (grid) {
    for (let x = 0; x <= width; x += step) vLines.push(x);
    for (let y = 0; y <= height; y += step) hLines.push(y);
  }
  return (
    <Canvas style={[StyleSheet.absoluteFill, { width, height }]} pointerEvents="none">
      {vLines.map((x) => (
        <Line key={`v${x}`} p1={vec(x, 0)} p2={vec(x, height)} color={C.grid} style="stroke" strokeWidth={1} />
      ))}
      {hLines.map((y) => (
        <Line key={`h${y}`} p1={vec(0, y)} p2={vec(width, y)} color={C.grid} style="stroke" strokeWidth={1} />
      ))}
      <Rect x={0} y={0} width={width} height={height}>
        <RadialGradient
          c={vec(width / 2, height * 0.5)}
          r={Math.max(width, height) * 0.7}
          colors={['transparent', 'rgba(0,0,0,0.55)']}
        />
      </Rect>
    </Canvas>
  );
}
