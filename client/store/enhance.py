# Post-process the raw gameplay captures into marketing "action" frames:
# a comet motion streak behind the ball, an impact flash at the striking
# paddle, and a confetti storm. Additive blending keeps the neon look of the
# game's own palette. Run: python3 enhance.py
import math
import random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

PALETTE = ['#19e7ff', '#ff2e88', '#d4ff3d', '#ffb347', '#ffffff']
HEAT = [(212, 255, 61), (255, 179, 71), (255, 77, 46)]  # lime -> amber -> red


def hex2rgb(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5))


def heat_color(t):
    # t 0..1 along lime->amber->red, blowing out to near-white at the head
    if t < 0.5:
        a, b, u = HEAT[0], HEAT[1], t * 2
    else:
        a, b, u = HEAT[1], HEAT[2], (t - 0.5) * 2
    c = [a[i] + (b[i] - a[i]) * u for i in range(3)]
    if t > 0.85:  # white-hot core near the ball
        w = (t - 0.85) / 0.15
        c = [v + (255 - v) * w * 0.7 for v in c]
    return tuple(int(v) for v in c)


def bezier(p0, p1, p2, t):
    x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
    y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
    return x, y


def enhance(src, dst, ball, tail_from, ctrl, impact=None, avoid=(), seed=7,
            confetti_n=46, tail_r=(5, 21)):
    im = Image.open(src).convert('RGB')
    w, h = im.size
    rng = random.Random(seed)

    glow = Image.new('RGB', (w, h), 'black')   # heavy halo, blurred a lot
    core = Image.new('RGB', (w, h), 'black')   # tight bright pass
    gd = ImageDraw.Draw(glow)
    cd = ImageDraw.Draw(core)

    # --- comet streak: tapered chain of discs along a bezier into the ball ---
    steps = 90
    for i in range(steps):
        t = i / (steps - 1)
        x, y = bezier(tail_from, ctrl, ball, t)
        r = tail_r[0] + (tail_r[1] - tail_r[0]) * t ** 1.3
        col = heat_color(t)
        a = 0.12 + 0.88 * t ** 1.6
        gcol = tuple(int(v * a) for v in col)
        gd.ellipse([x - r * 2.1, y - r * 2.1, x + r * 2.1, y + r * 2.1], fill=tuple(int(v * 0.55) for v in gcol))
        cd.ellipse([x - r, y - r, x + r, y + r], fill=gcol)
    # thin white-hot center line over the last stretch
    for i in range(steps // 2, steps):
        t = i / (steps - 1)
        x, y = bezier(tail_from, ctrl, ball, t)
        r = 2 + 5 * ((t - 0.5) * 2) ** 2
        a = int(235 * ((t - 0.5) * 2))
        cd.ellipse([x - r, y - r, x + r, y + r], fill=(a, a, a))

    # --- impact flash at the striking paddle ---
    if impact:
        ix, iy = impact
        gd.ellipse([ix - 150, iy - 150, ix + 150, iy + 150], fill=(70, 60, 28))
        cd.ellipse([ix - 56, iy - 56, ix + 56, iy + 56], fill=(120, 110, 60))
        for k in range(10):  # radial speed ticks
            ang = rng.uniform(0, math.tau)
            r0, r1 = 70 + rng.uniform(0, 30), 150 + rng.uniform(0, 80)
            x0, y0 = ix + math.cos(ang) * r0, iy + math.sin(ang) * r0
            x1, y1 = ix + math.cos(ang) * r1, iy + math.sin(ang) * r1
            cd.line([x0, y0, x1, y1], fill=(170, 160, 90), width=5)

    glow = glow.filter(ImageFilter.GaussianBlur(26))
    core = core.filter(ImageFilter.GaussianBlur(3))
    im = ImageChops.add(im, glow)
    im = ImageChops.add(im, core)

    # --- confetti storm (crisp, alpha-composited, plus additive glow) ---
    conf = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    cg = Image.new('RGB', (w, h), 'black')
    dd = ImageDraw.Draw(conf)
    gg = ImageDraw.Draw(cg)

    def blocked(x, y):
        for (ax, ay, ar) in avoid:
            if (x - ax) ** 2 + (y - ay) ** 2 < ar ** 2:
                return True
        return False

    placed = 0
    while placed < confetti_n:
        # bias placement toward the streak/impact action zone
        if rng.random() < 0.55:
            t = rng.random()
            bx, by = bezier(tail_from, ctrl, ball, t)
            x = bx + rng.gauss(0, 130)
            y = by + rng.gauss(0, 130)
        else:
            x = rng.uniform(60, w - 60)
            y = rng.uniform(420, h - 380)
        if not (0 < x < w and 380 < y < h - 300) or blocked(x, y):
            continue
        col = hex2rgb(rng.choice(PALETTE))
        s = rng.uniform(7, 21)
        a = int(rng.uniform(150, 255))
        gg.ellipse([x - s * 1.7, y - s * 1.7, x + s * 1.7, y + s * 1.7],
                   fill=tuple(int(v * 0.35) for v in col))
        if rng.random() < 0.5:
            dd.ellipse([x - s / 2, y - s / 2, x + s / 2, y + s / 2], fill=col + (a,))
        else:  # rotated rect = paper confetti
            ang = rng.uniform(0, math.pi)
            L, W2 = s, s * 0.45
            pts = []
            for sx, sy in [(-L, -W2), (L, -W2), (L, W2), (-L, W2)]:
                pts.append((x + sx * math.cos(ang) - sy * math.sin(ang),
                            y + sx * math.sin(ang) + sy * math.cos(ang)))
            dd.polygon(pts, fill=col + (a,))
        placed += 1

    cg = cg.filter(ImageFilter.GaussianBlur(10))
    im = ImageChops.add(im, cg)
    im = Image.alpha_composite(im.convert('RGBA'), conf).convert('RGB')
    im.save(dst)
    print('wrote', dst)


# Frame 1 (hero): the guy (bottom) just ripped it up-court — long comet
# sweeping from his paddle up to the white-hot ball under the woman.
enhance(
    'raw/02-gameplay-rally.png', 'raw/02-gameplay-action.png',
    ball=(843, 1067),
    tail_from=(1010, 2210), ctrl=(1190, 1560),
    impact=None,
    avoid=[(660, 640, 220), (800, 2410, 240)],  # keep faces clear
    seed=4,
    confetti_n=42,
)

# Frame 2 (RALLY X85): ball diving toward the guy at the bottom. Long streak
# sweeping down from upper court, around the rally text.
enhance(
    'raw/03-gameplay-clean.png', 'raw/03-gameplay-action.png',
    ball=(849, 2081),
    tail_from=(420, 1180), ctrl=(520, 1800),
    impact=None,
    avoid=[(660, 600, 210), (800, 2480, 240), (660, 1100, 0)],
    seed=23,
    confetti_n=40,
)
