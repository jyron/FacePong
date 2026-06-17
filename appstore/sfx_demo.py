#!/usr/bin/env python3
"""Render listenable rally demos of different pitch schemes so the most appealing one
can be chosen by ear. Each demo is a ~10s accelerating rally (panned L/R like real
gameplay) over the ambient bed, lower-pitched + reverby. Writes stereo WAVs to
appstore/sfx_gen/demos/.  Usage: python3 sfx_demo.py
"""
import numpy as np, wave, os
import synth_sfx as S

SR = S.SR
BASE = 300.0
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'sfx_gen', 'demos')
os.makedirs(OUT, exist_ok=True)
PENTA = [0, 2, 4, 7, 9]


def load_wav(path):
    with wave.open(path, 'r') as w:
        n, ch = w.getnframes(), w.getnchannels()
        a = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64) / 32768.0
    return a[::ch] if ch > 1 else a


def write_stereo(name, st, peak=0.95):
    m = np.max(np.abs(st)) or 1.0
    xi = np.int16(np.clip(st / m * peak, -1, 1) * 32767)
    inter = np.empty(xi.shape[1] * 2, dtype=np.int16)
    inter[0::2], inter[1::2] = xi[0], xi[1]
    with wave.open(os.path.join(OUT, name + '.wav'), 'w') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(inter.tobytes())
    print('wrote %-26s %4.1fs' % (name + '.wav', st.shape[1] / SR))


def rally_times(n=26, start=0.45, gap0=0.5, accel=0.965, floor=0.155):
    ts, t, gap = [], start, gap0
    for _ in range(n):
        ts.append(t); t += gap; gap = max(floor, gap * accel)
    return ts


def place(track, sig, t, pan, vol):
    i = int(t * SR); end = i + len(sig)
    if end > track.shape[1]:
        track = np.pad(track, ((0, 0), (0, end - track.shape[1])))
    nn = (max(-1, min(1, pan)) + 1) / 2
    track[0, i:end] += sig * vol * np.cos(nn * np.pi / 2)
    track[1, i:end] += sig * vol * np.sin(nn * np.pi / 2)
    return track


def render(name, hit_sig, amb=True):
    """hit_sig(k) -> mono waveform for the k-th hit of the rally."""
    ts = rally_times()
    track = np.zeros((2, int((ts[-1] + 1.6) * SR)))
    if amb:                                  # quiet ambient bed underneath
        try:
            bed = load_wav(os.path.join(HERE, 'sfx_gen', 'ambient.wav'))
            bed = np.resize(bed, track.shape[1]) * 0.5
            track[0] += bed; track[1] += bed
        except Exception:
            pass
    for k, t in enumerate(ts):
        track = place(track, hit_sig(k), t, 0.55 if k % 2 == 0 else -0.55, 0.9)
    write_stereo(name, track)


