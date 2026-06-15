// On-device face cutout. Runs selfie segmentation locally via
// react-native-executorch (no server, no network round-trip beyond a one-time
// model download), turns the picked photo into a transparent PNG of just the
// person, cropped to a centred square around the silhouette. The PNG's alpha IS
// the face outline — that's what the paddle is shaped from.
//
// NOTE: the executorch runtime is native, so this only runs in a development
// build (`expo prebuild` + `expo run:ios`/`run:android`), not Expo Go. Callers
// fall back to the raw photo if this throws.
import { Skia, ColorType, AlphaType, ImageFormat } from '@shopify/react-native-skia';
import { SemanticSegmentationModule } from 'react-native-executorch';

type SelfieModel = SemanticSegmentationModule<'selfie-segmentation'>;

// The model ships bundled in the app (assets/selfie_segmentation.pte, ~0.5 MB,
// registered as an asset in metro.config.js), so there is NO runtime download —
// users never wait, same as an OS-provided model.
const SELFIE_MODEL_SOURCE = {
  modelName: 'selfie-segmentation' as const,
  modelSource: require('../../assets/selfie_segmentation.pte'),
};

let modelPromise: Promise<SelfieModel> | null = null;
function loadModel(): Promise<SelfieModel> {
  if (!modelPromise) {
    modelPromise = SemanticSegmentationModule.fromModelName(SELFIE_MODEL_SOURCE).catch((e) => {
      modelPromise = null; // let the next pick retry
      throw e;
    });
  }
  return modelPromise;
}

const base64Of = (uri: string) => (uri.startsWith('data:') ? uri.slice(uri.indexOf(',') + 1) : uri);

// photoDataUri: a square-ish JPEG/PNG data URI. Returns a transparent PNG data
// URI of the segmented person, cropped to a centred square. Throws on failure.
export async function cutoutFace(photoDataUri: string): Promise<string> {
  const model = await loadModel();
  // Per-pixel foreground probability, resized back to the photo's own dimensions.
  const { SELFIE } = await model.forward(photoDataUri, ['SELFIE'], true);

  const img = Skia.Image.MakeImageFromEncoded(Skia.Data.fromBase64(base64Of(photoDataUri)));
  if (!img) throw new Error('cutoutFace: decode failed');
  const W = img.width();
  const H = img.height();
  const info = { width: W, height: H, colorType: ColorType.RGBA_8888, alphaType: AlphaType.Unpremul };
  const px = img.readPixels(0, 0, info) as Uint8Array | null;
  if (!px || SELFIE.length < W * H) throw new Error('cutoutFace: pixel/mask mismatch');

  // Write the mask into the alpha channel. The raw model output is a soft
  // probability ramp, which leaves a mushy edge with background bleed; remap it
  // through a smoothstep so the silhouette edge is crisp but still antialiased.
  // Per-row extents are tracked too, so the crop below can find the head.
  let minX = W;
  let minY = H;
  let maxX = -1;
  let maxY = -1;
  const rowMin = new Int32Array(H).fill(W);
  const rowMax = new Int32Array(H).fill(-1);
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = y * W + x;
      let t = (SELFIE[i] - 0.3) / 0.5; // crisp by 0.8, gone by 0.3
      t = t < 0 ? 0 : t > 1 ? 1 : t;
      t = t * t * (3 - 2 * t);
      const a = Math.round(t * 255);
      px[i * 4 + 3] = a;
      if (a > 128) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        if (x < rowMin[y]) rowMin[y] = x;
        if (x > rowMax[y]) rowMax[y] = x;
      }
    }
  }
  if (maxX < minX) throw new Error('cutoutFace: no foreground');

  // Selfie segmentation returns the whole person, so a bust shot's bounding box
  // is dominated by shoulders/chest and the face ends up small in the top half
  // of the paddle. Instead, crop a square around the HEAD: the widest row in
  // the top ~40% of the silhouette is roughly ear-to-ear, so a square of about
  // 1.5× that width, anchored just above the crown, frames the face with a
  // little shoulder for context.
  const bw = maxX - minX + 1;
  const bh = maxY - minY + 1;
  const bandEnd = Math.min(maxY, minY + Math.max(1, Math.round(bh * 0.4)));
  let headW = 0;
  let headCx = (minX + maxX) / 2;
  for (let y = minY; y <= bandEnd; y++) {
    const w = rowMax[y] - rowMin[y] + 1;
    if (w > headW) {
      headW = w;
      headCx = (rowMin[y] + rowMax[y]) / 2;
    }
  }
  // Floor at a fraction of the full bbox so a failed head estimate (e.g. a hand
  // in front of the face) can't produce an absurdly tight crop.
  const side = Math.min(W, H, Math.max(Math.round(headW * 1.5), Math.round(Math.max(bw, bh) * 0.55)));
  const sx = Math.max(0, Math.min(Math.round(headCx - side / 2), W - side));
  const sy = Math.max(0, Math.min(minY - Math.round(side * 0.1), H - side));

  // When the person fills the frame the foreground touches the crop edges,
  // producing a hard rectangular cut (most visible as a flat line across the
  // shoulders at the bottom). Feather the alpha toward the bottom and side
  // edges so it fades out into the court instead. The top is left crisp so the
  // crown of the head stays sharp.
  const feather = Math.max(1, Math.round(side * 0.12));
  const out = new Uint8Array(side * side * 4);
  for (let y = 0; y < side; y++) {
    const srcRow = (sy + y) * W + sx;
    const dstRow = y * side;
    const distBottom = side - 1 - y;
    for (let x = 0; x < side; x++) {
      const s = (srcRow + x) * 4;
      const d = (dstRow + x) * 4;
      out[d] = px[s];
      out[d + 1] = px[s + 1];
      out[d + 2] = px[s + 2];
      const edge = Math.min(x, side - 1 - x, distBottom); // ignore top edge
      let fade = 1;
      if (edge < feather) {
        const f = edge / feather;
        fade = f * f * (3 - 2 * f); // eased, so the fade has no visible start line
      }
      out[d + 3] = Math.round(px[s + 3] * fade);
    }
  }

  const cropped = Skia.Image.MakeImage(
    { width: side, height: side, colorType: ColorType.RGBA_8888, alphaType: AlphaType.Unpremul },
    Skia.Data.fromBytes(out),
    side * 4,
  );
  if (!cropped) throw new Error('cutoutFace: build failed');
  return `data:image/png;base64,${cropped.encodeToBase64(ImageFormat.PNG)}`;
}
