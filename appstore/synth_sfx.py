#!/usr/bin/env python3
"""FacePong ASMR sound set — pure numpy + stdlib wave (no sox/scipy needed).
Design from the deep-research spec: a dry, close, satisfying ping-pong "pock"
(3 layers: transient click + inharmonic body + Karplus-Strong pluck), a soft
wall "tok", FM bells for score/lose/milestone/fanfare, a C-major-pentatonic
rally ladder, and a low ambient bed. 44.1 kHz / mono / 16-bit.
Usage: python3 synth_sfx.py <out_dir>
"""
import numpy as np, wave, os, sys

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
os.makedirs(OUT, exist_ok=True)


def write_wav(name, x, peak=0.89, gain=None):
    x = np.asarray(x, dtype=np.float64)
    if gain is None:                       # per-file peak normalise (default)
        m = np.max(np.abs(x)) or 1.0
        x = x / m * peak
    else:                                  # shared gain (keeps a Shepard cycle's
        x = x * gain                       # constant loudness intact across frames)
    xi = np.int16(np.clip(x, -1, 1) * 32767)
    with wave.open(os.path.join(OUT, name + '.wav'), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(xi.tobytes())
    print('wrote %-14s %5.3fs peak=%.2f' % (name + '.wav', len(x) / SR, peak))


def exp_env(dur, tau):
    return np.exp(-np.arange(int(SR * dur)) / SR / tau)


def _biquad(x, b0, b1, b2, a0, a1, a2):
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(x); x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        xi = x[i]; yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, xi; y2, y1 = y1, yi; y[i] = yi
    return y


def bandpass(x, f0, Q):
    w0 = 2 * np.pi * f0 / SR; a = np.sin(w0) / (2 * Q); c = np.cos(w0)
    return _biquad(x, a, 0, -a, 1 + a, -2 * c, 1 - a)


def lowpass(x, f0, Q=0.707):
    w0 = 2 * np.pi * f0 / SR; a = np.sin(w0) / (2 * Q); c = np.cos(w0)
    return _biquad(x, (1 - c) / 2, 1 - c, (1 - c) / 2, 1 + a, -2 * c, 1 - a)


def karplus(freq, dur, decay=0.992):
    N = max(2, round(SR / freq)); buf = np.random.uniform(-1, 1, N).astype(np.float64)
    out = np.zeros(int(SR * dur))
    for i in range(len(out)):
        out[i] = buf[i % N]
        buf[i % N] = decay * 0.5 * (buf[i % N] + buf[(i - 1) % N])
    return out


def pock(f0=420.0, dur=0.16, seed=0):
    """The satisfying paddle 'pock': transient click + inharmonic body + KS pluck."""
    np.random.seed(seed)
    t = np.arange(int(SR * dur)) / SR
    body = (np.sin(2 * np.pi * f0 * t) + 0.5 * np.sin(2 * np.pi * 2 * f0 * t)
            + 0.25 * np.sin(2 * np.pi * 3.1 * f0 * t)) * exp_env(dur, 0.045)
    ks = karplus(1.5 * f0, dur, 0.992) * 0.6
    trn = int(SR * 0.012)
    tr = bandpass(np.random.uniform(-1, 1, trn), 2600, 1.2) * np.exp(-np.arange(trn) / SR / 0.0025) * 1.4
    sig = body + ks
    sig[:trn] += tr
    return np.tanh(sig * 1.3)


# --- ASMR voices: alternative one-shots (same (f0,dur,seed) signature as pock) that can be
# Shepard-stacked on the same pentatonic notes. Softer attacks + warmer spectra than the pock. ---

def _atk(t, ms):                       # gentle raised-onset attack (no harsh click)
    return np.minimum(1.0, t / (ms / 1000.0))


def voice_drop(f0=300.0, dur=0.16, seed=0):
    """Water droplet: a sine that glides DOWN in pitch with a soft attack — classic ASMR 'ploink'."""
    n = int(SR * dur); t = np.arange(n) / SR
    f = f0 * (1.0 + 1.3 * np.exp(-t / 0.018))      # starts ~2.3x, settles to f0
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.tanh(np.sin(ph) * np.exp(-t / 0.055) * _atk(t, 4) * 1.1)


def voice_marimba(f0=300.0, dur=0.16, seed=0):
    """Soft wooden mallet: fundamental + the marimba 4th partial, warm and rounded."""
    n = int(SR * dur); t = np.arange(n) / SR
    sig = (np.sin(2 * np.pi * f0 * t)
           + 0.40 * np.sin(2 * np.pi * 3.9 * f0 * t) * np.exp(-t / 0.030)
           + 0.12 * np.sin(2 * np.pi * 9.2 * f0 * t) * np.exp(-t / 0.012))
    return np.tanh(sig * np.exp(-t / 0.065) * _atk(t, 3) * 1.1)


def voice_kalimba(f0=300.0, dur=0.16, seed=0):
    """Thumb piano: fundamental + slightly inharmonic overtones, metallic-warm pluck."""
    n = int(SR * dur); t = np.arange(n) / SR
    sig = (np.sin(2 * np.pi * f0 * t)
           + 0.5 * np.sin(2 * np.pi * 2.01 * f0 * t) * np.exp(-t / 0.05)
           + 0.2 * np.sin(2 * np.pi * 5.4 * f0 * t) * np.exp(-t / 0.02))
    return np.tanh(sig * np.exp(-t / 0.085) * _atk(t, 2) * 1.2)


def voice_glass(f0=300.0, dur=0.16, seed=0):
    """Soft crystalline ping: inharmonic bell partials, gentle attack, softened highs — tingly."""
    n = int(SR * dur); t = np.arange(n) / SR
    sig = (np.sin(2 * np.pi * f0 * t)
           + 0.6 * np.sin(2 * np.pi * 2.76 * f0 * t) * np.exp(-t / 0.06)
           + 0.3 * np.sin(2 * np.pi * 5.40 * f0 * t) * np.exp(-t / 0.03))
    return lowpass(np.tanh(sig * np.exp(-t / 0.10) * _atk(t, 5) * 1.1), 6500)


def voice_pop(f0=300.0, dur=0.16, seed=0):
    """Bubble/cork pop: a quick UP-blip resonant body + soft click — rubbery and playful."""
    np.random.seed(seed)
    n = int(SR * dur); t = np.arange(n) / SR
    f = f0 * (1.0 + 0.55 * (1 - np.exp(-t / 0.009)))   # quick upward blip
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / 0.032)
    click = bandpass(np.random.uniform(-1, 1, n), f0 * 2.5, 3.0) * np.exp(-t / 0.006) * 0.5
    return np.tanh((body + click) * 1.2)


