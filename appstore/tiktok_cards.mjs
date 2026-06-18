// Renders the static 1080x1920 cards + transparent caption overlays for the
// FacePong TikTok concepts (war / trailer / bracket / yourface / satisfying).
// Photographic "tale of the tape" face-off cards use the raw celebrity-lookalike
// portraits (characters/raw/<id>.png) so the HARD CUT into the neon game coins is
// the joke; cinematic title cards + a VICTORY stamp + a tournament bracket round
// it out. Neon palette matches promo_caption.mjs / the shipping court.
// Run:  node appstore/tiktok_cards.mjs [namePrefix]   (prefix filters which jobs render)
import playwright from '/Users/jyron/src/faceslap/appstore/node_modules/playwright/index.js';
const { chromium } = playwright;
import { readFileSync, mkdirSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const dir = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(dir, 'promo_video', 'tiktok', 'cards');
mkdirSync(OUT, { recursive: true });

const fonts = '/Users/jyron/src/facepong/appstore/fonts';
const bungee = path.join(fonts, 'Bungee_400Regular.ttf');
const grotesk = path.join(fonts, 'SpaceGrotesk_700Bold.ttf');
const b64 = (p) => readFileSync(p).toString('base64');
const fontB64 = (p) => `data:font/ttf;base64,${b64(p)}`;
const raw = (id) => path.join(dir, 'characters', 'raw', `${id}.png`);
const cut = (id) => path.join(dir, 'characters', 'cut', `${id}_cutout.png`);
const img = (p) => `data:image/png;base64,${b64(p)}`;

const W = 1080, H = 1920;
const C = { bg: '#0a0918', cyan: '#19e7ff', magenta: '#ff2e88', lime: '#d4ff3d', amber: '#ffb02e' };
const NAME = {
  singer: 'THE SINGER', king: 'THE KING', tycoon: 'THE TYCOON', founder: 'THE FOUNDER',
  interesting: 'THE MOST INTERESTING MAN', wrestler: 'THE WRESTLER', champ: 'THE CHAMP',
  dictator: 'THE DICTATOR', president: 'THE PRESIDENT', chairman: 'THE CHAIRMAN',
};

const base = `
@font-face { font-family: Bungee; src: url('${fontB64(bungee)}'); }
@font-face { font-family: Grotesk; src: url('${fontB64(grotesk)}'); }
* { margin:0; padding:0; box-sizing:border-box; }
body { width:${W}px; height:${H}px; overflow:hidden; position:relative; }`;

// deterministic sparks/confetti so re-renders are stable
function sparks(seedStart = 11, n = 26) {
  let s = '', r = seedStart;
  const rnd = () => { r = (r * 16807) % 2147483647; return r / 2147483647; };
  const pal = [C.cyan, C.magenta, C.lime, '#fff'];
  for (let i = 0; i < n; i++) {
    const left = rnd() * W, top = rnd() * H;
    const sz = 6 + rnd() * 16, c = pal[Math.floor(rnd() * pal.length)];
    const rot = Math.floor(rnd() * 90) - 45, round = rnd() > 0.5 ? '50%' : '3px';
    s += `<div style="position:absolute;left:${left}px;top:${top}px;width:${sz}px;height:${sz}px;
      background:${c};border-radius:${round};opacity:${0.35 + rnd() * 0.5};
      transform:rotate(${rot}deg);box-shadow:0 0 ${sz * 1.8}px ${c};"></div>`;
  }
  return s;
}

// A photographic portrait in a neon-ringed panel (the "real life" face-off look).
const portraitPanel = (id, color, label, sub) => `
  <div style="position:relative;width:600px;">
    <div style="position:relative;width:600px;height:600px;border-radius:36px;overflow:hidden;
      border:8px solid ${color}; box-shadow:0 0 90px ${color}99, inset 0 0 60px rgba(0,0,0,.6);">
      <img src="${img(raw(id))}" style="width:100%;height:100%;object-fit:cover;object-position:center 28%;
        filter:contrast(1.12) saturate(1.05) brightness(.96);">
      <div style="position:absolute;inset:0;background:linear-gradient(180deg,transparent 55%,${color}22 100%);"></div>
    </div>
    <div style="font-family:Bungee;font-size:62px;color:#fff;text-align:center;margin-top:22px;
      text-shadow:0 0 34px ${color},0 0 14px ${color};letter-spacing:1px;">${label}</div>
    ${sub ? `<div style="font-family:Grotesk;font-weight:700;font-size:30px;color:${color};text-align:center;margin-top:8px;opacity:.9;">${sub}</div>` : ''}
  </div>`;

// A face rendered as the in-game neon paddle coin (cutout on a glowing disc).
const coin = (id, color, size) => `
  <div style="position:relative;width:${size}px;height:${size}px;">
    <div style="position:absolute;inset:-16px;border-radius:50%;box-shadow:0 0 70px ${color}cc,0 0 28px ${color};background:${color}22;"></div>
    <div style="position:absolute;inset:0;border-radius:50%;overflow:hidden;border:7px solid ${color};box-shadow:inset 0 0 0 2px #000a;">
      <img src="${img(cut(id))}" style="width:128%;height:128%;object-fit:cover;object-position:center 32%;transform:translate(-11%,-8%);">
    </div>
  </div>`;

// ---------- card templates ----------

// V1 face-off (photographic, tale-of-the-tape). top = magenta, bottom = cyan.
const faceoff = (topId, botId, hook) => `<!doctype html><html><head><style>${base}
body { background:
  radial-gradient(900px 700px at 50% 8%, ${C.magenta}33, transparent 62%),
  radial-gradient(900px 700px at 50% 96%, ${C.cyan}33, transparent 62%),
  ${C.bg};
  display:flex; flex-direction:column; align-items:center; }
.hook { font-family:Grotesk; font-weight:700; font-size:50px; color:#fff; text-align:center;
  margin-top:62px; padding:0 70px; -webkit-text-stroke:6px #000; paint-order:stroke fill;
  text-shadow:0 4px 0 rgba(0,0,0,.5),0 0 26px rgba(0,0,0,.6); line-height:1.05; }
.vs { position:absolute; top:50%; left:50%; transform:translate(-50%,-50%);
  font-family:Bungee; font-size:230px; color:#fff;
  text-shadow:0 0 60px ${C.magenta},0 0 30px ${C.cyan},0 0 12px #fff; z-index:5; }
.vs .b { color:${C.lime}; }
.stack { position:absolute; top:178px; left:50%; transform:translateX(-50%);
  display:flex; flex-direction:column; align-items:center; gap:96px; }
</style></head><body>
  ${sparks(7, 30)}
  ${hook ? `<div class="hook">${hook}</div>` : ''}
  <div class="stack">
    ${portraitPanel(topId, C.magenta, NAME[topId])}
    ${portraitPanel(botId, C.cyan, NAME[botId])}
  </div>
  <div class="vs">V<span class="b">S</span></div>
</body></html>`;

// V2 cinematic title card (deadpan epic). Optional sub line.
const title = (line, sub = '', accent = C.cyan) => `<!doctype html><html><head><style>${base}
body { background: radial-gradient(1200px 900px at 50% 50%, ${accent}14, transparent 70%), #05050b;
  display:flex; flex-direction:column; align-items:center; justify-content:center; }
.l { font-family:Bungee; font-size:118px; color:#fff; text-align:center; line-height:1.04; padding:0 70px;
  text-shadow:0 0 70px ${accent},0 0 24px ${accent}aa; }
.u { width:380px; height:9px; margin:48px auto 0; border-radius:6px;
  background:linear-gradient(90deg,${C.cyan},${C.lime},${C.magenta}); box-shadow:0 0 34px ${accent}cc; }
.s { font-family:Grotesk; font-weight:700; font-size:46px; color:#cfe9ff; text-align:center; margin-top:44px; padding:0 90px; line-height:1.2; }
.vig { position:absolute; inset:0; box-shadow: inset 0 0 360px 90px #000; pointer-events:none; }
</style></head><body>
  <div class="l">${line}</div>
  ${sub || line ? '<div class="u"></div>' : ''}
  ${sub ? `<div class="s">${sub}</div>` : ''}
  <div class="vig"></div>
</body></html>`;

// V3 tournament bracket. 8 rivals → final two. Champion box left empty (comment bait).
const bracketCard = (ids, finalA, finalB, champEmpty = true) => {
  const slot = (id, color) => `
    <div style="display:flex;align-items:center;gap:14px;">
      <div style="width:96px;height:96px;border-radius:50%;overflow:hidden;border:4px solid ${color};box-shadow:0 0 26px ${color}aa;flex:0 0 auto;">
        <img src="${img(raw(id))}" style="width:128%;height:128%;object-fit:cover;object-position:center 28%;transform:translate(-11%,-6%);">
      </div>
      <div style="font-family:Grotesk;font-weight:700;font-size:26px;color:#fff;line-height:1;">${NAME[id]}</div>
    </div>`;
  const col = (list, color) => `<div style="display:flex;flex-direction:column;gap:46px;">${list.map((id) => slot(id, color)).join('')}</div>`;
  const left = ids.slice(0, 4), right = ids.slice(4, 8);
  return `<!doctype html><html><head><style>${base}
  body { background: radial-gradient(900px 800px at 50% 6%, ${C.magenta}22, transparent 60%),
    radial-gradient(900px 800px at 50% 100%, ${C.cyan}22, transparent 60%), ${C.bg};
    display:flex; flex-direction:column; align-items:center; }
  .h { font-family:Bungee; font-size:78px; color:#fff; text-align:center; margin-top:84px; line-height:1;
    text-shadow:0 0 40px ${C.lime},0 0 16px ${C.lime}; }
  .grid { display:flex; justify-content:space-between; width:100%; padding:90px 60px 0; }
  .champ { margin-top:70px; width:560px; height:150px; border-radius:28px; border:5px dashed ${C.lime};
    display:flex; align-items:center; justify-content:center; box-shadow:0 0 50px ${C.lime}66;
    font-family:Bungee; font-size:${champEmpty ? 64 : 48}px; color:${C.lime}; text-shadow:0 0 24px ${C.lime}; }
  </style></head><body>
    ${sparks(5, 22)}
    <div class="h">LEADER<br>BRACKET 🏓</div>
    <div class="grid">${col(left, C.cyan)}${col(right, C.magenta)}</div>
    <div class="champ">${champEmpty ? '?' : 'CHAMPION'}</div>
  </body></html>`;
};

// V3 finalists + "you pick the winner" comment bait.
const pickWinner = (aId, bId) => `<!doctype html><html><head><style>${base}
body { background: radial-gradient(900px 700px at 30% 30%, ${C.cyan}26, transparent 62%),
  radial-gradient(900px 700px at 70% 30%, ${C.magenta}26, transparent 62%), ${C.bg};
  display:flex; flex-direction:column; align-items:center; }
.h { font-family:Bungee; font-size:72px; color:#fff; text-align:center; margin-top:120px;
  text-shadow:0 0 40px ${C.lime},0 0 16px ${C.lime}; }
.row { display:flex; align-items:center; gap:30px; margin-top:90px; }
.nm { font-family:Bungee; font-size:34px; text-align:center; margin-top:18px; }
.vs2 { font-family:Bungee; font-size:120px; color:#fff; text-shadow:0 0 40px ${C.lime}; }
.cta { font-family:Bungee; font-size:84px; color:${C.lime}; text-align:center; margin-top:120px;
  text-shadow:0 0 40px ${C.lime},0 0 14px ${C.lime}; }
.arrow { font-size:120px; text-align:center; margin-top:6px; }
</style></head><body>
  ${sparks(9, 22)}
  <div class="h">THE FINAL</div>
  <div class="row">
    <div><div>${coin(aId, C.cyan, 300)}</div><div class="nm" style="color:${C.cyan};text-shadow:0 0 22px ${C.cyan};">${NAME[aId]}</div></div>
    <div class="vs2">VS</div>
    <div><div>${coin(bId, C.magenta, 300)}</div><div class="nm" style="color:${C.magenta};text-shadow:0 0 22px ${C.magenta};">${NAME[bId]}</div></div>
  </div>
  <div class="cta">YOU PICK<br>THE WINNER</div>
  <div class="arrow">👇</div>
</body></html>`;

// Transparent VICTORY stamp overlay (for any concept's climax).
const stamp = (big, sub = '', color = C.lime) => `<!doctype html><html><head><style>${base}
.wrap { position:absolute; top:46%; left:50%; transform:translate(-50%,-50%) rotate(-9deg);
  display:flex; flex-direction:column; align-items:center; }
.big { font-family:Bungee; font-size:150px; color:#fff; text-align:center; line-height:.96;
  -webkit-text-stroke:5px ${color}; text-shadow:0 0 60px ${color},0 0 22px ${color}; }
.sub { font-family:Grotesk; font-weight:700; font-size:54px; color:${color}; margin-top:24px;
  -webkit-text-stroke:2px #000; paint-order:stroke fill; text-shadow:0 0 26px ${color}; }
</style></head><body>
  <div class="wrap"><div class="big">${big}</div>${sub ? `<div class="sub">${sub}</div>` : ''}</div>
</body></html>`;

// Transparent low caption (over gameplay) — never covers faces.
const caption = (lines, { top = 1360, size = 60 } = {}) => `<!doctype html><html><head><style>${base}
.wrap { position:absolute; top:${top}px; left:0; right:0; display:flex; flex-direction:column;
  align-items:center; gap:14px; padding:0 70px; }
.line { font-family:Grotesk; font-weight:700; font-size:${size}px; line-height:1.04; text-align:center;
  color:#fff; -webkit-text-stroke:7px #000; paint-order:stroke fill;
  text-shadow:0 5px 0 rgba(0,0,0,.55),0 0 30px rgba(0,0,0,.6); letter-spacing:-1px; }
.line .hl{color:${C.cyan};} .line .lime{color:${C.lime};} .line .hot{color:${C.magenta};}
</style></head><body><div class="wrap">${lines.map((l) => `<div class="line">${l}</div>`).join('')}</div></body></html>`;

// Branded FacePong end card (shared).
const endcard = (sub = 'your REAL face = the paddle 🏓', pill = 'FREE 👆 link in bio') => `<!doctype html><html><head><style>${base}
body { background: radial-gradient(900px 700px at 50% 38%, ${C.cyan}33, transparent 70%),
  radial-gradient(1100px 900px at 50% 112%, ${C.magenta}2e, transparent 70%), ${C.bg};
  display:flex; flex-direction:column; align-items:center; justify-content:center; }
.title { font-family:Bungee; font-size:154px; line-height:.98; text-align:center; color:#fff;
  text-shadow:0 0 90px ${C.cyan},0 0 34px ${C.cyan}cc,0 0 14px ${C.magenta}99; }
.title .p2{color:${C.cyan};}
.u { width:520px; height:13px; margin:46px auto 0; border-radius:7px;
  background:linear-gradient(90deg,${C.cyan},${C.lime},${C.magenta}); box-shadow:0 0 40px ${C.cyan}cc; }
.sub { font-family:Grotesk; font-weight:700; font-size:56px; text-align:center; color:#e8e2ff; margin:54px 60px 0; line-height:1.16; }
.pill { font-family:Grotesk; font-weight:700; font-size:46px; color:#04040a; margin-top:66px; padding:30px 64px;
  border-radius:60px; background:linear-gradient(90deg,${C.cyan},${C.lime}); box-shadow:0 0 60px ${C.cyan}aa; }
</style></head><body>
  ${sparks(13, 26)}
  <div class="title">FACE<br><span class="p2">PONG</span></div>
  <div class="u"></div>
  <div class="sub">${sub}</div>
  <div class="pill">${pill}</div>
</body></html>`;

// Transparent cinematic title, overlaid on continuous gameplay (no cut-to-black) — big
// Bungee text on a soft dark scrim + glow so it stays legible over the neon court.
const titleOverlay = (line, sub = '', accent = C.cyan) => `<!doctype html><html><head><style>${base}
.scrim { position:absolute; inset:0; background: radial-gradient(1200px 720px at 50% 46%, rgba(0,0,0,0.55), transparent 72%); }
.wrap { position:absolute; top:50%; left:0; right:0; transform:translateY(-50%); text-align:center; padding:0 70px; }
.l { font-family:Bungee; font-size:120px; color:#fff; line-height:1.02;
  text-shadow:0 0 70px ${accent}, 0 0 26px ${accent}, 0 6px 0 rgba(0,0,0,.55), 0 0 14px #000; }
.u { width:360px; height:9px; margin:40px auto 0; border-radius:6px;
  background:linear-gradient(90deg,${C.cyan},${C.lime},${C.magenta}); box-shadow:0 0 30px ${accent}; }
.s { font-family:Grotesk; font-weight:700; font-size:52px; color:#eaf6ff; margin-top:36px;
  text-shadow:0 3px 0 rgba(0,0,0,.6),0 0 18px #000; }
</style></head><body>
  <div class="scrim"></div>
  <div class="wrap"><div class="l">${line}</div>${(sub || line) ? '<div class="u"></div>' : ''}${sub ? `<div class="s">${sub}</div>` : ''}</div>
</body></html>`;

// ---------- jobs ----------
const BRACKET_IDS = ['president', 'chairman', 'dictator', 'tycoon', 'king', 'wrestler', 'champ', 'singer'];
const jobs = [
  // V1 WAR
  { name: 'war_faceoff', html: faceoff('dictator', 'president', 'two world leaders<br>settled it with PONG 😭'), t: false },
  { name: 'tycoon_singer_faceoff', html: faceoff('tycoon', 'singer', 'the tycoon vs<br>the pop princess'), t: false },
  { name: 'war_cap_reveal', html: caption(['wait those are', 'the <span class="hl">paddles</span> 💀'], { top: 1320 }), t: true },
  { name: 'war_cap_money', html: caption(['<span class="hot">RIGHT</span> in the face 😭'], { top: 1180, size: 64 }), t: true },
  { name: 'war_cap_final', html: caption(['no negotiations'], { top: 1320 }), t: true },
  { name: 'war_winner', html: stamp('VICTORY', 'new world order 👑', C.lime), t: true },
  // V2 TRAILER
  { name: 'tr_t1', html: title('TWO<br>SUPERPOWERS', '', C.magenta), t: false },
  { name: 'tr_t2', html: title('ONE<br>RALLY', '', C.cyan), t: false },
  { name: 'tr_t3', html: title('THE FATE OF<br>EVERYTHING', '', C.amber), t: false },
  { name: 'tr_o1', html: titleOverlay('TWO<br>SUPERPOWERS', '', C.magenta), t: true },
  { name: 'tr_o2', html: titleOverlay('ONE RALLY', '', C.cyan), t: true },
  { name: 'tr_o3', html: titleOverlay('THE FATE OF<br>EVERYTHING', '', C.amber), t: true },
  { name: 'tr_o_anti', html: titleOverlay('…it’s two faces.', 'bonking a ball.', C.lime), t: true },
  { name: 'tr_cap_hook', html: caption(['this rally', 'decided the <span class="hl">world</span>'], { top: 1300 }), t: true },
  { name: 'tr_cap_stakes', html: caption(['history. was. made.'], { top: 1300 }), t: true },
  { name: 'tr_anti', html: title('…it’s two faces.', 'bonking a ball.', C.lime), t: false },
  { name: 'tr_cap_body', html: caption(['i bodied <span class="hot">THE DICTATOR</span> 🏓'], { top: 1300 }), t: true },
  // V3 BRACKET
  { name: 'br_bracket', html: bracketCard(BRACKET_IDS, 'president', 'chairman'), t: false },
  { name: 'br_cap_hook', html: caption(['yes that’s his', '<span class="hl">real face</span> 💀'], { top: 1320 }), t: true },
  { name: 'br_cap_king', html: caption(['the king got bonked 💀'], { top: 1320 }), t: true },
  { name: 'br_cap_tycoon', html: caption(['<span class="lime">THE TYCOON</span>. round 1.'], { top: 1320 }), t: true },
  { name: 'br_cap_violent', html: caption(['this one got', '<span class="hot">violent</span> 😭'], { top: 1300 }), t: true },
  { name: 'br_pick', html: pickWinner('president', 'chairman'), t: false },
  // V4 YOURFACE caps (connection card via promo_phone.mjs)
  { name: 'yf_cap_what', html: caption(['wait <span class="lime">WHAT</span>'], { top: 1180, size: 70 }), t: true },
  { name: 'yf_cap_mine', html: caption(['that’s… <span class="hl">my face</span>'], { top: 1320 }), t: true },
  { name: 'yf_cap_bonk', html: caption(['every hit = <span class="hot">bonk</span>'], { top: 1300 }), t: true },
  { name: 'yf_cap_win', html: caption(['bodied <span class="hl">THE PRESIDENT</span> 💀'], { top: 1300 }), t: true },
  // V5 SATISFYING caps
  { name: 'sat_cap_face', html: caption(['wait that’s a <span class="hl">face</span> 🫠'], { top: 1320 }), t: true },
  { name: 'sat_cap_selfie', html: caption(['it’s YOUR selfie'], { top: 1320 }), t: true },
  { name: 'sat_cap_stop', html: caption(['i can’t stop', 'watching this 🌀'], { top: 1300 }), t: true },
  { name: 'sat_cap_loop', html: caption(['📍 free · link in bio'], { top: 1700, size: 46 }), t: true },
  // shared endcard
  { name: 'endcard', html: endcard(), t: false },
];

const prefix = process.argv[2] || '';
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
for (const j of jobs) {
  if (prefix && !j.name.startsWith(prefix)) continue;
  await page.setContent(j.html, { waitUntil: 'networkidle' });
  await page.screenshot({ path: path.join(OUT, j.name + '.png'), omitBackground: j.t });
  console.log('wrote cards/' + j.name + '.png');
}
await browser.close();
