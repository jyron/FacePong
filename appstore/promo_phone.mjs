// Renders the FacePong "connection" beat as a PHONE showing the face-as-paddle
// setup (1080x1920): a phone mockup of the FacePong pick screen where the player's
// REAL face becomes the cyan paddle (and, for the couple cut, the opponent's face
// becomes the magenta paddle) on a mini neon court — proving the real face goes
// straight into the game. Reuses Playwright + fonts from this repo's android module.
// Usage: node appstore/promo_phone.mjs <out.png> <face1_cutout.png> [face2_cutout.png]
import playwright from '/Users/jyron/src/faceslap/appstore/node_modules/playwright/index.js';
const { chromium } = playwright;
import { readFileSync } from 'fs';
import path from 'path';

const [, , outPath, face1, face2] = process.argv;
if (!outPath || !face1) { console.error('usage: promo_phone.mjs <out.png> <face1.png> [face2.png]'); process.exit(1); }

const fonts = '/Users/jyron/src/facepong/android/node_modules/@expo-google-fonts';
const grotesk = path.join(fonts, 'space-grotesk', '700Bold', 'SpaceGrotesk_700Bold.ttf');
const bungee = path.join(fonts, 'bungee', '400Regular', 'Bungee_400Regular.ttf');
const b64 = (p) => readFileSync(p).toString('base64');
const W = 1080, H = 1920;
const C = { bg: '#0a0918', cyan: '#19e7ff', magenta: '#ff2e88', lime: '#d4ff3d', text: '#a59fce' };

// A face rendered as the in-game paddle coin: circular cutout + neon ring + glow.
const coin = (facePath, color, size) => `
  <div style="position:relative;width:${size}px;height:${size}px;">
    <div style="position:absolute;inset:-14px;border-radius:50%;
      box-shadow:0 0 60px ${color}cc, 0 0 24px ${color}; background:${color}22;"></div>
    <div style="position:absolute;inset:0;border-radius:50%;overflow:hidden;
      border:6px solid ${color}; box-shadow:inset 0 0 0 2px #000a;">
      <img src="data:image/png;base64,${b64(facePath)}"
        style="width:118%;height:118%;object-fit:cover;object-position:center 40%;
        transform:translate(-8%,-6%);">
    </div>
  </div>`;

const couple = !!face2;
const courtInner = couple
  ? `${coin(face2, C.magenta, 200)}
     <div class="net"></div>
     <div class="ball"></div>
     ${coin(face1, C.cyan, 200)}`
  : `<div class="cpu">CPU</div>
     <div class="net"></div>
     <div class="ball"></div>
     ${coin(face1, C.cyan, 230)}`;

const html = `<!doctype html><html><head><style>
@font-face { font-family: Grotesk; src: url('data:font/ttf;base64,${b64(grotesk)}'); }
@font-face { font-family: Bungee; src: url('data:font/ttf;base64,${b64(bungee)}'); }
* { margin:0; padding:0; box-sizing:border-box; }
body { width:${W}px; height:${H}px; overflow:hidden; position:relative;
  background:
    radial-gradient(900px 720px at 50% 30%, ${C.cyan}26, transparent 70%),
    radial-gradient(1100px 900px at 50% 116%, ${C.magenta}24, transparent 70%),
    ${C.bg};
  display:flex; align-items:center; justify-content:center; }
.phone { width:660px; height:1380px; border-radius:84px; background:#04040a;
  border:14px solid #16161f; box-shadow:0 0 130px ${C.cyan}44, 0 40px 90px rgba(0,0,0,0.7);
  position:relative; overflow:hidden; transform:rotate(-2.5deg); }
.island { position:absolute; top:26px; left:50%; transform:translateX(-50%);
  width:128px; height:34px; background:#000; border-radius:20px; z-index:5; }
.screen { position:absolute; inset:14px; border-radius:70px; overflow:hidden;
  background:linear-gradient(180deg,#0c0a1c,#06060f);
  display:flex; flex-direction:column; align-items:center; }
.hdr { font-family:Bungee; font-size:40px; color:#fff; margin-top:92px; letter-spacing:1px;
  text-shadow:0 0 22px ${C.cyan}aa; }
.sub { font-family:Grotesk; font-weight:700; font-size:26px; color:${C.lime}; margin-top:16px;
  text-shadow:0 0 18px ${C.lime}66; }
.court { margin-top:48px; width:472px; height:720px; border-radius:42px; position:relative;
  background:
    radial-gradient(420px 300px at 50% 0%, ${C.magenta}18, transparent 70%),
    radial-gradient(420px 300px at 50% 100%, ${C.cyan}18, transparent 70%),
    #07060f;
  border:3px solid rgba(255,255,255,.10);
  box-shadow:0 0 50px ${C.cyan}33, inset 0 0 0 1px rgba(255,255,255,.04);
  display:flex; flex-direction:column; align-items:center; justify-content:space-between;
  padding:46px 0; overflow:hidden; }
.net { position:absolute; top:50%; left:7%; right:7%; height:2px;
  background:rgba(255,255,255,.16); transform:translateY(-50%); }
.net:after { content:''; position:absolute; left:50%; top:50%; width:64px; height:64px;
  border:2px solid rgba(255,255,255,.12); border-radius:50%; transform:translate(-50%,-50%); }
.ball { position:absolute; left:54%; top:42%; width:18px; height:18px; border-radius:50%;
  background:#fff; box-shadow:0 0 26px 8px ${C.lime}, 0 0 50px 14px ${C.lime}88; }
.cpu { font-family:Bungee; font-size:30px; color:${C.magenta}; opacity:.85;
  text-shadow:0 0 20px ${C.magenta}; padding:36px 0; }
.btn { margin-top:40px; font-family:Grotesk; font-weight:700; font-size:40px; color:#04040a;
  padding:30px 70px; border-radius:48px;
  background:linear-gradient(90deg, ${C.cyan}, ${C.lime}); box-shadow:0 0 50px ${C.cyan}aa; }
</style></head><body>
  <div class="phone">
    <div class="island"></div>
    <div class="screen">
      <div class="hdr">FACEPONG</div>
      <div class="sub">your face = your paddle 🏓</div>
      <div class="court">${courtInner}</div>
      <div class="btn">PLAY →</div>
    </div>
  </div>
</body></html>`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
await page.setContent(html, { waitUntil: 'networkidle' });
await page.screenshot({ path: outPath });
await browser.close();
console.log('wrote ' + outPath);
