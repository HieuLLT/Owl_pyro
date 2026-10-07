#!/usr/bin/env python3
"""
gen_fp_textures.py — procedural seamless brutalist textures (no API, no external art).

    python3 tools/gen_fp_textures.py

Writes 512x512 tileable PNGs to assets/textures/fp/:
    concrete.png   cold, cracked, pitted concrete slab
    rust.png       brushed dark steel plates with rust blooms and rivets
    mesh.png       rusted wire mesh over darkness

Every field is built from periodic noise (FFT-filtered white noise) and wrap-around
Voronoi cells, so edges tile with no seam. Colour stays dark and cold on purpose:
the red neon + shader noise do the rest in-engine.
"""
import os

import numpy as np
from PIL import Image

N = 512
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "textures", "fp")


def fbm(seed, beta=2.0, aniso=(1.0, 1.0)):
    """Periodic 1/f^beta noise in 0..1. aniso scales frequency per axis (streaks)."""
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((N, N))
    f = np.fft.fft2(white)
    fy = np.fft.fftfreq(N)[:, None] * aniso[1]
    fx = np.fft.fftfreq(N)[None, :] * aniso[0]
    r = np.sqrt(fx * fx + fy * fy)
    r[0, 0] = 1.0
    f = f / (r ** (beta / 2.0))
    f[0, 0] = 0
    out = np.real(np.fft.ifft2(f))
    out -= out.min()
    out /= out.max() + 1e-9
    return out


def voronoi_edges(seed, cells=9):
    """Wrap-around Voronoi: returns (F2 - F1) distance map, ~0 along cell borders."""
    rng = np.random.default_rng(seed)
    pts = rng.random((cells * cells, 2)) * N
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float32)
    d1 = np.full((N, N), 1e9, np.float32)
    d2 = np.full((N, N), 1e9, np.float32)
    for px, py in pts:
        dx = np.abs(xs - px)
        dy = np.abs(ys - py)
        dx = np.minimum(dx, N - dx)
        dy = np.minimum(dy, N - dy)
        d = np.sqrt(dx * dx + dy * dy)
        d2 = np.where(d < d1, d1, np.minimum(d2, d))
        d1 = np.minimum(d1, d)
    return d2 - d1


def save(name, arr):
    arr = np.clip(arr, 0, 1)
    Image.fromarray((arr * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name))


def concrete():
    base = 0.20 + 0.22 * fbm(1, 2.4) + 0.08 * fbm(2, 1.2)
    edges = voronoi_edges(3, 7)
    cracks = np.clip(1.0 - edges / 3.0, 0, 1) ** 1.5          # thin dark seams
    cracks *= np.clip(fbm(4, 2.0) * 1.8 - 0.35, 0, 1)         # only some borders crack
    pits = (fbm(5, 0.4) > 0.93).astype(np.float32)
    stain = np.clip(fbm(6, 2.8) - 0.55, 0, 1) * 0.5
    lum = base - cracks * 0.28 - pits * 0.12 - stain * 0.2
    rgb = np.stack([lum * 0.92, lum * 0.97, lum * 1.08], -1)  # cold tint
    save("concrete.png", rgb)


def rust():
    streak = fbm(7, 1.6, aniso=(0.04, 1.0))                   # brushed along x
    steel = 0.14 + 0.16 * streak + 0.05 * fbm(8, 1.0)
    bloom = np.clip(fbm(9, 2.6) * 1.7 - 0.7, 0, 1)
    bloom *= 0.6 + 0.4 * fbm(10, 1.0)
    rgb = np.stack([steel * 0.9, steel * 0.95, steel * 1.05], -1)
    rust_col = np.array([0.46, 0.21, 0.09])
    rgb = rgb * (1 - bloom[..., None]) + (rust_col * (0.5 + 0.7 * fbm(11, 0.8)[..., None])) * bloom[..., None]
    # plate seams every 256px (periodic) and rivet rows
    ys, xs = np.mgrid[0:N, 0:N]
    seam = ((xs % 256) < 2) | ((ys % 256) < 2)
    rgb[seam] *= 0.35
    for cy in (24, 232, 280, 488):
        for cx in range(16, N, 48):
            r2 = (xs - cx) ** 2 + (ys - cy) ** 2
            rgb[r2 < 9] = rgb[r2 < 9] * 0.5 + 0.22
            rgb[(r2 >= 9) & (r2 < 16)] *= 0.45
    save("rust.png", rgb)


def mesh():
    ys, xs = np.mgrid[0:N, 0:N]
    step, w = 32, 3
    wire = (((xs + 8) % step) < w) | (((ys + 8) % step) < w)
    diag = (((xs + ys) % 64) < 2) & False  # plain grid; kept simple
    lum = 0.04 + 0.04 * fbm(12, 1.0)
    metal = 0.20 + 0.18 * fbm(13, 1.4)
    rgb = np.stack([np.full((N, N), lum)] * 3, -1)
    mask = (wire | diag)
    rustiness = np.clip(fbm(14, 2.2) * 1.6 - 0.45, 0, 1)
    wire_rgb = np.stack([metal * (0.9 + 0.7 * rustiness), metal * (0.9 + 0.1 * rustiness), metal * (1.0 - 0.3 * rustiness)], -1)
    rgb[mask] = wire_rgb[mask]
    save("mesh.png", rgb)


def main():
    os.makedirs(OUT, exist_ok=True)
    concrete()
    rust()
    mesh()
    print("OK textures ->", OUT)


if __name__ == "__main__":
    main()
