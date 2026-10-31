"""Make assets/water/stage-water-4x30.json, the stage water texture.

Run from the project folder (needs the ROM files in roms/):
    .venv/bin/python assets/water/make_water.py [output.json]

The arcade's stage water is a 64x64 block of three blues with fine dots over
soft waves. The port shows water through 120 palette entries that rotate one
step per picture, so the texture must be made of K patterns of P lines (here
4 x 30) placed in columns. This script fits such a texture to the arcade water:

1. Wave picture: the arcade water blurred (sigma 1.5), resized from 64 to S
   lines with a Fourier resize, so K patterns of P lines fit it exactly.
2. Each of the S columns uses one pattern at its own offset (rigid motion).
3. Each pattern entry is one of the 3 arcade blues. Simulated annealing picks
   them so that the blurred texture matches the wave picture, the dots sit next
   to each other as the arcade dots do, and neighbour columns do not copy each
   other. The colour mix stays exactly the arcade's.

Orientation: row 0 = top of the screen; the water moves down.
"""

import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "scripts"))
from arcade import Arcade  # noqa: E402

K, P, SEED, ITERS, S, WST, CP = 4, 30, 1, 300000, 60, 2.0, 0.05


def arcade_water(a):
    """Stage-1 water: the first 64x64 block of the sea map, in screen orientation."""

    def pixel(x, y):
        at = 0x8000 + 2 * ((x // 32) * 8 + y // 32)
        code, attr = a.maps[at], a.maps[at + 1]
        tile = a.gfx[2][code % len(a.gfx[2])]
        flip = (attr >> 6) & 3
        return a.colors[2][
            ((attr >> 2) & 15) * 16
            + tile[
                (31 - y % 32 if flip & 2 else y % 32) * 32 + (31 - x % 32 if flip & 1 else x % 32)
            ]
        ]

    return np.array([[pixel(r, c) for c in range(64)] for r in range(64)], dtype=np.int16)[::-1]


def fit(F):
    u = np.unique(F)
    T = np.searchsorted(u, F)
    LUM = np.array([81, 98, 112.0])
    lum = LUM[T]
    mix = np.bincount(T.ravel(), minlength=3) / T.size

    def blur(A, sig=1.5):
        k = np.arange(-6, 7)
        g = np.exp(-(k**2) / (2 * sig**2))
        g /= g.sum()
        B = sum(w * np.roll(A, i, 0) for i, w in zip(k, g))
        return sum(w * np.roll(B, i, 1) for i, w in zip(k, g))

    def fresize(A, n):
        f = np.fft.fftshift(np.fft.fft2(A))
        c = A.shape[0] // 2
        h = n // 2
        g = f[c - h : c - h + n, c - h : c - h + n]
        return np.real(np.fft.ifft2(np.fft.ifftshift(g))) * (n * n) / (A.shape[0] ** 2)

    V = fresize(blur(lum), S)
    var = ((V - V.mean()) ** 2).mean()
    OFF = [(0, dx) for dx in range(1, 4)] + [(dy, dx) for dy in range(1, 4) for dx in range(-3, 4)]

    def cooc(G):
        out = []
        for dy, dx in OFF:
            B = np.roll(np.roll(G, -dy, 0), -dx, 1)
            C = np.bincount((G * 3 + B).ravel(), minlength=9).astype(float)
            out.append(C / C.sum())
        return np.array(out)

    TA = cooc(T)
    EXP = np.outer(mix, mix).ravel()
    rng = np.random.default_rng(SEED)
    # Start: K continuous profiles with per-column offsets (shift-invariant
    # clustering of the wave columns).
    cols = (V - V.mean()).T.reshape(S, S // P, P).mean(1)
    Pr = cols[rng.choice(S, K, replace=False)].copy()
    for _ in range(30):
        best = [
            max((np.roll(p, s) @ c, k, s) for k, p in enumerate(Pr) for s in range(P))[1:]
            for c in cols
        ]
        NP = np.zeros_like(Pr)
        n = np.zeros(K)
        for c, (k, s) in zip(cols, best):
            NP[k] += np.roll(c, -s)
            n[k] += 1
        Pr = np.where(n[:, None] > 0, NP / np.maximum(n, 1)[:, None], Pr)
    r_x = np.array([b[0] for b in best])
    s_x = np.array([(-b[1]) % P for b in best])
    # Start labels: dither each profile along its pattern with the arcade colour mix.
    lab = []
    for p in Pr:
        q = np.argsort(np.argsort(-(p + rng.normal(0, p.std() * 0.8, P))))
        nl = int(round(mix[2] * P))
        nd = int(round(mix[0] * P))
        lbl = np.ones(P, int)
        lbl[q < nl] = 2
        lbl[q >= P - nd] = 0
        lab.append(lbl)
    R = np.concatenate(lab)

    def build(R, r_x, s_x):
        return np.stack([R[r_x[x] * P + (np.arange(S) + s_x[x]) % P] for x in range(S)], 1)

    def loss(R, r_x, s_x):
        G = build(R, r_x, s_x)
        wave = ((blur(LUM[G]) - V) ** 2).mean() / var
        st = (((cooc(G) - TA) ** 2) / EXP).sum()
        nx = np.roll(np.arange(S), -1)
        lag = np.abs((s_x[nx] - s_x + P // 2) % P - P // 2)
        copies = ((r_x == r_x[nx]) & (lag <= 6)).sum()
        return wave + WST * st + CP * copies, wave, st

    cur, cw, cs = loss(R, r_x, s_x)
    best = (cur, R.copy(), r_x.copy(), s_x.copy())
    T0 = 0.01
    for it in range(ITERS):
        temp = T0 * (1 - it / ITERS) + 1e-9
        R2, r2, s2 = R, r_x, s_x
        m = rng.random()
        if m < 0.8:
            k = rng.integers(K)
            i, j = k * P + rng.integers(P, size=2)
            if R[i] == R[j]:
                continue
            R2 = R.copy()
            R2[i], R2[j] = R[j], R[i]
        else:
            x = rng.integers(S)
            r2 = r_x.copy()
            s2 = s_x.copy()
            if m < 0.9:
                s2[x] = (s_x[x] + rng.choice([-2, -1, 1, 2])) % P
            else:
                r2[x] = rng.integers(K)
                s2[x] = rng.integers(P)
        new, nw, ns = loss(R2, r2, s2)
        if new < cur or rng.random() < np.exp((cur - new) / temp):
            R, r_x, s_x, cur, cw, cs = R2, r2, s2, new, nw, ns
            if cur < best[0]:
                best = (cur, R.copy(), r_x.copy(), s_x.copy())
        if it % 50000 == 0:
            print(f"step {it}: wave picture missed {cw * 100:.1f}%", flush=True)
    _, R, r_x, s_x = best
    return R.reshape(K, P), r_x, s_x


def main():
    a = Arcade()
    F = arcade_water(a)
    assert sorted(np.unique(F).tolist()) == [2, 26, 39]
    patterns, columns, offsets = fit(F)
    out = dict(
        orientation="Screen orientation as the player sees it: row 0 = top of the screen, columns left to right. On screen the water moves DOWN 1 line per shown picture.",
        arcade_colour_index=[2, 26, 39],
        labels="0 = dark, 1 = mid, 2 = light (arcade_colour_index order)",
        patterns=patterns.tolist(),
        pattern_length=P,
        column_repeat=S,
        column_pattern=[int(v) for v in columns],
        column_offset=[int(v) for v in offsets],
        static_picture="pixel(sea line y, screen column x) = patterns[column_pattern[x%60]][(y + column_offset[x%60]) % 30]",
        palette_rule="120 entries = 4 patterns x 30. Entry k*30+j is phase j of pattern k; the palette rotates each pattern one phase per shown picture.",
        made_by=f"assets/water/make_water.py (K={K}, P={P}, seed={SEED}, steps={ITERS}, S={S}, dot weight={WST}, copy penalty={CP})",
    )
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "stage-water-4x30.json"
    path.write_text(json.dumps(out, indent=1) + "\n")
    print("wrote", path)


if __name__ == "__main__":
    main()