def voice_felt(f0=300.0, dur=0.16, seed=0):
    """Soft felt tap: warm low-mid thud, slow soft attack, almost no transient — cozy/muffled."""
    np.random.seed(seed)
    n = int(SR * dur); t = np.arange(n) / SR
    sig = (np.sin(2 * np.pi * f0 * t) + 0.3 * np.sin(2 * np.pi * 1.5 * f0 * t)) * _atk(t, 8)
    thump = lowpass(np.random.uniform(-1, 1, n) * np.exp(-t / 0.010) * 0.3, 1200)
    return lowpass(np.tanh((sig * np.exp(-t / 0.05) + thump) * 1.0), 2600)


def voice_vibe(f0=240.0, dur=0.85, seed=0, decay=0.55, trem=5.0, depth=0.18,
               sharp=0.0, atk_ms=3.0):
    """Vibraphone bar: a strong PURE fundamental + the in-tune 4:1 overtone (two octaves up,
    exactly harmonic — no detuning) + a brief mallet shimmer, a soft mallet attack (no click),
    and the signature rotating-disc tremolo. No noise, no inharmonic partials — full, clean,
    and meant to ring out under reverb. Lower `f0` + long `decay` = full and bellowing.
    `sharp` (0..1) adds an arcade edge: an in-tune octave, an upper chime, and a fast bright
    onset ping (all harmonic) for a crisper, more arcade attack. Smaller `atk_ms` = sharper."""
    n = int(SR * dur); t = np.arange(n) / SR
    sig = (np.sin(2 * np.pi * f0 * t) * np.exp(-t / decay)
           + 0.32 * np.sin(2 * np.pi * 4.0 * f0 * t) * np.exp(-t / (decay * 0.45))
           + 0.06 * np.sin(2 * np.pi * 9.8 * f0 * t) * np.exp(-t / 0.05))
    if sharp > 0:                                      # brighter, snappier — arcade edge
        sig += sharp * 0.22 * np.sin(2 * np.pi * 2.0 * f0 * t) * np.exp(-t / (decay * 0.5))   # octave (brightens body)
        sig += sharp * 0.14 * np.sin(2 * np.pi * 6.0 * f0 * t) * np.exp(-t / 0.07)            # upper chime
        sig += sharp * 0.30 * np.sin(2 * np.pi * 4.0 * f0 * t) * np.exp(-t / 0.012)           # fast bright onset ping
    sig *= _atk(t, atk_ms)                             # soft mallet, no transient click
    sig *= (1.0 + depth * np.sin(2 * np.pi * trem * t))  # vibraphone tremolo ("the vibe")
    return np.tanh(sig * 0.95)


