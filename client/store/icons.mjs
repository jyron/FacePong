// Renders app-icon candidates at 1024x1024 into ./icons/. Run: node icons.mjs
import { chromium } from 'playwright';
import { readFileSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const dir = path.dirname(fileURLToPath(import.meta.url));
const bungee = path.join(dir, '..', 'node_modules', '@expo-google-fonts', 'bungee', '400Regular', 'Bungee_400Regular.ttf');
const font = `data:font/ttf;base64,${readFileSync(bungee).toString('base64')}`;

const BG = `
  radial-gradient(720px 720px at 50% 18%, rgba(123,59,255,.30), transparent 70%),
  repeating-linear-gradient(0deg, transparent 0 63px, rgba(255,255,255,.045) 63px 64px),
  repeating-linear-gradient(90deg, transparent 0 63px, rgba(255,255,255,.045) 63px 64px),
  #07070f`;

const head = `<style>
@font-face { font-family: Bungee; src: url('${font}'); }
* { margin:0; padding:0; }
body { width:1024px; height:1024px; overflow:hidden; position:relative; background:${BG}; }
</style>`;

// A — face-coin paddle (cyan) smashing a streaking ball up-right
const A = `${head}<body>
<svg width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="streak" x1="0" y1="1" x2="1" y2="0">
      <stop offset="0" stop-color="#d4ff3d" stop-opacity="0"/>
      <stop offset=".45" stop-color="#d4ff3d"/>
      <stop offset=".8" stop-color="#ffb347"/>
      <stop offset="1" stop-color="#ff4d2e"/>
    </linearGradient>
    <filter id="glow" x="-80%" y="-80%" width="260%" height="260%">
      <feGaussianBlur stdDeviation="22"/>
    </filter>
  </defs>
  <!-- streak -->
  <g>
    <path d="M 180 880 Q 430 760 700 360" stroke="url(#streak)" stroke-width="64" fill="none" stroke-linecap="round" filter="url(#glow)" opacity=".8"/>
    <path d="M 180 880 Q 430 760 700 360" stroke="url(#streak)" stroke-width="34" fill="none" stroke-linecap="round"/>
  </g>
  <!-- ball -->
  <circle cx="712" cy="340" r="86" fill="#ff4d2e" filter="url(#glow)" opacity=".9"/>
  <circle cx="712" cy="340" r="66" fill="#ffb347"/>
  <circle cx="712" cy="340" r="52" fill="#ffe9a8"/>
  <circle cx="690" cy="318" r="16" fill="#ffffff"/>
  <!-- face-coin paddle bottom-left -->
  <circle cx="300" cy="760" r="218" fill="#0c2730" filter="url(#glow)" opacity=".9"/>
  <circle cx="300" cy="760" r="196" fill="#0e3540" stroke="#19e7ff" stroke-width="22"/>
  <circle cx="232" cy="716" r="26" fill="#19e7ff"/>
  <circle cx="356" cy="716" r="26" fill="#19e7ff"/>
  <path d="M 216 818 Q 300 896 384 818" stroke="#19e7ff" stroke-width="26" fill="none" stroke-linecap="round"/>
  <!-- confetti -->
  <g>
    <rect x="120" y="160" width="26" height="12" rx="4" fill="#ff2e88" transform="rotate(28 133 166)"/>
    <rect x="860" y="640" width="28" height="12" rx="4" fill="#19e7ff" transform="rotate(-24 874 646)"/>
    <circle cx="220" cy="330" r="12" fill="#d4ff3d"/>
    <circle cx="900" cy="180" r="13" fill="#ff2e88"/>
    <rect x="560" y="120" width="26" height="12" rx="4" fill="#d4ff3d" transform="rotate(-18 573 126)"/>
    <circle cx="660" cy="860" r="12" fill="#ffb347"/>
    <rect x="420" y="430" width="24" height="11" rx="4" fill="#ffffff" transform="rotate(40 432 435)" opacity=".9"/>
    <circle cx="120" cy="560" r="10" fill="#19e7ff"/>
  </g>
</svg></body>`;

// B — two paddle arcs + streaking ball between (geometric, no face)
const B = `${head}<body>
<svg width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="s2" x1="0" y1="1" x2=".6" y2="0">
      <stop offset="0" stop-color="#d4ff3d" stop-opacity="0"/>
      <stop offset=".5" stop-color="#d4ff3d"/>
      <stop offset="1" stop-color="#ff4d2e"/>
    </linearGradient>
    <filter id="g2" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="20"/></filter>
  </defs>
  <line x1="80" y1="512" x2="944" y2="512" stroke="rgba(255,255,255,.14)" stroke-width="8" stroke-dasharray="6 38" stroke-linecap="round"/>
  <!-- top paddle (magenta) -->
  <path d="M 250 178 Q 512 88 774 178" stroke="#ff2e88" stroke-width="74" fill="none" stroke-linecap="round" filter="url(#g2)" opacity=".75"/>
  <path d="M 250 178 Q 512 88 774 178" stroke="#ff2e88" stroke-width="56" fill="none" stroke-linecap="round"/>
  <!-- bottom paddle (cyan) -->
  <path d="M 250 846 Q 512 936 774 846" stroke="#19e7ff" stroke-width="74" fill="none" stroke-linecap="round" filter="url(#g2)" opacity=".75"/>
  <path d="M 250 846 Q 512 936 774 846" stroke="#19e7ff" stroke-width="56" fill="none" stroke-linecap="round"/>
  <!-- streak + ball -->
  <path d="M 320 800 Q 470 660 660 330" stroke="url(#s2)" stroke-width="58" fill="none" stroke-linecap="round" filter="url(#g2)" opacity=".85"/>
  <path d="M 320 800 Q 470 660 660 330" stroke="url(#s2)" stroke-width="30" fill="none" stroke-linecap="round"/>
  <circle cx="672" cy="308" r="92" fill="#ff4d2e" filter="url(#g2)" opacity=".9"/>
  <circle cx="672" cy="308" r="68" fill="#ffb347"/>
  <circle cx="672" cy="308" r="52" fill="#ffe9a8"/>
  <circle cx="650" cy="286" r="16" fill="#ffffff"/>
</svg></body>`;

// C — Bungee wordmark, stacked, with the pulse ball between words
const C2 = `${head}<body>
<div style="position:absolute; inset:0; display:flex; flex-direction:column; align-items:center; justify-content:center;">
  <div style="font-family:Bungee; font-size:218px; line-height:.94; color:#19e7ff; text-shadow:0 0 80px #19e7ff, 0 0 26px rgba(25,231,255,.8);">FACE</div>
  <div style="font-family:Bungee; font-size:218px; line-height:.94; color:#ff2e88; text-shadow:0 0 80px #ff2e88, 0 0 26px rgba(255,46,136,.8);">PONG</div>
</div>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" style="position:absolute; inset:0;">
  <defs><filter id="g3" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="16"/></filter></defs>
  <circle cx="876" cy="276" r="44" fill="#d4ff3d" filter="url(#g3)" opacity=".9"/>
  <circle cx="876" cy="276" r="32" fill="#d4ff3d"/>
  <circle cx="864" cy="264" r="9" fill="#ffffff"/>
  <path d="M 700 430 Q 800 360 852 306" stroke="#d4ff3d" stroke-width="18" fill="none" stroke-linecap="round" opacity=".55"/>
</svg></body>`;

// D — the ball IS a face: big lime smiley ball squashed mid-bounce + streak
const D = `${head}<body>
<svg width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="s4" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#d4ff3d" stop-opacity="0"/>
      <stop offset=".6" stop-color="#d4ff3d"/>
      <stop offset="1" stop-color="#ffb347"/>
    </linearGradient>
    <filter id="g4" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="24"/></filter>
  </defs>
  <!-- streak in from top-left -->
  <path d="M 110 110 Q 300 240 470 430" stroke="url(#s4)" stroke-width="70" fill="none" stroke-linecap="round" filter="url(#g4)" opacity=".8"/>
  <path d="M 110 110 Q 300 240 470 430" stroke="url(#s4)" stroke-width="40" fill="none" stroke-linecap="round"/>
  <!-- impact ring -->
  <ellipse cx="560" cy="560" rx="330" ry="318" fill="none" stroke="#19e7ff" stroke-width="14" opacity=".5" filter="url(#g4)"/>
  <!-- ball face (squashed) -->
  <ellipse cx="560" cy="572" rx="292" ry="262" fill="#d4ff3d" filter="url(#g4)" opacity=".85"/>
  <ellipse cx="560" cy="572" rx="270" ry="242" fill="#d4ff3d"/>
  <ellipse cx="560" cy="572" rx="270" ry="242" fill="url(#s4)" opacity=".25"/>
  <!-- eyes squint with impact -->
  <path d="M 420 500 Q 466 458 512 500" stroke="#07070f" stroke-width="30" fill="none" stroke-linecap="round"/>
  <path d="M 612 500 Q 658 458 704 500" stroke="#07070f" stroke-width="30" fill="none" stroke-linecap="round"/>
  <!-- big grin -->
  <path d="M 412 626 Q 560 760 708 626" stroke="#07070f" stroke-width="34" fill="none" stroke-linecap="round"/>
  <path d="M 446 652 Q 560 744 674 652" fill="#07070f"/>
  <!-- highlight -->
  <ellipse cx="446" cy="430" rx="56" ry="38" fill="#ffffff" opacity=".7" transform="rotate(-24 446 430)"/>
  <!-- confetti -->
  <circle cx="880" cy="300" r="14" fill="#ff2e88"/>
  <rect x="846" y="760" width="30" height="13" rx="4" fill="#19e7ff" transform="rotate(-22 861 766)"/>
  <circle cx="170" cy="700" r="12" fill="#ffb347"/>
  <rect x="240" y="860" width="28" height="12" rx="4" fill="#ff2e88" transform="rotate(30 254 866)"/>
</svg></body>`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
for (const [name, html] of [['icon-A-face-paddle', A], ['icon-B-arcs', B], ['icon-C-wordmark', C2], ['icon-D-smiley-ball', D]]) {
  await page.setContent(html, { waitUntil: 'networkidle' });
  await page.screenshot({ path: path.join(dir, 'icons', `${name}.png`) });
  console.log('wrote icons/' + name + '.png');
}
await browser.close();