# --- scheme A: pentatonic Shepard, advances every HIT (endless rising riff) ---
def penta_perhit(k):
    note = PENTA[k % 5] + 12 * (k // 5)
    return S.reverb(S.shepard_frame(note / 12.0, base=BASE, seed=k % 5))


# --- scheme B: smooth Shepard, 7 equal steps/octave every HIT (siren-smooth rise) ---
def smooth_perhit(k):
    return S.reverb(S.shepard_frame(k * (12.0 / 7) / 12.0, base=BASE, seed=k % 5))


# --- scheme C: pentatonic Shepard, advances every EXCHANGE (1-1-2-2, but endless) ---
def penta_exchange(k):
    step = k // 2
    note = PENTA[step % 5] + 12 * (step // 5)
    return S.reverb(S.shepard_frame(note / 12.0, base=BASE, seed=k % 5))


# --- scheme D: pentatonic random walk, no Shepard (no loop point at all, organic) ---
def meander():
    rng = np.random.RandomState(11)
    deg = [4]  # start mid-scale

    def f(k):
        if k > 0:
            nxt = deg[-1] + rng.choice([-1, -1, 0, 1, 1])  # gentle, centred drift
            deg.append(max(0, min(9, nxt)))                # ~1.5 octave window
        d = deg[-1]
        note = PENTA[d % 5] + 12 * (d // 5)
        return S.reverb(S.pock(f0=BASE * 2 ** (note / 12), seed=k % 5))
    return f


# --- ASMR timbre options: SAME option-A pitch pattern (pentatonic per-hit Shepard, the
# notes that were liked), only the voice changes. A touch more reverb for intimate space. ---
def penta_perhit_voice(voice):
    def f(k):
        note = PENTA[k % 5] + 12 * (k // 5)
        return S.reverb(S.shepard_frame(note / 12.0, base=BASE, seed=k % 5, voice=voice), wet=0.30)
    return f


# --- CLEAN: the ORIGINAL single clean pock, pitched per hit (no octave-stacking, no reverb
# -> full clarity). "Endless" is solved by climbing then DESCENDING (triangle) so the pitch
# never hits a ceiling and never hard-resets — the turn is musical, not a jarring loop. ---
def clean_climb(base=BASE, wet=0.0):
    ladder = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]   # 2 octaves of C pentatonic, then reset
    def f(k):
        p = S.pock(f0=base * 2 ** (ladder[k % len(ladder)] / 12), seed=k % 5)
        return S.reverb(p, wet=wet) if wet > 0 else p
    return f


def clean_pingpong(base=BASE, wet=0.0):
    up = [0, 2, 4, 7, 9, 12, 14, 16]               # ~1.3 octaves up...
    seq = up + up[-2:0:-1]                          # ...then back down (no repeated turn notes)
    def f(k):
        p = S.pock(f0=base * 2 ** (seq[k % len(seq)] / 12), seed=k % 5)
        return S.reverb(p, wet=wet) if wet > 0 else p
    return f


# --- VIBRAPHONE: full, bellowing, pure (no detuning), ringing under a lush reverb. Same
# pentatonic notes as option A; climbs then descends so it's endless without a hard reset.
# Long ring + pentatonic = overlapping notes pile into a consonant, gorgeous vibe cloud. ---
UP = [0, 2, 4, 7, 9, 12, 14, 16]
PINGPONG = UP + UP[-2:0:-1]
CLIMB = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]


def vibe(seq, base=240, decay=0.55, dur=0.85, trem=5.0, depth=0.18,
         sharp=0.0, atk_ms=3.0, wet=0.35, tail=1.5, rt=0.4):
    def f(k):
        note = seq[k % len(seq)]
        v = S.voice_vibe(f0=base * 2 ** (note / 12), dur=dur, decay=decay, trem=trem,
                         depth=depth, sharp=sharp, atk_ms=atk_ms, seed=k % 5)
        return S.reverb(v, wet=wet, tail=tail, rt=rt)
    return f


# --- ENDLESS: EXACTLY the demo_arcade_climb vibe, made perpetually-ascending via a Shepard
# cycle. The played note is the climbing pentatonic note; in-tune octave shadows (no detune)
# cross-fade so the climb never hits a ceiling and the wrap is inaudible. Period = 5 hits
# (one pentatonic octave) but it sounds like it rises forever. `sigma` sets how loud the
# octave shadows are (smaller = closer to a single note, larger = fuller/smoother wrap). ---
# sharper/more arcade + drier than before
ARCADE_VP = dict(decay=0.42, dur=0.65, sharp=0.95, atk_ms=1.0, depth=0.12)
ARCADE_REV = dict(wet=0.15, tail=0.7, rt=0.28)


def endless(base=230, span=2, sigma=1.5, mu=1.0, vp=None, rev=None):
    """Perpetual-climb Shepard over `span` octaves. Shepard layers are spaced `span` octaves
    apart (so the perceived climb covers `span` octaves before the seamless wrap); the vibe's
    own 4:1 overtone fills the in-between octave. period = 5*span hits."""
    vp = vp or ARCADE_VP; rev = rev or ARCADE_REV
    period = 5 * span
    def f(k):
        deg = k % period
        note = PENTA[deg % 5] + 12 * (deg // 5)    # pentatonic, climbing across `span` octaves
        frac = note / 12.0                          # 0 .. span
        layers = []
        for j in range(-1, 3):
            oct = frac + span * j                   # layers spaced `span` octaves apart
            w = np.exp(-0.5 * ((oct - mu) / sigma) ** 2)
            if w < 0.02:
                continue
            layers.append(S.voice_vibe(f0=base * 2 ** oct, seed=k % 5, **vp) * w)
        m = max(len(l) for l in layers)
        out = np.zeros(m)
        for l in layers:
            out[:len(l)] += l
        return S.reverb(np.tanh(out * 0.8), **rev)
    return f


if __name__ == '__main__':
    import sys
    if 'endless' in sys.argv or len(sys.argv) == 1:
        render('demo_endless2', endless(base=230, span=2, sigma=1.5, mu=1.0), amb=False)   # 2-octave climb, sharper, less verb
        render('demo_endless2_drier', endless(base=230, span=2, sigma=1.5, mu=1.0,
                                              rev=dict(wet=0.10, tail=0.6, rt=0.26)), amb=False)  # even less reverb
        render('demo_endless2_sharper', endless(base=230, span=2, sigma=1.5, mu=1.0,
                                               vp=dict(decay=0.40, dur=0.6, sharp=1.0, atk_ms=0.8, depth=0.10),
                                               rev=dict(wet=0.12, tail=0.65, rt=0.27)), amb=False)  # max bite
    if 'arcade' in sys.argv:
        # sharper, more arcade, less reverb than demo_vibe_full
        render('demo_arcade', vibe(PINGPONG, base=230, decay=0.45, dur=0.7, sharp=0.7,
                                   atk_ms=1.5, depth=0.14, wet=0.22, tail=1.0, rt=0.32), amb=False)   # the pick
        render('demo_arcade_sharper', vibe(PINGPONG, base=240, decay=0.40, dur=0.6, sharp=1.0,
                                           atk_ms=1.0, depth=0.12, wet=0.18, tail=0.85, rt=0.28), amb=False)  # crisper, drier
        render('demo_arcade_softer', vibe(PINGPONG, base=220, decay=0.50, dur=0.8, sharp=0.5,
                                          atk_ms=2.0, depth=0.16, wet=0.26, tail=1.2, rt=0.36), amb=False)    # fuller, a bit more verb
        render('demo_arcade_climb', vibe(CLIMB, base=230, decay=0.45, dur=0.7, sharp=0.7,
                                         atk_ms=1.5, depth=0.14, wet=0.22, tail=1.0, rt=0.32), amb=False)     # pure ascending
    if 'vibe' in sys.argv:
        render('demo_vibe_full', vibe(PINGPONG, base=220, decay=0.6, dur=0.9,
                                      wet=0.38, tail=1.6, rt=0.42), amb=False)          # FULL + bellowing
        render('demo_vibe_big', vibe(PINGPONG, base=220, decay=0.6, dur=0.9,
                                     wet=0.5, tail=2.4, rt=0.6), amb=False)             # cathedral reverb
    if 'clean' in sys.argv:
        render('demo_clean_climb', clean_climb(base=300), amb=False)         # lower pitch, climb+reset
        render('demo_clean_pingpong', clean_pingpong(base=300), amb=False)   # lower, climb+descend (endless)
        render('demo_clean_pingpong_420', clean_pingpong(base=420), amb=False)  # ORIGINAL pitch
        render('demo_clean_warm', clean_pingpong(base=300, wet=0.10), amb=False)  # hair of reverb
    if 'asmr' in sys.argv:
        for name in ['drop', 'marimba', 'kalimba', 'glass', 'pop', 'felt']:
            render('demo_asmr_' + name, penta_perhit_voice(S.VOICES[name]))
    if 'schemes' in sys.argv:
        render('demo_A_penta_perhit', penta_perhit)
        render('demo_B_smooth_perhit', smooth_perhit)
        render('demo_C_penta_exchange', penta_exchange)
        render('demo_D_meander', meander())
    print('\nlisten:  for f in appstore/sfx_gen/demos/demo_asmr_*.wav; do echo $f; afplay $f; done')
