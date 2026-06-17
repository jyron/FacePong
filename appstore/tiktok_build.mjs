// FacePong TikTok builder (v3). The rally plays as ONE CONTINUOUS take per video with
// captions FADING IN over the top (never cutting away mid-rally); cards are intro/outro
// bookends only. Audio is reconstructed from the game's own hit log: each real contact
// gets a pock, pitched on the SAME endless pentatonic Shepard rally as the app (one frame
// per hit, same pitch both players), panned to the ball's x, over a low ambient bed. 1080x1920, 30fps, stereo.
// Run:  node appstore/tiktok_build.mjs [key]
import { execFileSync } from 'child_process';
import { mkdirSync, writeFileSync, readFileSync } from 'fs';
import path from 'path';

const ROOT = '/Users/jyron/src/facepong/appstore/promo_video/tiktok';
const CARDS = path.join(ROOT, 'cards');
const GP = path.join(ROOT, 'gameplay');
const WK = path.join(ROOT, 'work');
const OUT = path.join(ROOT, 'final');
const SFX = '/Users/jyron/src/facepong/appstore/sfx_gen';
mkdirSync(WK, { recursive: true });
mkdirSync(OUT, { recursive: true });

const W = 1080, H = 1920, FPS = 30;
const VENC = ['-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p', '-r', String(FPS)];
const GPCROP = `scale=${W}:-2,crop=${W}:${H}:0:(ih-${H})/2,setsar=1,fps=${FPS}`;
const ff = (args) => execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-nostdin', ...args]);
const probe = (f) => parseFloat(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f]).toString().trim());
const card = (n) => path.join(CARDS, n + '.png');
const gpmov = (k) => path.join(GP, k + '_capture.mov');
const sfx = (n) => path.join(SFX, n + '.wav');

// Endless 2-octave vibraphone SHEPARD rally: one precomputed frame (shep_0..9) per hit. The
// pitch climbs two octaves then wraps inaudibly, so the rally rises forever with no audible
// loop point. Matches SoundManager.paddle so the ad sounds exactly like the game.
function shepFrame(rally) {
  return Math.max(0, rally - 1) % 10;
}

// ---------- event log + sync flash ----------
const _cap = {};
function captureEvents(key) {
  if (_cap[key]) return _cap[key];
  const mov = gpmov(key), yav = path.join(WK, `_yav_${key}.txt`);
  try { execFileSync('ffmpeg', ['-y', '-loglevel', 'quiet', '-nostdin', '-i', mov, '-vf', `signalstats,metadata=print:file=${yav}`, '-an', '-f', 'null', '-'], { stdio: 'ignore' }); } catch { /* warnings */ }
  let t = 0, best = -1, flashT = 0;
  for (const ln of readFileSync(yav, 'utf8').split('\n')) {
    let m = ln.match(/pts_time:([\d.]+)/); if (m) t = parseFloat(m[1]);
    m = ln.match(/YAVG=([\d.]+)/); if (m) { const v = parseFloat(m[1]); if (v > best) { best = v; flashT = t; } }
  }
  let sync = null; const raw = [];
  for (const ln of readFileSync(path.join(GP, key + '_events.log'), 'utf8').split('\n')) {
    const m = ln.match(/FPEVT (SYNC|HIT|WALL) (.+)/); if (!m) continue;
    const p = m[2].trim().split(/\s+/);
    if (m[1] === 'SYNC') sync = parseFloat(p[0]);
    else if (m[1] === 'HIT') raw.push({ kind: 'hit', slot: p[0], rally: +p[1], x: +p[2], gt: +p[3] });
    else if (m[1] === 'WALL') raw.push({ kind: 'wall', x: +p[0], gt: +p[1] });
  }
  return (_cap[key] = { events: sync == null ? [] : raw.map((e) => ({ ...e, vt: flashT + (e.gt - sync) })) });
}
const lr = (pan) => { const n = (Math.max(-1, Math.min(1, pan)) + 1) / 2; return [Math.cos(n * Math.PI / 2), Math.sin(n * Math.PI / 2)]; };

