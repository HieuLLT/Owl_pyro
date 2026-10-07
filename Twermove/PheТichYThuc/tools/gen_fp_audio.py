#!/usr/bin/env python3
"""
gen_fp_audio.py — procedural soundscape for the first-person build (numpy + wave only).

    python3 tools/gen_fp_audio.py

Writes 22.05 kHz mono 16-bit WAVs to assets/audio/fp/:
    fan_hum.wav          4 s  seamless loop: cooling-fan drone + blade-pass flutter
    metal_thud.wav       0.9 s one-shot: dull metallic pounding
    erasure_crackle.wav  3 s  loop: jarring digital crackle of The Erasure
    heartbeat.wav        1 s  loop (60 BPM): mechanical lub-dub with a relay tick
    drag.wav             1.1 s one-shot: heavy body being dragged over concrete

Loop files are made seamless by using whole-cycle frequencies and/or an end cross-fade.
"""
import os
import wave

import numpy as np

SR = 22050
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "audio", "fp")
RNG = np.random.default_rng(66)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def bandpass(x, lo, hi):
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    f[(fr < lo) | (fr > hi)] = 0
    return np.fft.irfft(f, len(x))


def noise(sec):
    return RNG.standard_normal(int(SR * sec))


def crossfade_loop(x, fade_sec=0.25):
    """Make x loop seamlessly by blending its tail into its head."""
    n = int(SR * fade_sec)
    w = np.linspace(0, 1, n)
    y = x[:-n].copy()
    y[:n] = y[:n] * w + x[-n:] * (1 - w)
    return y


def normalize(x, peak=0.8):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def save(name, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def fan_hum():
    sec = 4.0
    t = t_axis(sec)
    x = 0.0
    for k, a in ((1, 1.0), (2, 0.55), (3, 0.3), (5, 0.12)):  # 50 Hz mains-like drone
        x = x + a * np.sin(2 * np.pi * 50 * k * t + k)
    blade = 0.5 + 0.5 * np.sin(2 * np.pi * 7 * t)              # 7 Hz blade pass (28 whole cycles)
    air = bandpass(noise(sec), 300, 2500)
    air_loop = crossfade_loop(np.concatenate([air, air[: int(SR * 0.25)]]), 0.25)[: len(t)]
    x = x * (0.7 + 0.3 * blade) + 0.35 * air_loop * (0.5 + 0.5 * blade)
    save("fan_hum.wav", normalize(x, 0.55))


def metal_thud():
    t = t_axis(0.9)
    body = np.sin(2 * np.pi * (46 + 40 * np.exp(-t * 18)) * t) * np.exp(-t * 7)
    ring = 0
    for f, a, d in ((181, 0.5, 5), (297, 0.4, 7), (463, 0.3, 9), (712, 0.2, 12), (1180, 0.12, 16)):
        ring = ring + a * np.sin(2 * np.pi * f * t) * np.exp(-t * d)
    hit = bandpass(noise(0.9), 200, 4000) * np.exp(-t * 60) * 0.8
    save("metal_thud.wav", normalize(body * 1.2 + ring * 0.6 + hit, 0.85))


def erasure_crackle():
    sec = 3.0
    n = int(SR * sec)
    x = np.zeros(n)
    for _ in range(140):                                       # sparse digital clicks
        i = RNG.integers(0, n - 400)
        L = RNG.integers(6, 300)
        amp = RNG.uniform(0.2, 1.0)
        x[i:i + L] += amp * RNG.choice([-1, 1], L) * np.exp(-np.arange(L) / (L / 3))
    for _ in range(9):                                         # harsh static bursts
        i = RNG.integers(0, n - 4000)
        L = RNG.integers(1200, 4000)
        env = np.hanning(L)
        x[i:i + L] += bandpass(RNG.standard_normal(L), 1500, 9000) * env * RNG.uniform(0.25, 0.7)
    x += 0.04 * bandpass(noise(sec), 2000, 8000)
    x = crossfade_loop(np.concatenate([x, x[: int(SR * 0.2)]]), 0.2)
    save("erasure_crackle.wav", normalize(x, 0.7))


def heartbeat():
    sec = 1.0
    t = t_axis(sec)

    def thump(t0, f, amp):
        tt = np.clip(t - t0, 0, None)
        env = (t >= t0) * np.exp(-tt * 28)
        return amp * np.sin(2 * np.pi * f * tt) * env

    x = thump(0.00, 52, 1.0) + thump(0.22, 44, 0.75)
    for t0 in (0.0, 0.22):                                     # mechanical relay tick
        tt = np.clip(t - t0, 0, None)
        x = x + 0.25 * bandpass(noise(sec), 1800, 5000) * (t >= t0) * np.exp(-tt * 220)
    save("heartbeat.wav", normalize(x, 0.8))


def drag():
    sec = 1.1
    t = t_axis(sec)
    scrape = bandpass(noise(sec), 120, 1800)
    grit = bandpass(noise(sec), 2500, 6000) * 0.35
    env = np.sin(np.pi * np.clip(t / sec, 0, 1)) ** 1.5
    wobble = 0.65 + 0.35 * np.sin(2 * np.pi * 9 * t)
    low = np.sin(2 * np.pi * 38 * t) * 0.4 * env
    save("drag.wav", normalize((scrape * wobble + grit) * env + low, 0.7))


def main():
    os.makedirs(OUT, exist_ok=True)
    fan_hum()
    metal_thud()
    erasure_crackle()
    heartbeat()
    drag()
    print("OK audio ->", OUT)


if __name__ == "__main__":
    main()
