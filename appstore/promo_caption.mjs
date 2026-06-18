// Renders transparent TikTok caption overlays + a branded FacePong end card at
// 1080x1920. Captions are transparent (omitBackground) PNGs overlaid on each clip
// with ffmpeg; the end card is opaque and becomes the tail. Captions sit LOW so
// they never cover her face (hook/payoff selfies) or the squashing face paddle
// (gameplay). FacePong neon palette: cyan / magenta / lime.
// Run: node appstore/promo_caption.mjs
import playwright from '/Users/jyron/src/faceslap/appstore/node_modules/playwright/index.js';
const { chromium } = playwright;
import { readFileSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const dir = path.dirname(fileURLToPath(import.meta.url));
const fonts = '/Users/jyron/src/facepong/appstore/fonts';
const bungee = path.join(fonts, 'Bungee_400Regular.ttf');
const grotesk = path.join(fonts, 'SpaceGrotesk_700Bold.ttf');
const fontB64 = (p) => `data:font/ttf;base64,${readFileSync(p).toString('base64')}`;

const W = 1080, H = 1920;
const C = { bg: '#0a0918', cyan: '#19e7ff', magenta: '#ff2e88', lime: '#d4ff3d', amber: '#ffb02e' };

const faceCSS = `
@font-face { font-family: Bungee; src: url('${fontB64(bungee)}'); }
@font-face { font-family: Grotesk; src: url('${fontB64(grotesk)}'); }
* { margin: 0; padding: 0; box-sizing: border-box; }
body { width: ${W}px; height: ${H}px; overflow: hidden; position: relative; }`;

// Chunky white TikTok caption, black stroke + shadow. `top` places it (LOW so it
// never covers a face); `size` keeps the words from dominating the frame.
const caption = (lines, { top = 1360, size = 62 } = {}) => `<!doctype html><html><head><style>${faceCSS}
.wrap { position:absolute; top:${top}px; left:0; right:0; display:flex; flex-direction:column;
  align-items:center; gap:16px; padding:0 70px; }
.line { font-family: Grotesk; font-weight:700; font-size:${size}px; line-height:1.04; text-align:center;
  color:#fff; -webkit-text-stroke:7px #000; paint-order:stroke fill;
  text-shadow:0 5px 0 rgba(0,0,0,0.55), 0 0 30px rgba(0,0,0,0.6); letter-spacing:-1px; }
.line .hl { color:${C.cyan}; }
.line .lime { color:${C.lime}; }
.line .hot { color:${C.magenta}; }
</style></head><body>
  <div class="wrap">${lines.map((l) => `<div class="line">${l}</div>`).join('')}</div>
</body></html>`;

// Opaque branded FacePong outro.
function confetti() {
  const palette = [C.cyan, C.magenta, C.lime, '#ffffff'];
  const emojis = ['🏓', '💥', '⚡️', '😭'];
  let dots = '', r = 13;
  const rnd = () => { r = (r * 16807) % 2147483647; return r / 2147483647; };
  for (let i = 0; i < 30; i++) {
    const left = rnd() * W, top = rnd() * H;
    if (top > 620 && top < 1280) continue; // keep the center text clean
    if (i % 6 === 2) {
      const e = emojis[Math.floor(rnd() * emojis.length)], sz = 38 + rnd() * 30, rot = Math.floor(rnd() * 50) - 25;
      dots += `<div style="position:absolute;left:${left}px;top:${top}px;font-size:${sz}px;opacity:${0.55 + rnd() * 0.4};transform:rotate(${rot}deg);">${e}</div>`;
      continue;
    }
    const size = 9 + rnd() * 18, c = palette[Math.floor(rnd() * palette.length)];
    const rot = Math.floor(rnd() * 90) - 45, round = rnd() > 0.5 ? '50%' : '4px';
    dots += `<div style="position:absolute;left:${left}px;top:${top}px;width:${size}px;height:${size}px;background:${c};border-radius:${round};opacity:${0.5 + rnd() * 0.5};transform:rotate(${rot}deg);box-shadow:0 0 ${size * 1.7}px ${c};"></div>`;
  }
  return dots;
}

const endcard = (sub = 'Your face is the paddle. 🏓', pill = 'FREE 👆 link in bio') => `<!doctype html><html><head><style>${faceCSS}
body { background:
  radial-gradient(900px 700px at 50% 38%, ${C.cyan}33, transparent 70%),
  radial-gradient(1100px 900px at 50% 112%, ${C.magenta}2e, transparent 70%),
  ${C.bg}; display:flex; flex-direction:column; align-items:center; justify-content:center; }
.title { font-family: Bungee; font-size: 150px; line-height:0.98; text-align:center; color:#fff;
  text-shadow: 0 0 90px ${C.cyan}, 0 0 34px ${C.cyan}cc, 0 0 14px ${C.magenta}99; position:relative; z-index:2; }
.title .p2 { color:${C.cyan}; }
.underline { width:520px; height:13px; margin:46px auto 0; border-radius:7px;
  background: linear-gradient(90deg, ${C.cyan}, ${C.lime}, ${C.magenta}); box-shadow:0 0 40px ${C.cyan}cc; }
.sub { font-family: Grotesk; font-weight:700; font-size:58px; text-align:center; color:#e8e2ff;
  margin:54px 60px 0; line-height:1.16; position:relative; z-index:2; }
.pill { font-family: Grotesk; font-weight:700; font-size:46px; color:#04040a; margin-top:70px;
  padding:30px 64px; border-radius:60px; background:linear-gradient(90deg, ${C.cyan}, ${C.lime});
  box-shadow:0 0 60px ${C.cyan}aa; position:relative; z-index:2; }
</style></head><body>
  ${confetti()}
  <div class="title">FACE<br><span class="p2">PONG</span></div>
  <div class="underline"></div>
  <div class="sub">${sub}</div>
  <div class="pill">${pill}</div>
</body></html>`;

const GP = { top: 1150, size: 50 };   // gameplay caps: low + small so the squash stays visible
const HK = { top: 1360 };             // hook/payoff caps: low, below her face
const TOP = { top: 150, size: 56 };   // connection-card cap: up top

const jobs = [
  { name: 'endcard', html: endcard(), transparent: false },
  // --- Format A: "I made him play me" (couple, his face gets bodied) ---
  { name: 'rev_cap1', html: caption(['my bf swears he’s better', 'at every game 😏'], HK), transparent: true },
  { name: 'rev_cap2', html: caption(['so I put OUR faces', 'in <span class="hl">FacePong</span> 😈'], TOP), transparent: true },
  { name: 'rev_cap3', html: caption(['his face = the paddle', '<span class="hot">watch this</span> 💀'], GP), transparent: true },
  { name: 'rev_cap4', html: caption(['his face every time', 'he misses 😭'], GP), transparent: true },
  { name: 'rev_cap5', html: caption(['I bodied him 📸', '<span class="lime">(keeping this forever)</span>'], HK), transparent: true },
  // --- Format B: "this game is unhinged" (solo, your face is the paddle) ---
  { name: 'obs_cap1', html: caption(['weirdest game ever', 'and I’m <span class="hl">obsessed</span> 🤳'], HK), transparent: true },
  { name: 'obs_cap2', html: caption(['your REAL face', 'becomes the paddle 🏓'], TOP), transparent: true },
  { name: 'obs_cap3', html: caption(['wait… that’s literally', '<span class="hl">MY face</span> 🤯'], GP), transparent: true },
  { name: 'obs_cap4', html: caption(['I cannot stop', '<span class="hot">playing this</span> 💀'], GP), transparent: true },
  { name: 'obs_cap5', html: caption(['send help 😩', '<span class="lime">(and it’s free)</span>'], HK), transparent: true },
];

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
for (const j of jobs) {
  await page.setContent(j.html, { waitUntil: 'networkidle' });
  await page.screenshot({ path: path.join(dir, 'promo_video', 'work', j.name + '.png'), omitBackground: j.transparent });
  console.log('wrote promo_video/work/' + j.name + '.png');
}
await browser.close();
