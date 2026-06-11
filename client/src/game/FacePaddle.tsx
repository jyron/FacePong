// A player's paddle. It renders one of three ways depending on what face we
// actually have for that slot:
//
//   • a real segmented silhouette (data:image/png from faces/segment.ts) → a
//     deformable Skia triangle mesh, so the FACE OUTLINE itself squashes and
//     wobbles on impact. This is the whole point of the game: your face IS the
//     paddle. `textures` are the rest positions (the image sticks to these),
//     `vertices` are the live deformed positions driven by the `pop` value.
//   • a raw photo that never got segmented (data:image/jpeg fallback when
//     on-device segmentation is unavailable/failed) → a circular "face coin"
//     (photo clipped to a circle + neon ring), matching the HUD/menu look,
//     instead of an ugly hard-edged square.
//   • no photo at all (e.g. the CPU) → the stylized DefaultFace avatar as a
//     circular coin, the same face shown in the HUD.
//
// The coin variants squash uniformly (scale wider + shorter) on a hit rather
// than rippling, since there's no silhouette to ripple.
import React, { useMemo } from 'react';
import {
  Group,
  Vertices,
  Image as SkiaImage,
  ImageShader,
  ImageSVG,
  Circle,
  Blur,
  BlurMask,
  ColorMatrix,
  Skia,
  rect as skRect,
  rrect,
  type SkPoint,
  type SkImage,
} from '@shopify/react-native-skia';
import { useDerivedValue, type SharedValue } from 'react-native-reanimated';
import type { Slot } from '../../shared/constants';
import { ringColor } from '../theme/tokens';
import { defaultFaceSvgString } from '../faces/defaultFaceSvg';

const GRID = 8; // cells per side → (GRID+1)^2 vertices

function buildMesh(size: number) {
  const half = size / 2;
  const rest: SkPoint[] = [];
  for (let r = 0; r <= GRID; r++) {
    for (let c = 0; c <= GRID; c++) {
      rest.push({ x: -half + (c / GRID) * size, y: -half + (r / GRID) * size });
    }
  }
  const idxOf = (r: number, c: number) => r * (GRID + 1) + c;
  const indices: number[] = [];
  for (let r = 0; r < GRID; r++) {
    for (let c = 0; c < GRID; c++) {
      const a = idxOf(r, c);
      const b = idxOf(r, c + 1);
      const d = idxOf(r + 1, c);
      const e = idxOf(r + 1, c + 1);
      indices.push(a, b, d, b, e, d);
    }
  }
  const rect = { x: -half, y: -half, width: size, height: size };
  return { rest, indices, rect, maxR: half * Math.SQRT2 };
}

function decodeImage(uri: string | null): SkImage | null {
  if (!uri) return null;
  const b64 = uri.startsWith('data:') ? uri.slice(uri.indexOf(',') + 1) : uri;
  try {
    const data = Skia.Data.fromBase64(b64);
    return Skia.Image.MakeImageFromEncoded(data);
  } catch {
    return null;
  }
}

// A real, transparent face cutout is the only thing that gets the silhouette
// mesh; everything else falls back to a circular coin.
const isSilhouette = (uri: string | null) => !!uri && uri.startsWith('data:image/png');

// Color matrix that replaces the image with a flat tint carried by its alpha:
// out.rgb = tint, out.a = a * alpha. Drawing the cutout through this (plus a
// BlurMask) produces a neon aura in the exact shape of the face.
function tintMatrix(hex: string, alpha: number): number[] {
  const r = parseInt(hex.slice(1, 3), 16) / 255;
  const g = parseInt(hex.slice(3, 5), 16) / 255;
  const b = parseInt(hex.slice(5, 7), 16) / 255;
  // prettier-ignore
  return [
    0, 0, 0, r, 0,
    0, 0, 0, g, 0,
    0, 0, 0, b, 0,
    0, 0, 0, alpha, 0,
  ];
}