VOICES = {'pock': pock, 'drop': voice_drop, 'marimba': voice_marimba, 'kalimba': voice_kalimba,
          'glass': voice_glass, 'pop': voice_pop, 'felt': voice_felt, 'vibe': voice_vibe}


def reverb(x, wet=0.22, tail=0.18, rt=0.045, seed=7):
    """Reverb via convolution with a synthesised impulse: early reflections + a warm
    (lowpassed) exponential noise tail whose RT60 is set by `rt` (the noise decay tau).
    Short close room: tail=0.18, rt=0.045.  Lush hall (bellowing): tail≈1.5, rt≈0.4, wet≈0.35."""
    x = np.asarray(x, dtype=np.float64)
    n = int(SR * tail)
    rng = np.random.RandomState(seed)
    ir = rng.randn(n) * np.exp(-np.arange(n) / SR / rt)
    for d_ms, g in [(11, 0.5), (19, 0.4), (29, 0.3), (41, 0.22), (57, 0.16)]:  # early reflections
        i = int(SR * d_ms / 1000)
        if i < n:
            ir[i] += g
    ir = lowpass(ir, 5000)                                       # warm, not splashy
    ir /= (np.max(np.abs(ir)) or 1.0)
    wetsig = np.convolve(x, ir)
    out = np.zeros(len(x) + n)
    out[:len(x)] += x
    out[:len(wetsig)] += wet * wetsig[:len(out)]
    return out


def resample_pitch(x, r):
    """Pitch-shift by playback-rate r (r>1 = higher & shorter) via linear interpolation."""
    if abs(r - 1.0) < 1e-6:
        return np.asarray(x, dtype=np.float64).copy()
    m = max(1, int(len(x) / r))
    return np.interp(np.arange(m) * r, np.arange(len(x)), x).astype(np.float64)


def shepard_frame(theta, base=300.0, dur=0.16, seed=0, voice=None,
                  octs=range(-2, 3), mu=0.0, sigma=0.9, maxdur=0.22):
    """One frame of a Shepard scale: `voice` (default pock) stacked at octave offsets, weighted
    by a Gaussian over log-frequency centred at `mu`. As theta climbs 0->1 the perceived pitch
    rises, but the spectrum at theta is IDENTICAL to theta+1 (one octave up) — so a rally
    that advances theta climbs forever and the octave wrap is inaudible. `theta` is in
    octaves; any value works (the cycle is seamless modulo 1). The stack is capped to
    `maxdur` (with a short fade) so low octave layers stay a crisp hit, not a boomy tail."""
    p = (voice or pock)(f0=base, dur=dur, seed=seed)
    cap = int(SR * maxdur)
    out = np.zeros(cap)
    for k in octs:
        w = np.exp(-0.5 * ((theta + k - mu) / sigma) ** 2)
        if w < 0.02:
            continue
        lay = resample_pitch(p, 2.0 ** (theta + k)) * w
        out[:min(cap, len(lay))] += lay[:cap]
    fade = int(SR * 0.04)
    out[-fade:] *= np.linspace(1, 0, fade)        # avoid a hard truncation click
    return np.tanh(out * 0.9)


def fm_bell(f, dur, ratio=1.41, index0=4.5):
    t = np.arange(int(SR * dur)) / SR
    env = exp_env(dur, dur * 0.32)
    return np.sin(2 * np.pi * f * t + index0 * env * np.sin(2 * np.pi * f * ratio * t)) * env


def arp(freqs, dur, stag, index0, amps):
    total = int(SR * dur) + stag * len(freqs)
    out = np.zeros(total)
    for i, f in enumerate(freqs):
        b = fm_bell(f, dur, index0=index0) * amps[i]
        out[i * stag:i * stag + len(b)] += b
    return out


# Rally pitch design: a sharp, arcade VIBRAPHONE on a 2-octave pentatonic SHEPARD cycle.
# The app & ad index a frame per hit; the perceived pitch climbs two octaves then wraps
# seamlessly (in-tune octave shadows, no detune), so a rally rises endlessly with no audible
# loop point. 10 frames = 2 octaves of C-major pentatonic.
PENTA = [0, 2, 4, 7, 9]
RALLY_BASE = 230.0
RALLY_SPAN = 2                # octaves of perceived climb before the seamless wrap
RALLY_SIGMA = 1.5
RALLY_MU = 1.0
RALLY_FRAMES = 5 * RALLY_SPAN  # 10
RALLY_VP = dict(decay=0.40, dur=0.6, sharp=1.0, atk_ms=0.8, depth=0.10)
RALLY_REV = dict(wet=0.12, tail=0.65, rt=0.27)