// ---------- clips ----------
function cardClip(name, img, d, { motion = 'none', fadein = 0, fadeout = 0 } = {}) {
  const out = path.join(WK, name + '.mp4');
  let v = motion === 'pushin'
    ? `[0:v]scale=1188:2112,zoompan=z='min(1+0.0013*on,1.10)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=${W}x${H}:fps=${FPS}`
    : `[0:v]scale=${W}:${H},fps=${FPS}`;
  if (fadein > 0) v += `,fade=t=in:st=0:d=${fadein}`;
  if (fadeout > 0) v += `,fade=t=out:st=${(d - fadeout).toFixed(2)}:d=${fadeout}`;
  v += ',setsar=1,format=yuv420p[v]';
  ff(['-framerate', String(FPS), '-loop', '1', '-t', String(d), '-i', img, '-filter_complex', v, '-map', '[v]', ...VENC, '-an', out]);
  return out;
}
// ONE continuous gameplay take with captions fading in/out over the top (no cut-aways).
function playCaptioned(name, key, ss, d, captions = []) {
  const out = path.join(WK, name + '.mp4');
  const args = ['-ss', String(ss), '-t', String(d), '-i', gpmov(key)];
  let fc = `[0:v]${GPCROP}[bg]`, prev = '[bg]';
  captions.forEach((c, k) => {
    args.push('-framerate', String(FPS), '-loop', '1', '-t', String(d), '-i', card(c.img));
    fc += `;[${k + 1}:v]format=rgba,fade=t=in:st=${c.from}:d=0.25:alpha=1,fade=t=out:st=${(c.to - 0.25).toFixed(2)}:d=0.25:alpha=1[c${k}]`;
    fc += `;${prev}[c${k}]overlay=0:0[v${k}]`; prev = `[v${k}]`;
  });
  fc += `;${prev}format=yuv420p[v]`;
  args.push('-filter_complex', fc, '-map', '[v]', '-t', String(d), ...VENC, '-an', out);
  ff(args);
  return out;
}
function stampClip(name, key, freezeSs, overlay, d) {
  const frame = path.join(WK, name + '_frz.png');
  ff(['-ss', String(freezeSs), '-i', gpmov(key), '-frames:v', '1', frame]);
  const out = path.join(WK, name + '.mp4');
  ff(['-framerate', String(FPS), '-loop', '1', '-t', String(d), '-i', frame, '-framerate', String(FPS), '-loop', '1', '-t', String(d), '-i', card(overlay),
    '-filter_complex', `[0:v]${GPCROP}[g];[g][1:v]overlay=0:0,fade=t=in:st=0:d=0.15,format=yuv420p[v]`, '-map', '[v]', ...VENC, '-an', out]);
  return out;
}

// ---------- audio ----------
const ACCENT = { fanfare: ['fanfare', 0.9], boom: ['milestone', 0.8], win: ['score', 0.85] };
function buildAudio(key, total, evs, ambVol) {
  const inputs = [], filters = [], mix = [];
  let idx = 0;
  inputs.push('-i', sfx('ambient'));
  filters.push(`[${idx++}:a]aformat=channel_layouts=stereo,volume=${ambVol},atrim=0:${total.toFixed(3)}[amb]`); mix.push('[amb]');
  let e = 0;
  for (const ev of evs) {
    inputs.push('-i', sfx(ev.base));
    const ms = Math.max(0, Math.round(ev.t * 1000));
    const [L, R] = lr(ev.pan);
    filters.push(`[${idx++}:a]asetrate=44100*${ev.ratio.toFixed(5)},aresample=44100,volume=${ev.vol.toFixed(3)},adelay=${ms}:all=1,pan=stereo|c0=${L.toFixed(3)}*c0|c1=${R.toFixed(3)}*c0[e${e}]`);
    mix.push(`[e${e}]`); e++;
  }
  filters.push(`${mix.join('')}amix=inputs=${mix.length}:normalize=0:dropout_transition=0,loudnorm=I=-14:TP=-1.5:LRA=11,atrim=0:${total.toFixed(3)},aresample=48000[a]`);
  const out = path.join(WK, key + '_audio.m4a');
  ff([...inputs, '-filter_complex', filters.join(';'), '-map', '[a]', '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', out]);
  return out;
}

