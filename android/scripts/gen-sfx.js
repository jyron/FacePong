#!/usr/bin/env node
// Synthesizes the game's retro arcade sound effects into assets/sfx/*.wav so
// there are no licensing concerns and the whole SFX set stays a few KB.
// Re-run with `node scripts/gen-sfx.js` after tweaking; outputs are committed.
const fs = require('fs');
const path = require('path');

const SR = 22050; // sample rate — plenty for chiptune blips, keeps files tiny

// One note: sine+square blend (chip-ish but not harsh), 3ms attack, exponential
// decay. `slide` multiplies the frequency across the note (1 = no slide).
function note(freq, ms, { vol = 0.5, decay = 18, slide = 1 } = {}) {
  const n = Math.round((ms / 1000) * SR);
  const out = new Float32Array(n);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / n;
    const f = freq * Math.pow(slide, t);
    phase += (2 * Math.PI * f) / SR;
    const s = Math.sin(phase);
    const wave = 0.65 * s + 0.35 * Math.sign(s);
    const attack = Math.min(1, i / (0.003 * SR));
    out[i] = wave * vol * attack * Math.exp(-decay * t);
  }
  return out;
}

const silence = (ms) => new Float32Array(Math.round((ms / 1000) * SR));
const concat = (parts) => {
  const n = parts.reduce((a, p) => a + p.length, 0);
  const out = new Float32Array(n);
  let o = 0;
  for (const p of parts) {
    out.set(p, o);
    o += p.length;
  }
  return out;
};

function writeWav(name, samples) {
  const data = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    data.writeInt16LE(Math.round(v * 32767), i * 2);
  }
  const h = Buffer.alloc(44);
  h.write('RIFF', 0);
  h.writeUInt32LE(36 + data.length, 4);
  h.write('WAVEfmt ', 8);
  h.writeUInt32LE(16, 16);
  h.writeUInt16LE(1, 20); // PCM
  h.writeUInt16LE(1, 22); // mono
  h.writeUInt32LE(SR, 24);
  h.writeUInt32LE(SR * 2, 28);
  h.writeUInt16LE(2, 32);
  h.writeUInt16LE(16, 34);
  h.write('data', 36);
  h.writeUInt32LE(data.length, 40);
  const file = path.join(__dirname, '..', 'assets', 'sfx', name);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, Buffer.concat([h, data]));
  console.log(name, ((44 + data.length) / 1024).toFixed(1) + 'KB');
}

// Paddle hit — bright blip with a little upward chirp. Pitch is varied at
// runtime via playbackRate (rises with the rally, lower for the opponent).
writeWav('paddle.wav', note(660, 70, { vol: 0.55, decay: 14, slide: 1.25 }));

// Wall bounce — lower, quieter knock.
writeWav('wall.wav', note(290, 50, { vol: 0.34, decay: 16, slide: 0.92 }));

// You won the point — quick ascending arpeggio (C5 E5 G5 C6).
writeWav(
  'score.wav',
  concat([
    note(523.25, 80, { decay: 8 }),
    note(659.25, 80, { decay: 8 }),
    note(783.99, 80, { decay: 8 }),
    note(1046.5, 260, { decay: 7 }),
  ]),
);

// You lost the point — short descending womp.
writeWav(
  'lose.wav',
  concat([
    note(392, 110, { decay: 9, slide: 0.96 }),
    note(311.13, 110, { decay: 9, slide: 0.96 }),
    note(261.63, 220, { decay: 8, slide: 0.94 }),
  ]),
);

// Rally milestone — classic two-note coin.
writeWav('milestone.wav', concat([note(987.77, 70, { decay: 10 }), note(1318.5, 240, { decay: 7 })]));

// Countdown tick (the GO beep reuses this at a higher playbackRate).
writeWav('tick.wav', note(880, 60, { vol: 0.45, decay: 15 }));

// Match-won fanfare — arpeggio with an octave-doubled held last note.
const last = note(1046.5, 480, { decay: 5 });
const oct = note(2093, 480, { vol: 0.18, decay: 5 });
for (let i = 0; i < last.length; i++) last[i] += oct[i];
writeWav(
  'fanfare.wav',
  concat([
    note(523.25, 110, { decay: 7 }),
    note(659.25, 110, { decay: 7 }),
    note(783.99, 110, { decay: 7 }),
    silence(30),
    last,
  ]),
);
