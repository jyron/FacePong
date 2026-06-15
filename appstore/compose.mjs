// Composes App Store marketing screenshots (1320x2868, iPhone 6.9") from the
// raw simulator captures in ./raw: neon arcade background, headline, and the
// capture inside a minimal device bezel. Run: node compose.mjs
import { chromium } from 'playwright';
import { readFileSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const dir = path.dirname(fileURLToPath(import.meta.url));
const fonts = path.join(dir, '..', 'node_modules', '@expo-google-fonts');
const bungee = path.join(fonts, 'bungee', '400Regular', 'Bungee_400Regular.ttf');
const grotesk = path.join(fonts, 'space-grotesk', '700Bold', 'SpaceGrotesk_700Bold.ttf');

const C = {
  bg: '#07070f',
  cyan: '#19e7ff',
  magenta: '#ff2e88',
  lime: '#d4ff3d',
  amber: '#ffb347',
  dim: '#9aa0b5',
};

const slides = [
  { src: '02-gameplay-action.png', out: '1-face-paddle.png', color: C.cyan,
    title: 'YOUR FACE IS<br>THE PADDLE', sub: 'Snap a selfie — it’s your paddle.' },
  { src: '03-gameplay-action.png', out: '2-rally-smash.png', color: C.lime,
    title: 'RALLY. SMASH.<br>SCORE.', sub: 'The longer the rally, the hotter the ball.' },
  { src: '01-start.png', out: '3-pick-and-play.png', color: C.magenta,
    title: 'PICK A FACE<br>& PLAY', sub: 'From selfie to match point in seconds.' },
  { src: '05-win.png', out: '4-bragging-rights.png', color: C.amber,
    title: 'WIN BRAGGING<br>RIGHTS', sub: 'Top rally, aces, match time — the receipts.' },
  { src: '07-friend-code.png', out: '5-challenge.png', color: C.cyan,
    title: 'CHALLENGE<br>A FRIEND', sub: 'Create a game, text the code, settle it.' },
  { src: '06-share.png', out: '6-share.png', color: C.magenta, brighten: true,
    title: 'SHARE THE<br>VICTORY', sub: 'A victory card made for the group chat.' },
];

// Decorative floating confetti for the marketing canvas: deterministic
// positions so re-renders are stable. Kept off the device frame's screen.
function confettiHtml(color) {
  const palette = [C.cyan, C.magenta, C.lime, C.amber, '#ffffff'];
  let dots = '';
  let r = 7;
  const rnd = () => { r = (r * 16807) % 2147483647; return r / 2147483647; };
  for (let i = 0; i < 26; i++) {
    const left = rnd() * 1320;
    const top = 100 + rnd() * 2600;
    // keep clear of the device area (x 150-1170, y 640-2868)
    if (left > 130 && left < 1190 && top > 600) continue;
    const size = 8 + rnd() * 18;
    const c = i % 3 === 0 ? color : palette[Math.floor(rnd() * palette.length)];
    const rot = Math.floor(rnd() * 90) - 45;
    const round = rnd() > 0.5 ? '50%' : '4px';
    dots += `<div style="position:absolute;left:${left}px;top:${top}px;width:${size}px;height:${size}px;
      background:${c};border-radius:${round};opacity:${0.5 + rnd() * 0.5};
      transform:rotate(${rot}deg);box-shadow:0 0 ${size * 1.6}px ${c};"></div>`;
  }
  return dots;
}

// Base64-embed fonts: file:// font URLs are blocked for pages loaded via
// setContent (about:blank origin), so inline them instead.
const fontB64 = (p) => `data:font/ttf;base64,${readFileSync(p).toString('base64')}`;

const html = (s) => `<!doctype html><html><head><style>
@font-face { font-family: Bungee; src: url('${fontB64(bungee)}'); }
@font-face { font-family: Grotesk; src: url('${fontB64(grotesk)}'); }
* { margin: 0; padding: 0; }
body {
  width: 1320px; height: 2868px; overflow: hidden; position: relative;
  background:
    radial-gradient(900px 700px at 50% -100px, ${s.color}40, transparent 70%),
    radial-gradient(1000px 800px at 50% 2400px, ${s.color}22, transparent 70%),
    repeating-linear-gradient(0deg, transparent 0 79px, rgba(255,255,255,0.035) 79px 80px),
    repeating-linear-gradient(90deg, transparent 0 79px, rgba(255,255,255,0.035) 79px 80px),
    ${C.bg};
}
.title {
  font-family: Bungee; font-size: 122px; line-height: 1.08; text-align: center;
  color: ${s.color}; margin-top: 140px; position: relative; z-index: 2;
  text-shadow: 0 0 90px ${s.color}, 0 0 36px ${s.color}aa, 0 0 14px ${s.color}88;
}
.underline {
  width: 460px; height: 10px; margin: 34px auto 0; border-radius: 6px;
  background: linear-gradient(90deg, ${C.cyan}, ${C.magenta}, ${C.lime});
  box-shadow: 0 0 30px ${s.color}aa;
}
.sub {
  font-family: Grotesk; font-size: 48px; text-align: center; color: #c9cede;
  margin-top: 34px; letter-spacing: 0.5px; position: relative; z-index: 2;
}
.device {
  position: absolute; left: 50%; transform: translateX(-50%);
  top: 660px; width: 1020px; padding: 22px;
  background: #15151f; border-radius: 162px;
  border: 2px solid rgba(255,255,255,0.14);
  box-shadow: 0 0 220px ${s.color}66, 0 0 70px ${s.color}55, 0 60px 120px rgba(0,0,0,0.8);
  z-index: 3;
}
.device img { display: block; width: 100%; border-radius: 140px; ${s.brighten ? 'filter: brightness(1.22) saturate(1.12);' : ''} }
</style></head><body>
  ${confettiHtml(s.color)}
  <div class="title">${s.title}</div>
  <div class="underline"></div>
  <div class="sub">${s.sub}</div>
  <div class="device"><img src="data:image/png;base64,${readFileSync(path.join(dir, 'raw', s.src)).toString('base64')}"></div>
</body></html>`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1320, height: 2868 }, deviceScaleFactor: 1 });
for (const s of slides) {
  await page.setContent(html(s), { waitUntil: 'networkidle' });
  await page.screenshot({ path: path.join(dir, 'final', s.out) });
  console.log('wrote final/' + s.out);
}
await browser.close();