export function FacePaddle({
  uri,
  slot,
  x,
  y,
  size,
  pop,
}: {
  uri: string | null;
  slot: Slot; // p1 (cyan) / p2 (magenta) — picks the ring colour + default avatar
  x: SharedValue<number>; // paddle centre x in court units (animated)
  y: number; // paddle centre y in court units (constant)
  size: number;
  pop: SharedValue<number>; // 0 at rest, springs on hit
}) {
  const { rest, indices, rect, maxR } = useMemo(() => buildMesh(size), [size]);
  const img = useMemo(() => decodeImage(uri), [uri]);
  const silhouette = isSilhouette(uri) && !!img;
  const ring = ringColor(slot);
  const half = size / 2;
  const ringW = Math.max(2, size * 0.045);
  const coinClip = useMemo(() => rrect(skRect(-half, -half, size, size), half, half), [half, size]);
  const svg = useMemo(
    () => (silhouette ? null : Skia.SVG.MakeFromString(defaultFaceSvgString(slot))),
    [silhouette, slot],
  );
  const amp = size * 0.06;

  // Silhouette: deform each mesh vertex (squash + ripple) so the outline wobbles.
  const vertices = useDerivedValue<SkPoint[]>(() => {
    const p = pop.value;
    const sx = 1 + p * 0.16; // squash wider...
    const sy = 1 - p * 0.12; // ...and shorter on impact
    const out: SkPoint[] = [];
    for (let i = 0; i < rest.length; i++) {
      const vx = rest[i].x;
      const vy = rest[i].y;
      let nx = vx * sx;
      let ny = vy * sy;
      const d = Math.sqrt(vx * vx + vy * vy);
      if (d > 0.001) {
        const rr = d / maxR;
        const k = p * amp * Math.sin(rr * 6.0); // ripple that rides the spring
        nx += (vx / d) * k;
        ny += (vy / d) * k;
      }
      out.push({ x: nx, y: ny });
    }
    return out;
  });
  const meshTransform = useDerivedValue(() => [{ translateX: x.value }, { translateY: y }]);

  // Coin: translate to the paddle centre and squash the whole disc on a hit.
  const coinTransform = useDerivedValue(() => {
    const p = pop.value;
    return [
      { translateX: x.value },
      { translateY: y },
      { scaleX: 1 + p * 0.16 },
      { scaleY: 1 - p * 0.12 },
    ];
  });

  if (silhouette) {
    // Two tinted copies of the deformed mesh under the real one: a wide soft
    // aura and a tight bright rim, both in the player's neon colour and both
    // shaped exactly like the face (they ride the same deformed vertices). This
    // is what makes the cutout read as a game piece on the dark court instead
    // of floating photo pixels, and matches the coin paddles' ring + glow.
    return (
      <Group transform={meshTransform}>
        <Vertices vertices={vertices} textures={rest} indices={indices} mode="triangles">
          <ImageShader image={img!} rect={rect} fit="cover" tx="decal" ty="decal" />
          <ColorMatrix matrix={tintMatrix(ring, 0.7)} />
          <Blur blur={size * 0.09} />
        </Vertices>
        <Vertices vertices={vertices} textures={rest} indices={indices} mode="triangles">
          <ImageShader image={img!} rect={rect} fit="cover" tx="decal" ty="decal" />
          <ColorMatrix matrix={tintMatrix(ring, 1)} />
          <Blur blur={size * 0.02} />
        </Vertices>
        <Vertices vertices={vertices} textures={rest} indices={indices} mode="triangles">
          <ImageShader image={img!} rect={rect} fit="cover" tx="decal" ty="decal" />
        </Vertices>
      </Group>
    );
  }

  // Circular face coin (raw-photo fallback or the default/CPU avatar).
  return (
    <Group transform={coinTransform}>
      <Circle cx={0} cy={0} r={half} color={ring} opacity={0.45}>
        <BlurMask blur={size * 0.22} style="normal" />
      </Circle>
      <Group clip={coinClip}>
        {img ? (
          <SkiaImage image={img} x={-half} y={-half} width={size} height={size} fit="cover" />
        ) : svg ? (
          <Group transform={[{ translateX: -half }, { translateY: -half }, { scale: size / 100 }]}>
            <ImageSVG svg={svg} x={0} y={0} width={100} height={100} />
          </Group>
        ) : null}
      </Group>
      <Circle cx={0} cy={0} r={half - ringW / 2} color={ring} style="stroke" strokeWidth={ringW} />
    </Group>
  );
}