def shep_vibe_frame(deg):
    """Dry frame `deg` of the 2-octave vibraphone Shepard cycle. Vibe layers are spaced
    RALLY_SPAN octaves apart (the vibe's 4:1 overtone fills the in-between octave); the
    Gaussian over log-frequency makes the wrap seamless. Reverb is added by the caller."""
    note = PENTA[deg % 5] + 12 * (deg // 5)        # pentatonic, climbing across the span
    frac = note / 12.0
    layers = []
    for j in range(-1, 3):
        oct = frac + RALLY_SPAN * j
        w = np.exp(-0.5 * ((oct - RALLY_MU) / RALLY_SIGMA) ** 2)
        if w < 0.02:
            continue
        layers.append(voice_vibe(f0=RALLY_BASE * 2 ** oct, **RALLY_VP) * w)
    m = max(len(l) for l in layers)
    out = np.zeros(m)
    for l in layers:
        out[:len(l)] += l
    return np.tanh(out * 0.8)


def main():
    # paddle: 5 humanised round-robin variants (fallback only — rally uses the shep frames)
    for s in range(5):
        write_wav('paddle_%d' % s, reverb(pock(f0=300, seed=s)))
    write_wav('paddle', reverb(pock(f0=300, seed=0)))  # legacy single (fallback)

    # Vibraphone Shepard rally cycle: one reverbed frame per degree (10 = 2 octaves). Shared
    # gain across frames preserves the Shepard constant-loudness (so the climb has no pumping).
    frames = [reverb(shep_vibe_frame(i), **RALLY_REV) for i in range(RALLY_FRAMES)]
    g = 0.89 / (max(np.max(np.abs(f)) for f in frames) or 1.0)
    for i, f in enumerate(frames):
        write_wav('shep_%d' % i, f, gain=g)

    # wall: soft duller 'tok', quieter + lower than the pock so it sits under it
    nw = np.random.uniform(-1, 1, int(SR * 0.045)); nw = bandpass(nw, 1500, 2.0)
    nw *= np.exp(-np.arange(len(nw)) / SR / 0.006)
    nw[:80] += np.random.uniform(-1, 1, 80) * np.exp(-np.arange(80) / 20) * 0.5
    write_wav('wall', reverb(np.tanh(nw * 1.1), wet=0.18), peak=0.7)

    # FM bells: score resolves UP (C major), lose resolves DOWN (minor)
    write_wav('score', arp([523.25, 659.25, 783.99, 1046.5], 0.9, int(SR * 0.09), 4.5, [1, .9, .85, .8]))
    write_wav('lose', arp([392.0, 311.13, 261.63], 0.9, int(SR * 0.11), 3.0, [1, .9, .85]))
    write_wav('milestone', fm_bell(1046.5, 0.5, index0=5.5))
    fan = arp([523.25, 659.25, 783.99, 1046.5, 1318.51], 1.4, int(SR * 0.085), 6.0, [1, 1, .95, .9, .85])
    ts = np.arange(int(SR * 1.4)) / SR
    fan[:len(ts)] += (np.sin(2 * np.pi * 523.25 * ts) + np.sin(2 * np.pi * 783.99 * ts)) * exp_env(1.4, 0.6) * 0.3
    write_wav('fanfare', fan)
    write_wav('tick', pock(f0=480, dur=0.08, seed=1))  # countdown blip

    # ambient bed: low warm drone, breathing, clickless loop
    t = np.arange(int(SR * 20)) / SR
    pad = np.zeros(len(t))
    for f in [65.41, 98.0, 130.81]:
        pad += np.sin(2 * np.pi * f * t) * (1 + 0.15 * np.sin(2 * np.pi * 0.08 * t))
    pad = lowpass(pad, 600)
    air = lowpass(np.random.randn(len(t)), 2000) * 10 ** (-40 / 20)
    bed = pad * 0.5 + air
    xf = int(SR * 0.05)
    fin, fout = np.sqrt(np.linspace(0, 1, xf)), np.sqrt(np.linspace(1, 0, xf))
    bed[:xf] = bed[:xf] * fin + bed[-xf:] * fout
    bed = bed[:-xf]
    write_wav('ambient', bed, peak=0.1)
    print('done')


if __name__ == '__main__':
    main()