function assemble(key, specs, ambVol) {
  const clips = [], evs = [];
  let t = 0, vi = 0;
  for (let i = 0; i < specs.length; i++) {
    const s = specs[i], name = `${key}_${i}`;
    let clip;
    if (s.type === 'card') clip = cardClip(name, card(s.img), s.d, s);
    else if (s.type === 'stamp') clip = stampClip(name, s.src, s.freezeSs, s.overlay, s.d);
    else clip = playCaptioned(name, s.src, s.ss, s.d, s.caps || []);
    const realD = probe(clip);
    if (s.type === 'play') {
      for (const ev of captureEvents(s.src).events) {
        if (ev.vt < s.ss || ev.vt > s.ss + realD) continue;
        const ft = t + (ev.vt - s.ss), pan = (ev.x * 2 - 1) * 0.7;
        if (ev.kind === 'hit') {
          evs.push({ base: 'shep_' + shepFrame(ev.rally), ratio: 1, t: ft, pan, vol: 1.0 });
        } else evs.push({ base: 'wall', ratio: 1, t: ft, pan, vol: 0.7 });
      }
    }
    if (s.accent) { const [f, v] = ACCENT[s.accent]; evs.push({ base: f, ratio: 1, t: t + (s.accentAt || 0), pan: 0, vol: v }); }
    clips.push(clip); t += realD;
  }
  const list = path.join(WK, key + '_list.txt');
  writeFileSync(list, clips.map((c) => `file '${c}'`).join('\n'));
  const mute = path.join(WK, key + '_mute.mp4');
  ff(['-f', 'concat', '-safe', '0', '-i', list, '-c', 'copy', mute]);
  const total = probe(mute);
  const audio = buildAudio(key, total, evs, ambVol);
  const out = path.join(OUT, `facepong-tiktok-${key}.mp4`);
  ff(['-i', mute, '-i', audio, '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', '-shortest', out]);
  console.log(`BUILT ${path.basename(out)}  ${total.toFixed(1)}s  ${evs.length} sounds`);
}

// ---------- manifests (one continuous rally each; cards are bookends) ----------
const VIDEOS = {
  war: { amb: 0.5, specs: [
    { type: 'card', img: 'war_faceoff', d: 2.0, motion: 'pushin', fadein: 0.3 },
    { type: 'play', src: 'war', ss: 7.0, d: 8.0, caps: [
      { img: 'war_cap_reveal', from: 0.3, to: 2.8 }, { img: 'war_cap_money', from: 3.3, to: 5.3 }, { img: 'war_cap_final', from: 5.8, to: 7.8 }] },
    { type: 'stamp', src: 'war', freezeSs: 14.9, overlay: 'war_winner', d: 1.5, accent: 'fanfare' },
    { type: 'card', img: 'endcard', d: 2.2, fadein: 0.3, fadeout: 0.3 },
  ] },
  trailer: { amb: 0.6, specs: [
    { type: 'play', src: 'war', ss: 7.0, d: 8.0, caps: [
      { img: 'tr_o1', from: 0.3, to: 2.3 }, { img: 'tr_o2', from: 2.6, to: 4.5 },
      { img: 'tr_o3', from: 4.8, to: 6.7 }, { img: 'tr_o_anti', from: 7.0, to: 7.95 }] },
    { type: 'card', img: 'endcard', d: 2.2, fadein: 0.3, fadeout: 0.3 },
  ] },
  bracket: { amb: 0.45, specs: [
    { type: 'play', src: 'trumpxi', ss: 7.5, d: 2.6, caps: [{ img: 'br_cap_hook', from: 0.3, to: 2.4 }] },
    { type: 'card', img: 'br_bracket', d: 1.8, fadein: 0.2, accent: 'boom' },
    { type: 'play', src: 'elvishogan', ss: 8.0, d: 2.6, caps: [{ img: 'br_cap_king', from: 0.2, to: 2.4 }] },
    { type: 'play', src: 'champsinger', ss: 8.0, d: 2.4, caps: [{ img: 'br_cap_violent', from: 0.2, to: 2.2 }] },
    { type: 'card', img: 'br_pick', d: 2.2, fadein: 0.2, accent: 'fanfare' },
    { type: 'card', img: 'endcard', d: 1.8, fadein: 0.3, fadeout: 0.3 },
  ] },
  yourface: { amb: 0.5, specs: [
    { type: 'card', img: 'yf_connect', d: 2.0, fadein: 0.2 },
    { type: 'play', src: 'yourface', ss: 8.0, d: 6.0, caps: [
      { img: 'yf_cap_what', from: 0.3, to: 2.3 }, { img: 'yf_cap_bonk', from: 2.8, to: 4.3 }, { img: 'yf_cap_win', from: 4.8, to: 5.9 }] },
    { type: 'card', img: 'endcard', d: 2.2, fadein: 0.3, fadeout: 0.3 },
  ] },
  satisfying: { amb: 0.85, specs: [
    { type: 'play', src: 'war', ss: 6.9, d: 8.0, caps: [
      { img: 'sat_cap_face', from: 0.5, to: 2.7 }, { img: 'sat_cap_selfie', from: 3.2, to: 5.4 }, { img: 'sat_cap_stop', from: 5.9, to: 7.8 }] },
    { type: 'card', img: 'endcard', d: 1.6, fadein: 0.3, fadeout: 0.3 },
  ] },
};

const only = process.argv[2];
for (const [key, v] of Object.entries(VIDEOS)) {
  if (only && key !== only) continue;
  assemble(key, v.specs, v.amb);
}
