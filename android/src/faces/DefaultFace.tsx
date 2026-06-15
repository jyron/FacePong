// The two stylized default avatars, ported from the design bundle's faces.jsx
// to react-native-svg. Used until a player drops in a real photo.
import React from 'react';
import Svg, { Defs, LinearGradient, Stop, Rect, Ellipse, Path, Circle } from 'react-native-svg';
import type { Slot } from '../../shared/constants';

export function DefaultFace({ slot }: { slot: Slot }) {
  if (slot === 'p1') {
    return (
      <Svg width="100%" height="100%" viewBox="0 0 100 100">
        <Defs>
          <LinearGradient id="p1bg" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0" stopColor="#0c2b3a" />
            <Stop offset="1" stopColor="#0a1726" />
          </LinearGradient>
        </Defs>
        <Rect width="100" height="100" fill="url(#p1bg)" />
        <Ellipse cx="50" cy="55" rx="27" ry="30" fill="#ffd6a8" />
        <Path
          d="M23 50c0-19 13-30 27-30s27 11 27 30c0-6-3-9-7-9-2-9-13-15-20-15s-18 6-20 15c-4 0-7 3-7 9z"
          fill="#23314a"
        />
        <Rect x="28" y="48" width="44" height="11" rx="5.5" fill="#0b1320" />
        <Rect x="30" y="49.5" width="17" height="8" rx="4" fill="#19e7ff" opacity="0.85" />
        <Rect x="53" y="49.5" width="17" height="8" rx="4" fill="#19e7ff" opacity="0.85" />
        <Path d="M40 70q10 9 20 0" stroke="#b9744a" strokeWidth="3.5" fill="none" strokeLinecap="round" />
      </Svg>
    );
  }
  return (
    <Svg width="100%" height="100%" viewBox="0 0 100 100">
      <Defs>
        <LinearGradient id="p2bg" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#3a0c2a" />
          <Stop offset="1" stopColor="#260a1c" />
        </LinearGradient>
      </Defs>
      <Rect width="100" height="100" fill="url(#p2bg)" />
      <Ellipse cx="50" cy="55" rx="27" ry="30" fill="#e7b48f" />
      <Path
        d="M21 58c-2-26 14-38 29-38s31 12 29 38c-3-4-6-4-9-3 1-10-2-17-6-20-3 7-12 10-23 10-4 0-7 2-9 6-1 3-1 8 0 12-4-1-8-1-11-5z"
        fill="#3b1d33"
      />
      <Circle cx="40" cy="52" r="3.4" fill="#2a1422" />
      <Circle cx="60" cy="52" r="3.4" fill="#2a1422" />
      <Circle cx="34" cy="62" r="4" fill="#ff7ab0" opacity="0.4" />
      <Circle cx="66" cy="62" r="4" fill="#ff7ab0" opacity="0.4" />
      <Path d="M41 67q9 10 18 0" stroke="#b85b7e" strokeWidth="3.5" fill="none" strokeLinecap="round" />
    </Svg>
  );
}
