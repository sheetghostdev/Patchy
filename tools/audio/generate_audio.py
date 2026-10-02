#!/usr/bin/env python3
"""
PATCHY - procedural audio generator
===================================

Synthesizes every sound effect and music cue used by the PATCHY platformer
from scratch: oscillators, filtered noise, FM, modal (struck-object)
synthesis, Karplus-Strong plucks and a synthetic reverb.  No samples, no
borrowed melodies.

The script is deterministic: every sound gets a fixed seed derived from its
name (``seed_for``), so re-running it reproduces identical WAV files and
musically identical OGG files.  It is idempotent and overwrites its outputs.

Usage (from the project root)::

    python3 tools/audio/generate_audio.py              # everything
    python3 tools/audio/generate_audio.py --no-music   # SFX only
    python3 tools/audio/generate_audio.py --only coin  # names containing "coin"

Outputs::

    audio/sfx/*.wav            mono, 44.1 kHz, 16-bit PCM
    audio/music/*.ogg          stereo, 44.1 kHz, Ogg Vorbis (quality 0.5)
    audio/audio_manifest.json  metadata (durations, loops, buses, groups ...)

Requires: numpy, scipy, soundfile  (pip install numpy scipy soundfile)

Layout of this file
-------------------
 1. Config / seeds
 2. DSP helpers (envelopes, oscillators, noise, filters, modal, FM, KS, reverb,
    loop tools)
 3. Shared instrument voices (used by both SFX and music)
 4. Sound effects: registry + finalisation (trim, fades, DC, level), then one
    small function per sound, registered with @sfx / @sfx_family
 5. Music (tiny sequencer + mixer, compositions)
 6. Writing, manifest, verification and summary table
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import numpy as np
from scipy import ndimage
from scipy import signal as sps

try:
    import soundfile as sf
except ImportError:  # pragma: no cover - dependency hint
    sys.exit("This script needs 'soundfile':  pip install numpy scipy soundfile")

# =============================================================================
# 1. Config
# =============================================================================
SR = 44100
ROOT = Path(__file__).resolve().parents[2]          # .../Patchy
AUDIO_DIR = ROOT / "audio"
SFX_DIR = AUDIO_DIR / "sfx"
MUSIC_DIR = AUDIO_DIR / "music"
MANIFEST_PATH = AUDIO_DIR / "audio_manifest.json"
MASTER_SEED = 0x5EA5                                # change to re-roll all details
OGG_QUALITY = 0.5                                   # Vorbis VBR quality (0..1)
SFX_PEAK_DB = -1.0                                  # default SFX peak level


def seed_for(name: str) -> int:
    """Stable per-name seed (Python's hash() is salted per process)."""
    return (zlib.crc32(name.encode("utf-8")) ^ MASTER_SEED) & 0xFFFFFFFF


def rng_for(name: str) -> np.random.Generator:
    return np.random.default_rng(seed_for(name))


# =============================================================================
# 2. DSP helpers
# =============================================================================
# ---- time / envelopes -------------------------------------------------------
def ns(sec: float) -> int:
    """Seconds -> sample count (at least 1)."""
    return max(1, int(round(sec * SR)))


def tn(n: int) -> np.ndarray:
    """Time axis (seconds) for n samples."""
    return np.arange(n) / SR


def db2a(db: float) -> float:
    return 10.0 ** (db / 20.0)


def a2db(a: float) -> float:
    return 20.0 * np.log10(max(float(a), 1e-12))


def mtof(m: float) -> float:
    """MIDI note number -> frequency in Hz."""
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


NOTE_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note(name: str) -> int:
    """'F#5' -> 78, 'Bb3' -> 58."""
    pc = NOTE_PC[name[0]]
    rest = name[1:]
    while rest and rest[0] in "#b":
        pc += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + pc


def curve(t, points, kind: str = "lin"):
    """Piece-wise curve through (time, value) points evaluated at t.
    kind: 'lin' linear, 'exp' log-linear (for frequencies), 'cos' eased."""
    pt = np.array([p[0] for p in points], float)
    pv = np.array([p[1] for p in points], float)
    t = np.asarray(t, float)
    if kind == "exp":
        return np.exp(np.interp(t, pt, np.log(np.maximum(pv, 1e-9))))
    if kind == "cos":
        idx = np.clip(np.searchsorted(pt, t, side="right") - 1, 0, len(pt) - 2)
        t0, t1 = pt[idx], pt[idx + 1]
        u = np.clip((t - t0) / np.maximum(t1 - t0, 1e-12), 0.0, 1.0)
        u = 0.5 - 0.5 * np.cos(np.pi * u)
        return pv[idx] + (pv[idx + 1] - pv[idx]) * u
    return np.interp(t, pt, pv)


def env_perc(n: int, attack: float = 0.002, decay: float = 0.2) -> np.ndarray:
    """Linear attack then exponential decay (time constant `decay`)."""
    t = tn(n)
    a = np.clip(t / max(attack, 1e-6), 0.0, 1.0)
    e = a * np.exp(-np.maximum(t - attack, 0.0) / decay)
    return e * fade_tail(n, min(0.01, 0.2 * n / SR))       # always ends at 0


def env_ar(n: int, attack: float, release: float, hold: float | None = None) -> np.ndarray:
    """Raised-cosine attack, sustain, raised-cosine release (ends at n)."""
    t = tn(n)
    total = n / SR
    hold = total - release if hold is None else hold
    a = 0.5 - 0.5 * np.cos(np.pi * np.clip(t / max(attack, 1e-6), 0, 1))
    r = 0.5 + 0.5 * np.cos(np.pi * np.clip((t - hold) / max(release, 1e-6), 0, 1))
    return a * r


def fade(x: np.ndarray, fin: float = 0.002, fout: float = 0.005) -> np.ndarray:
    """Half-cosine fade in/out (seconds) to kill clicks at the edges."""
    x = x.copy()
    a, b = min(ns(fin), len(x)), min(ns(fout), len(x))
    if fin > 0:
        x[:a] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(a) / a)
    if fout > 0:
        x[len(x) - b:] *= 0.5 + 0.5 * np.cos(np.pi * (np.arange(b) + 1) / b)
    return x


def fit(x: np.ndarray, dur: float, fade_s: float = 0.2) -> np.ndarray:
    """Cap a sound at `dur` seconds with a smooth fade over the last fade_s."""
    x = np.asarray(x, float)[:ns(dur)].copy()
    k = min(ns(fade_s), len(x))
    x[len(x) - k:] *= 0.5 + 0.5 * np.cos(np.pi * (np.arange(k) + 1) / k)
    return x


# ---- mixing utilities -------------------------------------------------------
def nz(x: np.ndarray, peak: float = 1.0) -> np.ndarray:
    """Peak-normalise (safe for silence)."""
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    return x * (peak / m) if m > 1e-12 else x


def place(buf: np.ndarray, start: int, sig: np.ndarray, gain: float = 1.0) -> None:
    """Add sig into buf at sample offset start (cropped to buf)."""
    if start >= len(buf) or start + len(sig) <= 0:
        return
    s0 = max(0, -start)
    s1 = min(len(sig), len(buf) - start)
    buf[start + s0:start + s1] += gain * sig[s0:s1]


def mix(*items) -> np.ndarray:
    """mix((sig, gain, offset_sec), ...) -> summed mono signal.
    gain and offset are optional; peaks are NOT normalised."""
    parts = []
    for it in items:
        if isinstance(it, np.ndarray):
            it = (it,)
        sig = np.asarray(it[0], float)
        gain = it[1] if len(it) > 1 else 1.0
        off = ns(it[2]) if len(it) > 2 and it[2] > 0 else 0
        parts.append((sig, gain, off))
    n = max(off + len(sig) for sig, _, off in parts)
    out = np.zeros(n)
    for sig, gain, off in parts:
        out[off:off + len(sig)] += gain * sig
    return out


def softclip(x: np.ndarray, drive: float = 1.5) -> np.ndarray:
    """tanh saturation for peak-normalised material (output peak <= 1)."""
    return np.tanh(drive * x) / np.tanh(drive)


def soft_limit(x: np.ndarray, ceiling: float = db2a(-1.0), knee: float = 0.75) -> np.ndarray:
    """Transparent below knee*ceiling, smooth tanh knee above; |y| < ceiling."""
    k = knee * ceiling
    ax = np.abs(x)
    over = ax > k
    y = x.copy()
    y[over] = np.sign(x[over]) * (k + (ceiling - k) * np.tanh((ax[over] - k) / (ceiling - k)))
    return y


def rms(x: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(x)))) if len(x) else 0.0


# ---- oscillators ------------------------------------------------------------
def _as_curve(freq, n: int) -> np.ndarray:
    if np.isscalar(freq):
        return np.full(n, float(freq))
    f = np.asarray(freq, float)
    return f[:n] if len(f) >= n else np.pad(f, (0, n - len(f)), mode="edge")


def phase_of(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    """Instantaneous phase (radians) for a constant or per-sample frequency."""
    f = _as_curve(freq, n)
    return phase0 + 2.0 * np.pi * np.concatenate(([0.0], np.cumsum(f[:-1]))) / SR


def sine(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    return np.sin(phase_of(freq, n, phase0))


def _polyblep(ph: np.ndarray, dt: np.ndarray) -> np.ndarray:
    out = np.zeros_like(ph)
    m = ph < dt
    x = ph[m] / dt[m]
    out[m] = x + x - x * x - 1.0
    m = ph > 1.0 - dt
    x = (ph[m] - 1.0) / dt[m]
    out[m] = x * x + x + x + 1.0
    return out


def saw(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    """Band-limited (PolyBLEP) sawtooth, frequency may vary per sample."""
    f = _as_curve(freq, n)
    dt = f / SR
    ph = (phase0 + np.concatenate(([0.0], np.cumsum(dt[:-1])))) % 1.0
    return 2.0 * ph - 1.0 - _polyblep(ph, dt)


def pulse(freq, n: int, width: float = 0.5, phase0: float = 0.0) -> np.ndarray:
    """Band-limited (PolyBLEP) pulse wave with DC removed."""
    f = _as_curve(freq, n)
    dt = f / SR
    ph = (phase0 + np.concatenate(([0.0], np.cumsum(dt[:-1])))) % 1.0
    y = np.where(ph < width, 1.0, -1.0)
    y += _polyblep(ph, dt) - _polyblep((ph - width) % 1.0, dt)
    return y - (2.0 * width - 1.0)


def harmonic_tone(freq, n: int, amps, phase0: float = 0.0) -> np.ndarray:
    """Additive tone: amps[k] for harmonic k+1 (skips partials above 18 kHz)."""
    ph = phase_of(freq, n, phase0)
    fmax = float(np.max(_as_curve(freq, n)))
    y = np.zeros(n)
    for k, a in enumerate(amps, start=1):
        if a and k * fmax < 18000:
            y += a * np.sin(k * ph)
    return y


def fm(carrier, n: int, ratio: float = 1.0, index=1.0, mod_phase: float = 0.0) -> np.ndarray:
    """Two-operator FM: sin(phi_c + I(t) * sin(ratio * phi_c + mod_phase))."""
    ph = phase_of(carrier, n)
    idx = _as_curve(index, n) if not np.isscalar(index) else index
    return np.sin(ph + idx * np.sin(ratio * ph + mod_phase))


# ---- noise -------------------------------------------------------------------
def white(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n)


def colored(n: int, rng: np.random.Generator, slope: float = 1.0) -> np.ndarray:
    """1/f^slope noise (slope 1 = pink, 2 = brown), unit std, circular."""
    X = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = f[1] if n > 2 else 1.0
    y = np.fft.irfft(X / f ** (slope / 2.0), n)
    return y / (np.std(y) + 1e-12)


# ---- filters -----------------------------------------------------------------
def _fc(f: float) -> float:
    return float(min(max(f, 5.0), SR * 0.49))


def lp(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    return sps.sosfilt(sps.butter(order, _fc(fc), "lowpass", fs=SR, output="sos"), x)


def hp(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    return sps.sosfilt(sps.butter(order, _fc(fc), "highpass", fs=SR, output="sos"), x)


def bp(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    lo, hi = _fc(lo), _fc(hi)
    if hi <= lo * 1.05:
        hi = min(lo * 1.05, SR * 0.49)
    return sps.sosfilt(sps.butter(order, [lo, hi], "bandpass", fs=SR, output="sos"), x)


def reson(x: np.ndarray, f0: float, q: float) -> np.ndarray:
    """Constant-peak-gain resonator (2nd-order peaking band-pass)."""
    b, a = sps.iirpeak(_fc(f0), q, fs=SR)
    return sps.lfilter(b, a, x)


def gauss_band(f, fc, width_oct):
    """Gaussian band in log-frequency (width = std dev in octaves)."""
    return np.exp(-0.5 * (np.log2(np.maximum(f, 1.0) / fc) / width_oct) ** 2)


def lp_gain(f, fc, order: float = 2.0):
    return 1.0 / np.sqrt(1.0 + (np.maximum(f, 0.0) / fc) ** (2 * order))


def hp_gain(f, fc, order: float = 2.0):
    return 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * order))


def shaped_noise(n: int, rng: np.random.Generator, gain_fn, nfft: int = 1024, hop: int = 256) -> np.ndarray:
    """White noise sculpted by a time-varying spectral gain via STFT.
    gain_fn(f[:,None], t[None,:]) -> gain matrix (t = frame centre in s)."""
    x = rng.standard_normal(n)
    f, tt, Z = sps.stft(x, fs=SR, nperseg=nfft, noverlap=nfft - hop)
    G = np.broadcast_to(gain_fn(f[:, None], tt[None, :]), Z.shape)
    _, y = sps.istft(Z * G, fs=SR, nperseg=nfft, noverlap=nfft - hop)
    y = y[:n]
    return np.pad(y, (0, n - len(y))) if len(y) < n else y


def whoosh(dur: float, rng, fc_pts, width: float = 0.8, amp_pts=None,
           tonal: float = 0.0, tonal_width: float = 0.1) -> np.ndarray:
    """Band-pass noise whose centre follows fc_pts [(t, Hz)...]."""
    n = ns(dur)

    def g(f, tt):
        fc = curve(tt, fc_pts, "exp")
        G = gauss_band(f, fc, width)
        if tonal:
            G = G + tonal * gauss_band(f, fc, tonal_width)
        return G

    y = nz(shaped_noise(n, rng, g))
    if amp_pts:
        y = y * curve(tn(n), amp_pts, "cos")
    return y


# ---- circular (loop-safe) generators ----------------------------------------
def circ_noise(L: int, rng, mag_fn=None) -> np.ndarray:
    """Exactly periodic noise of length L, optionally coloured by mag_fn(f)."""
    X = np.fft.rfft(rng.standard_normal(L))
    if mag_fn is not None:
        X = X * mag_fn(np.fft.rfftfreq(L, 1.0 / SR))
    y = np.fft.irfft(X, L)
    return y / (np.std(y) + 1e-12)


def circ_filter(x: np.ndarray, mag_fn) -> np.ndarray:
    """Zero-phase circular filtering (keeps a loop seamless)."""
    X = np.fft.rfft(x)
    return np.fft.irfft(X * mag_fn(np.fft.rfftfreq(len(x), 1.0 / SR)), len(x))


def periodic_lfo(L: int, rng, harmonics: int = 3, depth: float = 0.3, tilt: float = 1.0) -> np.ndarray:
    """1 + depth * smooth random wave that repeats exactly every L samples."""
    u = np.arange(L) / L
    s = np.zeros(L)
    for k in range(1, harmonics + 1):
        s += rng.uniform(0.4, 1.0) / k ** tilt * np.sin(2 * np.pi * k * u + rng.uniform(0, 2 * np.pi))
    return 1.0 + depth * s / (np.max(np.abs(s)) + 1e-12)


def loop_freq(f: float, L: int) -> float:
    """Nearest frequency with a whole number of cycles in L samples."""
    return max(1, round(f * L / SR)) * SR / L


def fold_tail(x: np.ndarray, L: int) -> np.ndarray:
    """'Tail wrap': add everything past L back onto the start (circularly).
    For linear processing this equals rendering an infinitely repeating loop."""
    out = np.zeros((L,) + x.shape[1:])
    for s in range(0, len(x), L):
        seg = x[s:s + L]
        out[:len(seg)] += seg
    return out


def loop_crossfade(x: np.ndarray, L: int, xf: int) -> np.ndarray:
    """Equal-power crossfade of the overhang x[L:L+xf] into the head.
    General tool for looping non-periodic material (e.g. a recorded-style
    render); the shipped loops don't need it because they are built to be
    exactly periodic (circular noise, whole-cycle tones, fold_tail)."""
    out = x[:L].copy()
    u = np.arange(xf) / xf
    out[:xf] = x[:xf] * np.sin(0.5 * np.pi * u) + x[L:L + xf] * np.cos(0.5 * np.pi * u)
    return out


def periodic_events(t: np.ndarray, period: float, centers, shape) -> np.ndarray:
    """Sum of shape(t - c) over event centres, made periodic via images."""
    out = np.zeros_like(t)
    for c in centers:
        for k in (-2, -1, 0, 1, 2):
            out += shape(t - c + k * period)
    return out


def seam_ratio(x: np.ndarray) -> float:
    """Wrap-around jump |x[0]-x[-1]| relative to the 99.9th percentile of
    ordinary sample steps.  <= ~1 means the seam is as smooth as the body."""
    x = x if x.ndim == 1 else x.mean(axis=1)
    steps = np.abs(np.diff(x))
    ref = float(np.percentile(steps, 99.9)) + 1e-9
    return float(abs(x[0] - x[-1]) / ref)


# ---- physical-ish building blocks ------------------------------------------
def modes(n: int, freqs, amps, taus, attack: float = 0.0004) -> np.ndarray:
    """Modal synthesis: sum of exponentially decaying sinusoids."""
    t = tn(n)
    y = np.zeros(n)
    for f, a, tau in zip(freqs, amps, taus):
        if f < SR * 0.45:
            y += a * np.exp(-t / tau) * np.sin(2 * np.pi * f * t)
    if attack > 0:
        y *= np.clip(t / attack, 0.0, 1.0)
    return y * fade_tail(n, min(0.015, 0.2 * n / SR))      # no truncation click


def thump(dur: float, f0: float, f1: float, tau_f: float = 0.03, tau_a: float = 0.08,
          attack: float = 0.0008) -> np.ndarray:
    """Sine with exponential pitch drop f0 -> f1: kicks, thuds, booms."""
    n = ns(dur)
    t = tn(n)
    f = f1 + (f0 - f1) * np.exp(-t / tau_f)
    y = np.sin(phase_of(f, n)) * np.exp(-t / tau_a) * np.clip(t / attack, 0, 1)
    return y * fade_tail(n, 0.01)


def fade_tail(n: int, sec: float) -> np.ndarray:
    """Envelope that is 1 except for a half-cosine fade over the last `sec`."""
    e = np.ones(n)
    k = min(ns(sec), n)
    e[n - k:] = 0.5 + 0.5 * np.cos(np.pi * (np.arange(k) + 1) / k)
    return e


def click(rng, dur: float = 0.004, lo: float = 2000.0, hi: float = 12000.0) -> np.ndarray:
    """Very short band-limited noise tick (transient layer), peak 1."""
    n = ns(dur)
    return nz(bp(white(n, rng), lo, hi) * env_perc(n, 0.0001, dur / 5))


def bubble(f0: float, dur: float = 0.06, rise: float = 1.2, tau: float | None = None) -> np.ndarray:
    """Liquid 'plip': sine whose pitch rises while it decays (Minnaert-ish)."""
    n = ns(dur)
    t = tn(n)
    f = f0 * (1.0 + rise * t / dur)
    tau = tau or dur / 4.0
    return np.sin(phase_of(f, n)) * np.exp(-t / tau) * np.clip(t / 0.0008, 0, 1) * fade_tail(n, 0.004)


def grains(n: int, rng, rate, amp_env=None, grain_ms=(0.4, 2.5), lo: float | None = None,
           hi: float | None = None, kernels: int = 4) -> np.ndarray:
    """Sparse random micro-clicks (crunch, grit, crackle).
    rate: grains/second (scalar or per-sample array)."""
    rate = _as_curve(rate, n)
    hits = rng.random(n) < rate / SR
    amps = rng.exponential(1.0, n) * hits
    # grains fade with their density unless an explicit envelope is given
    amps = amps * (amp_env if amp_env is not None else np.sqrt(rate / (rate.max() + 1e-12)))
    which = rng.integers(0, kernels, n)
    out = np.zeros(n)
    for k in range(kernels):
        L = max(4, ns(rng.uniform(*grain_ms) / 1000.0))
        ker = rng.standard_normal(L) * np.exp(-np.arange(L) / (L / 4.0))
        a = np.where(which == k, amps, 0.0)
        if a.any():
            out += sps.fftconvolve(a, ker)[:n]
    if lo and hi:
        out = bp(out, lo, hi)
    elif hi:
        out = lp(out, hi)
    elif lo:
        out = hp(out, lo)
    return out * fade_tail(n, min(0.005, 0.2 * n / SR))


def circ_grains(L: int, rng, rate: float, grain_ms=(0.4, 2.5), mag_fn=None, amp_pow: float = 1.0) -> np.ndarray:
    """Periodic version of grains() (circular convolution)."""
    hits = rng.random(L) < rate / SR
    amps = rng.exponential(1.0, L) ** amp_pow * hits
    out = np.zeros(L)
    which = rng.integers(0, 4, L)
    for k in range(4):
        K = max(4, ns(rng.uniform(*grain_ms) / 1000.0))
        ker = np.zeros(L)
        ker[:K] = rng.standard_normal(K) * np.exp(-np.arange(K) / (K / 4.0))
        a = np.where(which == k, amps, 0.0)
        out += np.fft.irfft(np.fft.rfft(a) * np.fft.rfft(ker), L)
    return circ_filter(out, mag_fn) if mag_fn is not None else out


def cloth_flap(dur: float, rng, rate: float = 30.0, lo: float = 250.0, hi: float = 1800.0,
               depth: float = 0.85) -> np.ndarray:
    """Fluttering fabric: band noise with fast amplitude flutter."""
    n = ns(dur)
    t = tn(n)
    am = 1.0 - depth * (0.5 + 0.5 * np.cos(2 * np.pi * rate * t + rng.uniform(0, 6.28)))
    return bp(white(n, rng), lo, hi) * am * env_perc(n, 0.004, dur / 3.0)


def creak(dur: float, rng, rate_pts, res, amp_pts, jitter: float = 0.12) -> np.ndarray:
    """Stick-slip friction: a jittery pulse train exciting resonances.
    res = [(freq, Q, gain), ...]; rate_pts = [(t, pulses/s), ...]."""
    n = ns(dur)
    imp = np.zeros(n)
    rt = np.array([p[0] for p in rate_pts])
    rv = np.array([p[1] for p in rate_pts])
    t = 0.0
    while True:
        r = float(np.interp(t, rt, rv))
        t += (1.0 / r) * max(0.3, 1.0 + jitter * rng.standard_normal())
        if t >= dur:
            break
        imp[int(t * SR)] += rng.uniform(0.55, 1.0)
    exc = imp + 0.02 * white(n, rng)
    out = sum(g * reson(exc, f, q) for f, q, g in res)
    return out * curve(tn(n), amp_pts, "cos")


def ks_pluck(freq: float, dur: float, rng, t60: float = 1.5, bright: float = 0.6,
             pick: float = 0.2) -> np.ndarray:
    """Karplus-Strong plucked string (vectorised one period at a time).
    The loop filter is a 2-point average convolved with a linear-interpolation
    fractional delay, so tuning is exact and damping is consistent."""
    n = ns(dur)
    D = SR / freq
    N = max(3, int(np.floor(D - 0.5)))
    fr = float(np.clip(D - 0.5 - N, 0.0, 1.0))
    g = 10.0 ** (-3.0 / (t60 * freq))               # -60 dB after t60 seconds
    c0, c1, c2 = 0.5 * (1 - fr) * g, 0.5 * g, 0.5 * fr * g
    # excitation: triangular string displacement plucked at `pick` (mellow
    # 1/k^2 spectrum with pick-position notches) + a little filtered noise
    x = np.arange(N) / N
    p = float(np.clip(pick, 0.05, 0.5))
    tri = np.where(x < p, x / p, (1.0 - x) / (1.0 - p))
    a = float(np.clip(1.0 - bright, 0.0, 0.95))       # one-pole LP = softer noise
    noise = sps.lfilter([1.0 - a], [1.0, -a], rng.uniform(-1.0, 1.0, N))
    exc = 2.0 * (tri - tri.mean()) + (0.15 + 0.5 * bright) * noise
    exc -= exc.mean()
    exc *= 0.3 / (np.sqrt(np.mean(exc ** 2)) + 1e-12)   # fixed excitation energy
    total = n + 2
    y = np.zeros(total + N)
    y[2:2 + N] = exc
    pos = 2 + N
    while pos < total:
        end = min(pos + N, total)
        k = end - pos
        y[pos:end] = (c0 * y[pos - N:pos - N + k] + c1 * y[pos - N - 1:pos - N - 1 + k]
                      + c2 * y[pos - N - 2:pos - N - 2 + k])
        pos = end
    return y[2:2 + n]


# ---- space -------------------------------------------------------------------
def make_ir(rng, rt60: float = 1.4, predelay: float = 0.012, hf: float = 0.45,
            stereo: bool = True, er: int = 6) -> np.ndarray:
    """Synthetic reverb impulse response: exponentially decaying noise with
    frequency-dependent decay plus a few early reflections.  Shape (n, ch)."""
    n = ns(rt60 * 1.15)
    t = tn(n)
    chans = []
    for _ in range(2 if stereo else 1):
        w = rng.standard_normal(n)
        lo_b, mid_b, hi_b = lp(w, 400), bp(w, 400, 3500), hp(w, 3500)
        dec = lambda r: np.exp(-6.9078 * t / r)  # noqa: E731
        ir = 0.8 * lo_b * dec(rt60 * 1.1) + mid_b * dec(rt60) + 0.7 * hi_b * dec(rt60 * hf)
        ir *= np.clip(t / 0.01, 0, 1)                 # soften onset
        for _ in range(er):
            place(ir, ns(rng.uniform(0.004, 0.045)), np.array([rng.uniform(-1, 1) * 2.5]))
        ir = np.concatenate((np.zeros(ns(predelay)), ir))
        chans.append(ir / np.sqrt(np.sum(ir ** 2)))
    return np.stack(chans, axis=1)


_IR_CACHE: dict = {}


def room_ir(kind: str = "small") -> np.ndarray:
    """Cached mono IRs for SFX: 'small' (tight room), 'hall' (sparkly), 'outdoor'."""
    if kind not in _IR_CACHE:
        rt, pre, hf = {"small": (0.45, 0.004, 0.5), "hall": (1.3, 0.012, 0.6),
                       "outdoor": (0.8, 0.03, 0.35), "cave": (1.8, 0.02, 0.4)}[kind]
        _IR_CACHE[kind] = make_ir(rng_for("ir_" + kind), rt, pre, hf, stereo=False)[:, 0]
    return _IR_CACHE[kind]


def reverb(x: np.ndarray, kind: str = "small", wet: float = 0.2) -> np.ndarray:
    """Dry + wet mono convolution reverb (output is longer than input)."""
    w = sps.fftconvolve(x, room_ir(kind))
    out = np.zeros(len(w))
    out[:len(x)] += x
    return out + wet * w


def echo(x: np.ndarray, delay: float, fb: float = 0.35, repeats: int = 4, damp: float = 3500.0) -> np.ndarray:
    """Feed-forward multi-tap echo with progressively darker repeats."""
    d = ns(delay)
    out = np.zeros(len(x) + d * repeats)
    out[:len(x)] += x
    rep = x
    for k in range(1, repeats + 1):
        rep = lp(rep, damp)
        out[k * d:k * d + len(x)] += (fb ** k) * rep
    return out


# =============================================================================
# 3. Shared instrument voices  (all return mono float arrays, peak ~<= 1)
# =============================================================================
def accordion(m: float, dur: float, vel: float = 1.0, rng=None, vib: float = 1.0,
              bright: float = 1.0) -> np.ndarray:
    """Musette-style reed voice: two detuned PolyBLEP saws + a narrow pulse
    reed, reed-chamber formant, gentle delayed vibrato and bellows swell."""
    rng = rng or np.random.default_rng(int(m * 101))
    rel = 0.09
    n = ns(dur + rel)
    t = tn(n)
    f0 = mtof(m)
    depth = 0.0034 * vib * np.clip((t - 0.12) / 0.3, 0, 1)            # ~6 cents
    f = f0 * (1.0 + depth * np.sin(2 * np.pi * 5.3 * t + rng.uniform(0, 6.28)))
    x = (0.5 * saw(f, n, rng.random()) + 0.42 * saw(f * 1.0040, n, rng.random())
         + 0.28 * pulse(f * 0.9986, n, 0.3, rng.random()))
    cut = min(3600.0 * bright, f0 * 9.0)
    x = lp(x, cut, 4)
    x = x + 0.45 * reson(x, 1150, 1.4)                                 # reed-chamber formant
    breath = bp(white(n, rng), 1500, 3500) * 0.008
    swell = 0.82 + 0.18 * (1.0 - np.exp(-t / 0.28))
    env = env_ar(n, 0.028, rel, hold=dur) * swell
    return (x + breath) * env * vel * 0.7


def uke(m: float, dur: float, vel: float = 1.0, rng=None) -> np.ndarray:
    """Ukulele/nylon pluck (Karplus-Strong) damped after `dur`."""
    rng = rng or np.random.default_rng(int(m * 7))
    f = mtof(m)
    y = ks_pluck(f, dur + 0.04, rng, t60=1.1 + 0.4 * (60.0 / max(m, 40)), bright=0.3 + 0.22 * vel,
                 pick=0.17)
    return y * fade_tail(len(y), 0.04) * vel


def uke_body(x: np.ndarray) -> np.ndarray:
    """Small-body resonance for a uke track."""
    x = hp(x, 140)
    return 0.8 * x + 0.35 * reson(x, 420, 2.5) + 0.2 * reson(x, 1500, 2.0)


def pizz_bass(m: float, dur: float, vel: float = 1.0, rng=None) -> np.ndarray:
    """Pizzicato upright-ish bass: KS string + sine body + finger thump."""
    rng = rng or np.random.default_rng(int(m * 13))
    f = mtof(m)
    d = dur + 0.06
    n = ns(d)
    t = tn(n)
    s = ks_pluck(f, d, rng, t60=1.2, bright=0.32, pick=0.12)
    body = np.sin(phase_of(f, n)) * np.exp(-t / 0.35) * np.clip(t / 0.004, 0, 1)
    thud = lp(white(n, rng), 300) * env_perc(n, 0.0005, 0.01)
    y = lp(0.75 * nz(s) + 0.55 * body + 0.15 * nz(thud), 1600)
    return y * fade_tail(n, 0.05) * vel


def drive_bass(m: float, dur: float, vel: float = 1.0) -> np.ndarray:
    """Short plucky saw bass with a quick 'filter' decay (combat layer)."""
    f = mtof(m)
    n = ns(dur + 0.02)
    t = tn(n)
    raw = saw(f, n) + 0.6 * np.sin(phase_of(f * 0.5, n))
    dark, bright = lp(raw, 320), lp(raw, 2200)
    y = dark + (bright - dark) * np.exp(-t / 0.045)
    return y * env_ar(n, 0.003, 0.03) * vel * 0.8


def marimba(m: float, dur: float = 1.0, vel: float = 1.0, rng=None) -> np.ndarray:
    """Marimba bar: 1 : 3.93 : 9.2 modes with pitch-dependent decay."""
    f = mtof(m)
    tau = 0.55 * (523.0 / f) ** 0.45
    n = ns(min(max(dur, tau * 4.0), 2.0))
    y = modes(n, [f, f * 3.93, f * 9.2], [1.0, 0.22 * vel, 0.05 * vel],
              [tau, tau * 0.25, tau * 0.08], attack=0.0015)
    if rng is not None:
        y += 0.06 * vel * lp(white(n, rng), 2500) * env_perc(n, 0.0003, 0.002)
    return y * fade_tail(n, 0.02) * vel


def vibes(m: float, dur: float = 2.0, vel: float = 1.0, trem: float = 4.6) -> np.ndarray:
    """Soft vibraphone-ish mallet: 1 : 4 : 10 modes with motor tremolo."""
    f = mtof(m)
    n = ns(dur)
    t = tn(n)
    y = modes(n, [f, f * 4.0, f * 10.0], [1.0, 0.18, 0.03], [1.1, 0.25, 0.05], attack=0.002)
    y *= 1.0 - 0.22 * (0.5 - 0.5 * np.cos(2 * np.pi * trem * t))
    return y * fade_tail(n, 0.05) * vel


def steelpan(m: float, dur: float = 1.2, vel: float = 1.0) -> np.ndarray:
    """Steel-drum-ish note: harmonic partials with individual decays, a tiny
    strike 'bloom' in pitch and a slightly detuned second layer (shimmer)."""
    f = mtof(m)
    ring = min(max(dur + 0.5, 0.6), 2.2)
    n = ns(ring)
    t = tn(n)
    tau0 = 0.8 * (440.0 / f) ** 0.3
    y = np.zeros(n)
    for detune, lvl in ((1.0, 1.0), (1.0013, 0.3)):
        ph = phase_of(f * detune * (1.0 + 0.010 * np.exp(-t / 0.025)), n)
        for k, a, ts in ((1, 1.0, 1.0), (2, 0.55, 0.65), (3, 0.3, 0.45), (4, 0.12, 0.3), (5.02, 0.05, 0.2)):
            if k * f < 16000:
                y += lvl * a * np.exp(-t / (tau0 * ts)) * np.sin(k * ph)
    y *= np.clip(t / 0.002, 0, 1)
    return y * fade_tail(n, 0.08) * vel * 0.55


def brass(m: float, dur: float, vel: float = 1.0, bright: float = 0.72) -> np.ndarray:
    """Additive brass-ish voice (fanfares): harmonic series whose brightness
    blooms at the attack, small pitch scoop and late vibrato."""
    f0 = mtof(m)
    rel = 0.12
    n = ns(dur + rel)
    t = tn(n)
    f = f0 * (1.0 - 0.017 * np.exp(-t / 0.035)) * (1 + 0.004 * np.sin(2 * np.pi * 5.2 * t)
                                                    * np.clip((t - 0.25) / 0.3, 0, 1))
    ph = phase_of(f, n)
    b = np.clip(bright * (0.75 + 0.3 * np.exp(-t / 0.07)) * (0.6 + 0.4 * vel), 0.05, 0.95)
    y = np.zeros(n)
    bk = np.ones(n)
    for k in range(1, min(32, int(15000 / f0)) + 1):
        y += bk * np.sin(k * ph) / k
        bk = bk * b
    return y * env_ar(n, 0.022, rel, hold=dur) * vel * 0.6


def pad_voice(m: float, dur: float, rng, vel: float = 1.0, cutoff: float = 1300.0,
              attack: float = 0.7, release: float = 1.2) -> np.ndarray:
    """Warm detuned-saw pad note (slow attack and release)."""
    n = ns(dur + release)
    f = mtof(m)
    x = sum(saw(f * 2 ** (c / 1200), n, rng.random()) for c in (-7, 0, 6.5))
    x = lp(lp(x, cutoff), cutoff * 1.4)
    return x * env_ar(n, attack, release, hold=dur) * vel * 0.25


def chime(f: float, dur: float = 0.8, vel: float = 1.0, glass: bool = False, tau: float = 0.5) -> np.ndarray:
    """Bright bell/chime tone (coins, pickups, UI)."""
    n = ns(dur)
    if glass:   # inharmonic, glassy
        parts = ((1.0, 1.0, 1.0), (2.32, 0.42, 0.55), (4.25, 0.2, 0.3), (6.63, 0.09, 0.18))
    else:
        parts = ((1.0, 1.0, 1.0), (2.0, 0.3, 0.6), (3.0, 0.12, 0.35), (4.16, 0.08, 0.22))
    y = np.zeros(n)
    for detune, lvl in ((1.0, 1.0), (1.0021, 0.3)):          # faint detuned layer = shimmer
        y += lvl * modes(n, [f * r * detune for r, _, _ in parts], [a for _, a, _ in parts],
                         [tau * s for _, _, s in parts], attack=0.0006)
    return y * fade_tail(n, 0.03) * vel * 0.5


def bell(f0: float, dur: float = 2.2, vel: float = 1.0) -> np.ndarray:
    """Ship's bell: hum/prime/tierce/quint/nominal partials, beating pairs."""
    n = ns(dur)
    parts = ((0.5, 0.35, 2.0), (1.0, 1.0, 1.4), (1.19, 0.45, 1.0), (1.5, 0.25, 0.9),
             (2.0, 0.6, 0.8), (2.51, 0.2, 0.5), (2.66, 0.15, 0.45), (3.01, 0.12, 0.35), (4.07, 0.07, 0.25))
    y = np.zeros(n)
    for r, a, tau in parts:
        y += modes(n, [f0 * r, f0 * r + 0.9], [a, a * 0.6], [tau, tau * 0.9], attack=0.0008)
    return y * fade_tail(n, 0.05) * vel


# ---- percussion one-shots ----------------------------------------------------
def perc_kick(rng, vel: float = 1.0, punch: float = 1.0) -> np.ndarray:
    k = thump(0.38, 120 + 40 * punch, 47, 0.028, 0.12 + 0.05 * punch)
    return mix((k, 1.0), (click(rng, 0.003, 1500, 8000), 0.12 * punch)) * vel


def perc_shaker(rng, vel: float = 1.0) -> np.ndarray:
    n = ns(0.09)
    y = bp(white(n, rng), 4500, 12000) * curve(tn(n), [(0, 0), (0.010, 1), (0.03, 0.4), (0.09, 0)], "cos")
    return nz(y) * vel


def perc_woodblock(rng, pitch: float = 1.0, vel: float = 1.0) -> np.ndarray:
    n = ns(0.09)
    y = modes(n, [820 * pitch, 2050 * pitch, 3400 * pitch], [1, 0.35, 0.1], [0.03, 0.012, 0.006])
    return nz(mix((y, 1.0), (click(rng, 0.002, 2000, 9000), 0.12))) * vel


def perc_conga(rng, kind: str = "open", pitch: float = 1.0, vel: float = 1.0) -> np.ndarray:
    f0 = 210.0 * pitch
    if kind == "slap":
        n = ns(0.12)
        tone = modes(n, [f0 * 1.5, f0 * 2.9], [0.6, 0.3], [0.04, 0.02])
        y = mix((tone, 0.6), (nz(bp(white(n, rng), 1500, 6000)) * env_perc(n, 0.0003, 0.012), 0.9))
    else:
        dur, tau = (0.4, 0.17) if kind == "open" else (0.12, 0.04)
        n = ns(dur)
        t = tn(n)
        ph = phase_of(f0 * (1 + 0.06 * np.exp(-t / 0.02)), n)
        tone = (np.sin(ph) + 0.25 * np.sin(2.25 * ph)) * np.exp(-t / tau) * np.clip(t / 0.001, 0, 1)
        y = mix((tone, 1.0), (nz(bp(white(n, rng), 800, 3000)) * env_perc(n, 0.0003, 0.006), 0.25))
    return nz(y) * vel


def perc_clave(rng, vel: float = 1.0) -> np.ndarray:
    n = ns(0.1)
    return nz(modes(n, [2480, 6250], [1, 0.18], [0.035, 0.012])) * vel


def perc_clap(rng, vel: float = 1.0) -> np.ndarray:
    n = ns(0.2)
    w = white(n, rng)
    env = np.zeros(n)
    for k, d in enumerate((0.0, 0.009, 0.019)):
        place(env, ns(d), env_perc(ns(0.02), 0.0004, 0.004), 1.0 - 0.15 * k)
    place(env, ns(0.026), env_perc(ns(0.17), 0.0005, 0.05), 0.8)
    return nz(bp(w, 900, 4200) * env) * vel


def perc_tambourine(rng, vel: float = 1.0) -> np.ndarray:
    n = ns(0.12)
    jing = modes(n, [6900, 8800, 10400, 12100], [1, 0.8, 0.6, 0.4], [0.05, 0.04, 0.03, 0.025])
    hiss = hp(white(n, rng), 6000) * env_perc(n, 0.002, 0.035)
    return nz(mix((jing * rng.uniform(0.6, 1.0), 0.5), (nz(hiss), 1.0))) * vel


def perc_tom(rng, f0: float = 110.0, vel: float = 1.0) -> np.ndarray:
    k = thump(0.5, f0 * 1.45, f0, 0.025, 0.2)
    n = len(k)
    slap = nz(bp(white(n, rng), 500, 4000)) * env_perc(n, 0.0004, 0.012)
    return nz(mix((k, 1.0), (slap, 0.25))) * vel


def perc_cymbal(rng, dur: float = 1.6, swell: bool = False, vel: float = 1.0) -> np.ndarray:
    """Soft cymbal / shimmer: metallic noise; swell=True gives a reverse-ish rise."""
    n = ns(dur)
    t = tn(n)
    metal = shaped_noise(n, rng, lambda f, tt: gauss_band(f, 7500, 0.6) + 0.4 * gauss_band(f, 4200, 0.4))
    if swell:
        env = curve(t, [(0, 0), (dur * 0.85, 1), (dur, 0)], "cos") ** 2
    else:
        env = np.clip(t / 0.003, 0, 1) * np.exp(-t / (dur / 4)) * fade_tail(n, 0.05)
    return nz(metal * env) * vel


# =============================================================================
# 4. Sound effects
# =============================================================================
@dataclass
class SfxSpec:
    name: str
    fn: Callable
    bus: str = "SFX"
    volume_db: float = 0.0
    loop: bool = False
    peak_db: float = SFX_PEAK_DB
    sharp: bool = False          # sharp transient -> 1 ms fade-in instead of 2 ms
    group: str | None = None


SFX: list[SfxSpec] = []


def sfx(name: str, **kw):
    """Register a one-off sound: fn(rng) -> mono float array."""
    def deco(fn):
        SFX.append(SfxSpec(name, fn, **kw))
        return fn
    return deco


def sfx_family(prefix: str, count: int, **kw):
    """Register numbered variations prefix_01..: fn(rng, index) -> array."""
    def deco(fn):
        for i in range(count):
            SFX.append(SfxSpec(f"{prefix}_{i + 1:02d}", (lambda rng, i=i: fn(rng, i)), group=prefix, **kw))
        return fn
    return deco


def finalize_sfx(x: np.ndarray, spec: SfxSpec) -> np.ndarray:
    """DC/sub-sonic removal, silence trimming, click-free edges, peak level."""
    x = np.asarray(x, float)
    if spec.loop:
        # circular high-pass keeps the loop seamless; no trims, no fades
        x = circ_filter(x, lambda f: np.clip((f - 12.0) / 14.0, 0.0, 1.0))
    else:
        x = sps.sosfilt(sps.butter(2, 20.0, "highpass", fs=SR, output="sos"), x)
        pk = np.max(np.abs(x))
        on = int(np.argmax(np.abs(x) > pk * db2a(-40)))
        x = x[max(0, on - ns(0.0004)):]
        # trailing trim on a smoothed envelope so we don't cut inside a cycle
        env = sps.lfilter([0.002], [1, -0.998], np.abs(x))
        above = np.nonzero(env > pk * db2a(-54))[0]
        end = min(len(x), int(above[-1]) + ns(0.005)) if len(above) else len(x)
        x = fade(x[:end], 0.001 if spec.sharp else 0.002, 0.012)
    return nz(x, db2a(spec.peak_db))


# ---- 4a. Movement -------------------------------------------------------------
FOOT_PITCH = (1.0, 0.93, 1.07, 0.97)


def _footfall(rng, idx, hit, gap=(0.022, 0.04), toe=(0.4, 0.65)):
    """Heel strike + softer ball-of-foot contact; idx picks the variation."""
    p = FOOT_PITCH[idx] * rng.uniform(0.985, 1.015)
    heel = hit(rng, p)
    ball = hit(rng, p * rng.uniform(1.04, 1.12))
    return mix((heel, 1.0), (ball, rng.uniform(*toe), rng.uniform(*gap)))


@sfx_family("footstep_sand", 4, volume_db=-9.0, peak_db=-3.0)
def footstep_sand(rng, idx):
    def hit(rng, p):
        n = ns(0.16)
        t = tn(n)
        crunch = grains(n, rng, 2600 * np.exp(-t / 0.045), lo=1200 * p, hi=7000)
        hiss = bp(white(n, rng), 700 * p, 3200 * p) * env_perc(n, 0.004, 0.035)
        thud = thump(0.08, 110 * p, 70 * p, 0.02, 0.03)
        return mix((nz(crunch), 0.8), (nz(hiss), 0.45), (nz(thud), 0.35))
    return _footfall(rng, idx, hit, gap=(0.03, 0.05))


@sfx_family("footstep_grass", 4, volume_db=-9.0, peak_db=-3.0)
def footstep_grass(rng, idx):
    def hit(rng, p):
        n = ns(0.17)
        t = tn(n)
        swish = whoosh(0.17, rng, [(0, 3800 * p), (0.17, 2400 * p)], 0.9,
                       [(0, 0), (0.008, 1), (0.05, 0.5), (0.17, 0)])
        thud = thump(0.09, 95 * p, 62 * p, 0.02, 0.035)
        blades = grains(n, rng, 900 * np.exp(-t / 0.04), lo=2500, hi=9000)
        return mix((swish, 0.7), (nz(thud), 0.5), (nz(blades), 0.25))
    return _footfall(rng, idx, hit, gap=(0.03, 0.05), toe=(0.35, 0.55))


@sfx_family("footstep_wood", 4, volume_db=-8.0, peak_db=-3.0, sharp=True)
def footstep_wood(rng, idx):
    def hit(rng, p):
        n = ns(0.2)
        fr = np.array([142, 310, 505, 790, 1180]) * p * rng.uniform(0.97, 1.03, 5)
        body = modes(n, fr, [1.0, 0.7, 0.45, 0.25, 0.12], [0.075, 0.05, 0.035, 0.025, 0.018])
        thud = thump(0.1, 125 * p, 80 * p, 0.015, 0.04)
        return mix((nz(body), 0.8), (click(rng, 0.006, 1500, 9000), 0.3), (nz(thud), 0.45))
    return _footfall(rng, idx, hit, gap=(0.025, 0.04), toe=(0.35, 0.55))


@sfx_family("footstep_stone", 4, volume_db=-8.0, peak_db=-3.0, sharp=True)
def footstep_stone(rng, idx):
    def hit(rng, p):
        n = ns(0.11)
        t = tn(n)
        tick = modes(ns(0.04), [2100 * p, 3900 * p, 5600 * p], [1, 0.5, 0.25], [0.006, 0.004, 0.003])
        thud = thump(0.09, 165 * p, 92 * p, 0.012, 0.022)
        grit = grains(n, rng, 1500 * np.exp(-t / 0.02), lo=3000, hi=10000)
        return mix((click(rng, 0.008, 2500 * p, 11000), 0.6), (nz(thud), 0.6), (nz(grit), 0.22),
                   (nz(tick), 0.25))
    return _footfall(rng, idx, hit, gap=(0.018, 0.03), toe=(0.3, 0.5))


@sfx("jump", volume_db=-5.0)
def jump(rng):
    n = ns(0.2)
    t = tn(n)
    w = whoosh(0.2, rng, [(0, 600), (0.14, 2800), (0.2, 3200)], 0.7, [(0, 0), (0.012, 1), (0.07, 0.7), (0.2, 0)])
    tone = sine(curve(t, [(0, 380), (0.12, 760)], "exp"), n) * env_perc(n, 0.003, 0.05)
    return mix((w, 0.8), (nz(cloth_flap(0.08, rng, 34)), 0.35, 0.01), (tone, 0.16))


@sfx("jump_high", volume_db=-4.0)
def jump_high(rng):
    w = whoosh(0.38, rng, [(0, 500), (0.25, 3200), (0.38, 3600)], 0.8, [(0, 0), (0.015, 1), (0.15, 0.8), (0.38, 0)])
    n = ns(0.4)
    t = tn(n)
    f = curve(t, [(0, 170), (0.25, 430), (0.4, 520)], "exp") * (1 + 0.07 * np.sin(2 * np.pi * 26 * t) * np.exp(-t / 0.2))
    boing = harmonic_tone(f, n, [1, 0.35, 0.15]) * env_perc(n, 0.003, 0.12)
    return mix((w, 0.75), (nz(boing), 0.3), (nz(cloth_flap(0.12, rng, 30)), 0.3, 0.02))


@sfx("long_jump", volume_db=-4.0)
def long_jump(rng):
    w = whoosh(0.5, rng, [(0, 700), (0.2, 3400), (0.5, 800)], 0.6, [(0, 0), (0.04, 0.5), (0.2, 1), (0.5, 0)],
               tonal=0.5, tonal_width=0.08)
    return mix((w, 0.9), (nz(cloth_flap(0.25, rng, 40, depth=0.7)), 0.25, 0.03))


def _land(rng, size: int) -> np.ndarray:
    """Boot thud + dust crunch. size: 0 soft, 1 normal, 2 heavy (adds boom)."""
    s = (0.6, 1.0, 1.6)[size]
    dur = (0.25, 0.4, 0.9)[size]
    n = ns(dur)
    t = tn(n)
    thud = thump(0.18 * s, (150, 130, 115)[size], (85, 70, 55)[size], 0.02, 0.045 * s)
    body = lp(white(n, rng), 320) * env_perc(n, 0.002, 0.035 * s)
    slap = bp(white(ns(0.03), rng), 700, 2600) * env_perc(ns(0.03), 0.0004, 0.008)
    crunch = grains(n, rng, 2600 * s * np.exp(-t / (0.05 * s)), lo=1000, hi=6500)
    dust = whoosh(min(dur, 0.35 * s), rng, [(0, 2600), (0.3 * s, 1400)], 1.2, [(0, 0), (0.006, 1), (0.3 * s, 0)])
    parts = [(nz(thud), 1.0), (nz(body), 0.45), (nz(slap), 0.45), (nz(crunch), 0.4 * s), (dust, 0.22 * s)]
    if size == 2:
        parts.append((nz(thump(0.85, 62, 36, 0.06, 0.26)), 0.9))
    return softclip(nz(mix(*parts)), 1.4 if size == 2 else 1.0)


@sfx("land_soft", volume_db=-8.0, sharp=True)
def land_soft(rng):
    return _land(rng, 0)


@sfx("land_normal", volume_db=-5.0, sharp=True)
def land_normal(rng):
    return _land(rng, 1)


@sfx("land_heavy", volume_db=-2.0, sharp=True)
def land_heavy(rng):
    return _land(rng, 2)


@sfx("dive", volume_db=-4.0)
def dive(rng):
    w = whoosh(0.32, rng, [(0, 900), (0.1, 2600), (0.32, 1200)], 0.75, [(0, 0), (0.02, 1), (0.12, 0.85), (0.32, 0)])
    return mix((w, 0.85), (nz(cloth_flap(0.18, rng, 28, depth=0.8)), 0.35, 0.015))


@sfx("roll", volume_db=-5.0)
def roll(rng):
    dur = 0.5
    n = ns(dur)
    t = tn(n)
    parts = []
    for ts, a in ((0.0, 1.0), (0.11, 0.75), (0.23, 0.6), (0.34, 0.45)):
        p = rng.uniform(0.92, 1.08)
        hit = mix((nz(thump(0.1, 125 * p, 72 * p, 0.015, 0.035)), 1.0), (click(rng, 0.02, 600, 3000), 0.35))
        parts.append((hit, a, ts))
    scuffle = grains(n, rng, curve(t, [(0, 1600), (0.4, 900), (dur, 0)]), lo=1500, hi=6500)
    cloth = bp(white(n, rng), 400, 2000) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)) \
        * curve(t, [(0, 0), (0.03, 1), (0.4, 0.6), (dur, 0)], "cos")
    w = whoosh(0.45, rng, [(0, 600), (0.2, 1400), (0.45, 700)], 0.9, [(0, 0), (0.1, 1), (0.45, 0)])
    return mix(*parts, (nz(scuffle), 0.35), (nz(cloth), 0.25), (w, 0.3))


@sfx("skid", volume_db=-4.0)
def skid(rng):
    dur = 0.36
    n = ns(dur)
    t = tn(n)
    scrape = shaped_noise(n, rng, lambda f, tt: gauss_band(f, curve(tt, [(0, 2600), (dur, 1300)], "exp"), 1.0))
    stick = 1.0 + 0.6 * nz(lp(white(n, rng), 45))          # irregular stick-slip
    grit = grains(n, rng, 2200, lo=1500, hi=8000)
    squeak = reson(white(n, rng), 1750, 30) * np.clip(stick - 1.0, 0, None)
    env = curve(t, [(0, 0), (0.015, 1), (0.25, 0.8), (dur, 0)], "cos")
    return mix((nz(scrape * stick), 0.8), (nz(grit), 0.4), (nz(squeak), 0.12)) * env


@sfx("slide_loop", loop=True, volume_db=-8.0)
def slide_loop(rng):
    L = ns(1.5)
    hiss = circ_noise(L, rng, lambda f: gauss_band(f, 2600, 1.2))
    low = circ_noise(L, rng, lambda f: gauss_band(f, 500, 1.0))
    grit = circ_grains(L, rng, 1800, mag_fn=lambda f: gauss_band(f, 4000, 0.9))
    grit /= np.std(grit) + 1e-12
    return (0.7 * hiss + 0.35 * low + 0.4 * grit) * periodic_lfo(L, rng, 4, 0.25)


@sfx("ground_pound_start", volume_db=-4.0)
def ground_pound_start(rng):
    dur = 0.36
    n = ns(dur)
    t = tn(n)
    w = whoosh(dur, rng, [(0, 500), (0.3, 3000), (dur, 3400)], 0.7, [(0, 0), (0.02, 0.6), (0.28, 1), (dur, 0)])
    spin = 1.0 - 0.55 * (0.5 + 0.5 * np.cos(phase_of(curve(t, [(0, 9), (dur, 22)]), n)))
    whistle = sine(curve(t, [(0, 420), (0.34, 1250)], "exp"), n) * curve(t, [(0, 0), (0.05, 0.6), (0.3, 1), (dur, 0)], "cos")
    return mix((w * spin, 0.85), (whistle, 0.18))


@sfx("ground_pound_impact", volume_db=-1.0, sharp=True)
def ground_pound_impact(rng):
    dur = 0.9
    n = ns(dur)
    t = tn(n)
    kick = thump(0.35, 165, 46, 0.022, 0.11)
    boom = thump(0.9, 58, 36, 0.08, 0.3)
    body = lp(white(n, rng), 600) * env_perc(n, 0.002, 0.06)
    crunch = grains(n, rng, 3200 * np.exp(-t / 0.08), lo=900, hi=7000)
    debris = grains(n, rng, 260 * np.exp(-np.maximum(t - 0.08, 0) / 0.2) * (t > 0.08), lo=1500, hi=6000,
                    grain_ms=(1, 4))
    out = mix((nz(kick), 1.0), (nz(boom), 0.8), (nz(body), 0.5), (click(rng, 0.03, 1500, 8000), 0.4),
              (nz(crunch), 0.5), (nz(debris), 0.25))
    return softclip(nz(out), 1.8)


@sfx("ledge_grab", volume_db=-4.0, sharp=True)
def ledge_grab(rng):
    def slap(p):
        n = ns(0.09)
        t = tn(n)
        s = bp(white(n, rng), 900 * p, 4200 * p) * env_perc(n, 0.0004, 0.012)
        body = thump(0.06, 260 * p, 180 * p, 0.01, 0.02)
        grit = grains(n, rng, 2000 * np.exp(-t / 0.015), lo=3000, hi=9000)
        return mix((nz(s), 0.8), (nz(body), 0.5), (nz(grit), 0.2))
    return mix((slap(1.0), 1.0), (slap(0.9), 0.75, 0.028))


@sfx("ledge_climb", volume_db=-6.0)
def ledge_climb(rng):
    dur = 0.55
    n = ns(dur)
    t = tn(n)
    flutter = 0.55 + 0.45 * nz(lp(white(n, rng), 15))
    rustle = bp(white(n, rng), 500, 3000) * flutter * curve(t, [(0, 0), (0.05, 1), (0.35, 0.7), (dur, 0)], "cos")
    scrape = grains(n, rng, curve(t, [(0, 0), (0.05, 1800), (0.3, 800), (0.4, 0), (dur, 0)]), lo=2000, hi=8000)
    step = mix((nz(thump(0.08, 130, 80, 0.012, 0.03)), 1.0), (nz(grains(ns(0.08), rng, 1500, lo=1200, hi=6000)), 0.3))
    return mix((nz(rustle), 0.5), (nz(scrape), 0.35), (step, 0.6, 0.38))


@sfx("wall_kick", volume_db=-3.0, sharp=True)
def wall_kick(rng):
    thud = mix((nz(thump(0.14, 175, 85, 0.012, 0.045)), 1.0), (click(rng, 0.01, 800, 6000), 0.45),
               (nz(modes(ns(0.12), [240, 520, 910], [1, 0.5, 0.25], [0.05, 0.03, 0.02])), 0.4))
    w = whoosh(0.28, rng, [(0, 900), (0.15, 2800), (0.28, 2000)], 0.7, [(0, 0), (0.03, 1), (0.28, 0)])
    return mix((thud, 1.0), (w, 0.6, 0.03))


@sfx("hurt", volume_db=-2.0, sharp=True)
def hurt(rng):
    """Cartoon 'bonk' (hollow knock with pitch drop) + dizzy warble."""
    n = ns(0.18)
    t = tn(n)
    f = curve(t, [(0, 820), (0.06, 470), (0.18, 440)], "exp")
    bonk = harmonic_tone(f, n, [1, 0.45, 0.2]) * env_perc(n, 0.0008, 0.06)
    knock = modes(ns(0.12), [380, 960, 1640], [1, 0.5, 0.25], [0.04, 0.02, 0.012])
    thud = thump(0.1, 180, 90, 0.01, 0.03)
    n2 = ns(0.42)
    t2 = tn(n2)
    f2 = curve(t2, [(0, 980), (0.42, 520)], "exp") * (1 + 0.035 * np.sin(2 * np.pi * 13 * t2))
    warble = harmonic_tone(f2, n2, [1, 0.2]) * curve(t2, [(0, 0), (0.03, 1), (0.3, 0.6), (0.42, 0)], "cos")
    return mix((nz(bonk), 0.9), (nz(knock), 0.4), (nz(thud), 0.5), (nz(warble), 0.28, 0.07))


@sfx("fall_whoosh", volume_db=-3.0)
def fall_whoosh(rng):
    """Descending slide-whistle style fall with a wind bed."""
    dur = 1.35
    n = ns(dur)
    t = tn(n)
    pts = [(0, 1650), (dur, 240)]
    f = curve(t, pts, "exp") * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * t))
    whistle = harmonic_tone(f, n, [1, 0.12])
    breath = shaped_noise(n, rng, lambda ff, tt: gauss_band(ff, curve(tt, pts, "exp"), 0.12))
    wind = whoosh(dur, rng, [(0, 900), (dur, 400)], 1.0, [(0, 0.2), (0.6, 0.8), (dur, 0)])
    env = curve(t, [(0, 0), (0.04, 1), (0.9, 0.85), (dur, 0)], "cos")
    return mix((whistle * env, 0.55), (nz(breath) * env, 0.12), (wind, 0.35))


@sfx("respawn_poof", volume_db=-4.0)
def respawn_poof(rng):
    """Soft cloud pop: tiny pitch-dropping pop + airy puff (no magic)."""
    pop = thump(0.05, 900, 300, 0.008, 0.012)
    n = ns(0.4)
    puff = shaped_noise(n, rng, lambda f, tt: gauss_band(f, curve(tt, [(0, 1800), (0.4, 650)], "exp"), 1.3))
    puff = nz(puff) * curve(tn(n), [(0, 0), (0.008, 1), (0.08, 0.55), (0.4, 0)], "cos")
    air = lp(white(ns(0.08), rng), 4000) * env_perc(ns(0.08), 0.003, 0.03)
    return mix((nz(pop), 0.55), (puff, 0.8), (nz(air), 0.25))


# ---- 4b. Water -----------------------------------------------------------------
def _bubbles(rng, n, count, t_range, f_range, dur_range=(0.025, 0.07), rise=(0.6, 1.6), amp=(0.3, 1.0)):
    """Scatter `count` random bubbles into an n-sample buffer."""
    buf = np.zeros(n)
    for _ in range(count):
        b = bubble(rng.uniform(*f_range), rng.uniform(*dur_range), rng.uniform(*rise))
        place(buf, ns(rng.uniform(*t_range)), b, rng.uniform(*amp))
    return buf


@sfx_family("swim_stroke", 3, volume_db=-7.0)
def swim_stroke(rng, idx):
    p = (1.0, 0.92, 1.08)[idx]
    dur = 0.55
    n = ns(dur)
    t = tn(n)
    wash = shaped_noise(n, rng, lambda f, tt: gauss_band(
        f, curve(tt, [(0, 700 * p), (0.15, 1500 * p), (dur, 900 * p)], "exp"), 1.0))
    env = curve(t, [(0, 0), (0.09, 1), (0.2, 0.8), (dur, 0)], "cos")
    bub = _bubbles(rng, n, 7, (0.03, 0.4), (500 * p, 1400 * p))
    gloop = bubble(260 * p, 0.12, 0.8, tau=0.04)
    return mix((nz(wash) * env, 0.6), (nz(bub), 0.45), (nz(gloop), 0.25, 0.05))


@sfx("splash_small", volume_db=-4.0)
def splash_small(rng):
    dur = 0.6
    n = ns(dur)
    t = tn(n)
    burst = shaped_noise(n, rng, lambda f, tt: gauss_band(f, curve(tt, [(0, 2600), (dur, 1500)], "exp"), 1.6))
    burst = nz(burst) * curve(t, [(0, 0), (0.006, 1), (0.12, 0.45), (dur, 0)], "cos")
    plunk = bubble(380, 0.09, 1.2, tau=0.03)
    drops = _bubbles(rng, n, 10, (0.08, 0.5), (900, 2600), amp=(0.2, 0.7))
    return mix((burst, 0.8), (nz(plunk), 0.5), (nz(drops), 0.35))


@sfx("splash_big", volume_db=-2.0, sharp=True)
def splash_big(rng):
    dur = 1.25
    n = ns(dur)
    t = tn(n)
    nw = ns(0.3)
    whump = mix((nz(thump(0.3, 110, 55, 0.03, 0.09)), 1.0),
                (nz(lp(white(nw, rng), 350) * env_perc(nw, 0.003, 0.08)), 0.6))
    burst = shaped_noise(n, rng, lambda f, tt: gauss_band(f, curve(tt, [(0, 1900), (dur, 1100)], "exp"), 1.8))
    burst = nz(burst) * curve(t, [(0, 0), (0.01, 1), (0.25, 0.55), (dur, 0)], "cos")
    spray = nz(hp(white(n, rng), 3500)) * curve(t, [(0, 0), (0.02, 0.8), (0.5, 0.25), (1.0, 0), (dur, 0)], "cos")
    drops = _bubbles(rng, n, 24, (0.15, 1.1), (700, 2800), amp=(0.2, 0.8))
    plunk = bubble(240, 0.15, 1.0, tau=0.05)
    return mix((whump, 0.8), (burst, 0.9), (spray, 0.35), (nz(drops), 0.35), (nz(plunk), 0.45, 0.01))


@sfx("water_exit", volume_db=-6.0)
def water_exit(rng):
    """Water sheds off Patchy, then drips."""
    dur = 0.95
    n = ns(dur)
    nsd = ns(0.35)
    shed = nz(shaped_noise(nsd, rng, lambda f, tt: gauss_band(f, 2200, 1.4)))
    shed *= curve(tn(nsd), [(0, 0), (0.01, 1), (0.1, 0.5), (0.35, 0)], "cos")
    drips = np.zeros(n)
    tt = 0.04
    while tt < dur - 0.08:
        drop = bubble(rng.uniform(1300, 3000), rng.uniform(0.02, 0.05), rng.uniform(0.8, 1.8))
        place(drips, ns(tt), drop, rng.uniform(0.4, 1.0) * (1 - tt / dur) ** 0.5)
        tt += rng.exponential(0.07) + 0.025 + tt * 0.12
    return mix((shed, 0.5), (nz(drips), 0.7))


@sfx("underwater_loop", loop=True, bus="Ambience", volume_db=-6.0)
def underwater_loop(rng):
    L = ns(3.0)
    rumble = circ_noise(L, rng, lambda f: lp_gain(f, 260, 3) * hp_gain(f, 25, 2))
    murmur = circ_noise(L, rng, lambda f: gauss_band(f, 600, 0.6))
    bub = np.zeros(L + ns(0.6))
    for _ in range(4):                                   # a few rising bubble streams
        t0 = rng.uniform(0, 3.0)
        f0 = rng.uniform(350, 700)
        for k in range(int(rng.integers(4, 8))):
            place(bub, ns(t0 + k * rng.uniform(0.05, 0.11)), bubble(f0 * (1 + 0.12 * k), 0.06, 1.0),
                  rng.uniform(0.3, 0.9))
    bub = fold_tail(lp(bub, 1500), L)                    # filter, then wrap = circular
    return (0.8 * rumble * periodic_lfo(L, rng, 2, 0.35) + 0.25 * murmur * periodic_lfo(L, rng, 5, 0.6)
            + 1.0 * nz(bub))


# ---- 4c. Hook & tools -----------------------------------------------------------
@sfx("hook_swipe", volume_db=-3.0)
def hook_swipe(rng):
    dur = 0.32
    n = ns(dur)
    t = tn(n)
    w = whoosh(dur, rng, [(0, 1200), (0.1, 3800), (dur, 2000)], 0.6, [(0, 0), (0.02, 1), (0.1, 0.9), (dur, 0)])
    ring = shaped_noise(n, rng, lambda f, tt: gauss_band(f, 3150, 0.03) + 0.7 * gauss_band(f, 4720, 0.025)
                        + 0.4 * gauss_band(f, 6900, 0.02))
    ring = nz(ring) * curve(t, [(0, 0), (0.04, 1), (dur, 0)], "cos")
    return mix((w, 0.85), (ring, 0.3))


@sfx("hook_hit", volume_db=-2.0, sharp=True)
def hook_hit(rng):
    n = ns(0.7)
    fr = np.array([523, 1214, 2023, 2826, 3712, 4890]) * rng.uniform(0.99, 1.01, 6)
    clang = modes(n, fr, [1, 0.8, 0.6, 0.45, 0.3, 0.2], [0.35, 0.25, 0.18, 0.12, 0.09, 0.07])
    nt = ns(0.08)
    thwack = bp(white(nt, rng), 400, 3000) * env_perc(nt, 0.0003, 0.015)
    return mix((nz(clang), 0.7), (nz(thwack), 0.8), (nz(thump(0.12, 150, 80, 0.012, 0.035)), 0.6),
               (click(rng, 0.004, 3000, 12000), 0.4))


@sfx("hook_latch", volume_db=-3.0, sharp=True)
def hook_latch(rng):
    c1 = mix((nz(modes(ns(0.15), [880, 2140, 3510], [1, 0.6, 0.4], [0.04, 0.03, 0.02])), 1.0),
             (click(rng, 0.003, 2500, 12000), 0.5))
    ring = mix((nz(modes(ns(0.8), [1245, 2790, 4410, 6120], [1, 0.55, 0.35, 0.2], [0.45, 0.3, 0.2, 0.12])), 1.0),
               (click(rng, 0.003, 2500, 12000), 0.6))
    return mix((c1, 0.7), (ring, 0.9, 0.035), (nz(thump(0.06, 300, 180, 0.008, 0.015)), 0.35, 0.035))


@sfx("hook_release", volume_db=-4.0, sharp=True)
def hook_release(rng):
    snap = mix((click(rng, 0.03, 1800, 12000), 1.0), (nz(thump(0.05, 300, 150, 0.005, 0.012)), 0.5))
    nr = ns(0.06)
    rope = bp(white(nr, rng), 300, 1500) * env_perc(nr, 0.001, 0.015) * (0.6 + 0.4 * np.sin(2 * np.pi * 45 * tn(nr)))
    w = whoosh(0.32, rng, [(0, 2400), (0.32, 900)], 0.8, [(0, 0), (0.02, 1), (0.32, 0)])
    return mix((snap, 0.9), (nz(rope), 0.4, 0.005), (w, 0.7, 0.02))


@sfx("rope_creak", volume_db=-6.0)
def rope_creak(rng):
    return creak(0.6, rng, [(0, 55), (0.3, 85), (0.6, 60)],
                 [(420, 8, 1.0), (980, 10, 0.6), (1850, 12, 0.35), (3100, 14, 0.15)],
                 [(0, 0), (0.08, 1), (0.45, 0.8), (0.6, 0)])


@sfx("attachment_clunk", volume_db=-2.0, sharp=True)
def attachment_clunk(rng):
    """Ratchet clicks, then a heavy satisfying CLUNK as the tool seats."""
    def tick(p):
        return mix((nz(modes(ns(0.03), [3200 * p, 5100 * p, 7300 * p], [1, 0.6, 0.3], [0.006, 0.004, 0.003])), 1.0),
                   (click(rng, 0.002, 4000, 14000), 0.4))
    ratchet = mix(*[(tick(p), a, d) for p, a, d in
                    ((1.0, 0.5, 0.0), (1.04, 0.45, 0.028), (0.97, 0.5, 0.056), (1.02, 0.55, 0.084))])
    ct = 0.13
    clunk = modes(ns(0.4), [150, 342, 610, 985, 1460], [1, 0.8, 0.55, 0.35, 0.2], [0.12, 0.08, 0.05, 0.035, 0.025])
    latch = modes(ns(0.25), [2350, 3900], [1, 0.5], [0.08, 0.05])
    return mix((ratchet, 0.6), (nz(clunk), 1.0, ct), (nz(thump(0.2, 140, 62, 0.015, 0.06)), 0.8, ct),
               (click(rng, 0.01, 1200, 6000), 0.6, ct), (nz(latch), 0.15, ct + 0.005))


@sfx("grapple_fire", volume_db=-3.0, sharp=True)
def grapple_fire(rng):
    """Spring launch 'sproing' + pop + rattling chain."""
    n = ns(0.25)
    t = tn(n)
    f = curve(t, [(0, 260), (0.07, 980), (0.25, 900)], "exp") * (1 + 0.06 * np.sin(2 * np.pi * 31 * t) * np.exp(-t / 0.08))
    ph = phase_of(f, n)
    spring = (np.sin(ph) + 0.5 * np.sin(2.76 * ph) + 0.25 * np.sin(5.4 * ph)) * env_perc(n, 0.001, 0.07)
    pop = mix((nz(thump(0.08, 220, 90, 0.008, 0.02)), 1.0), (click(rng, 0.01, 1500, 9000), 0.7))
    chain = np.zeros(ns(0.65))
    tt = 0.03
    while tt < 0.55:
        fq = rng.uniform(2500, 5200)
        tk = modes(ns(0.04), [fq, fq * 1.6, fq * 2.7], [1, 0.5, 0.25], [rng.uniform(0.006, 0.015), 0.006, 0.004])
        place(chain, ns(tt), tk, rng.uniform(0.3, 1.0) * (1 - tt / 0.6))
        tt += rng.exponential(0.012) + 0.006 + tt * 0.05
    w = whoosh(0.35, rng, [(0, 1500), (0.35, 3200)], 0.8, [(0, 0), (0.03, 1), (0.35, 0)])
    return mix((pop, 0.8), (nz(spring), 0.5), (nz(chain), 0.5, 0.01), (w, 0.4, 0.02))


@sfx("grapple_hit", volume_db=-3.0, sharp=True)
def grapple_hit(rng):
    thunk = modes(ns(0.25), [165, 355, 590, 910], [1, 0.7, 0.4, 0.2], [0.08, 0.05, 0.03, 0.02])
    tick = modes(ns(0.1), [2900, 4700], [1, 0.5], [0.03, 0.02])
    ng = ns(0.12)
    splinter = grains(ng, rng, 2000 * np.exp(-tn(ng) / 0.03), lo=2000, hi=8000)
    return mix((nz(thunk), 1.0), (nz(thump(0.15, 140, 70, 0.012, 0.045)), 0.7),
               (click(rng, 0.006, 2000, 10000), 0.5), (nz(tick), 0.2), (nz(splinter), 0.3))


@sfx("grapple_reel_loop", loop=True, volume_db=-6.0)
def grapple_reel_loop(rng):
    """Ratchet clicks every 40 ms over a geared whirr; exactly periodic."""
    clicks = 24
    step = ns(0.96) // clicks
    L = step * clicks
    buf = np.zeros(L + ns(0.1))
    for k in range(clicks):
        p = 1 + 0.03 * rng.standard_normal()
        tk = mix((nz(modes(ns(0.03), [2600 * p, 4300 * p, 6800 * p], [1, 0.5, 0.3], [0.007, 0.005, 0.003])), 1.0),
                 (click(rng, 0.002, 3000, 12000), 0.3))
        start = (k * step + int(rng.integers(-20, 20))) % L
        place(buf, start, tk, (1.0 if k % 4 == 0 else 0.75) * rng.uniform(0.85, 1.0))
    ticks = fold_tail(buf, L)
    u = np.arange(L) / L
    whirr = circ_noise(L, rng, lambda f: gauss_band(f, 260, 0.5)) * (1 + 0.5 * np.cos(2 * np.pi * clicks * u))
    hiss = circ_noise(L, rng, lambda f: gauss_band(f, 3000, 1.0))
    motor = harmonic_tone(loop_freq(125, L), L, [1, 0.5, 0.25])
    return 0.9 * nz(ticks) + 0.06 * whirr + 0.02 * hiss + 0.05 * motor


@sfx("cannon_fire", volume_db=-1.0, sharp=True)
def cannon_fire(rng):
    dur = 0.9
    n = ns(dur)
    t = tn(n)
    kick = thump(0.4, 190, 50, 0.02, 0.1)
    boom = lp(white(n, rng), 380) * np.clip(t / 0.004, 0, 1) * np.exp(-t / 0.2)
    sub = thump(dur, 70, 42, 0.05, 0.3)
    fwoomp = whoosh(0.4, rng, [(0, 600), (0.4, 250)], 1.0, [(0, 0), (0.01, 1), (0.4, 0)])
    out = mix((click(rng, 0.02, 800, 12000), 0.7), (nz(kick), 1.0), (nz(boom), 0.7), (nz(sub), 0.6), (fwoomp, 0.4))
    return softclip(nz(out), 2.0)


@sfx("explosion", volume_db=0.0, sharp=True)
def explosion(rng):
    """Cartoony punchy boom: kick + closing low-pass blast + rumble + debris."""
    dur = 1.6
    n = ns(dur)
    t = tn(n)
    kick = thump(0.5, 130, 36, 0.03, 0.16)
    blast = shaped_noise(n, rng, lambda f, tt: lp_gain(f, curve(tt, [(0, 6000), (0.15, 1500), (dur, 250)], "exp"), 1.5))
    blast = nz(blast) * curve(t, [(0, 0), (0.003, 1), (0.1, 0.7), (0.5, 0.3), (dur, 0)], "cos")
    rumble = lp(colored(n, rng, 2.0), 120) * np.exp(-t / 0.5) * np.clip(t / 0.01, 0, 1)
    debris = grains(n, rng, 900 * np.exp(-t / 0.3) * (t > 0.05), lo=1200, hi=6000, grain_ms=(0.8, 3))
    out = mix((click(rng, 0.03, 1500, 12000), 0.6), (nz(kick), 1.0), (blast, 0.9), (nz(rumble), 0.6), (nz(debris), 0.3))
    return softclip(nz(out), 2.5)


def _dig(rng, p: float = 1.0) -> np.ndarray:
    """Blade stab into sand/dirt, crunchy scoop, then the load pouring off."""
    n1 = ns(0.1)
    stab = grains(n1, rng, 3000 * np.exp(-tn(n1) / 0.03), lo=1800 * p, hi=8000)
    blade = modes(ns(0.1), [1850 * p, 3300 * p], [1, 0.5], [0.04, 0.025])
    n2 = ns(0.25)
    crunch = grains(n2, rng, 2500 * np.exp(-tn(n2) / 0.08), lo=500 * p, hi=3500 * p)
    body = bp(white(n2, rng), 400 * p, 1600 * p) * env_perc(n2, 0.003, 0.06)
    n3 = ns(0.35)
    pour = grains(n3, rng, curve(tn(n3), [(0, 0), (0.05, 1800), (0.35, 0)]), lo=900, hi=5000)
    return mix((nz(stab), 0.6), (nz(blade), 0.18), (nz(thump(0.08, 120 * p, 75 * p, 0.01, 0.03)), 0.5, 0.005),
               (nz(crunch), 0.8, 0.01), (nz(body), 0.4, 0.01), (nz(pour), 0.45, 0.17))


@sfx_family("shovel_dig", 3, volume_db=-5.0, sharp=True)
def shovel_dig(rng, idx):
    return _dig(rng, (1.0, 0.94, 1.06)[idx])


@sfx("shovel_find", volume_db=-3.0, sharp=True)
def shovel_find(rng):
    """Dig, then the blade 'tinks' on something metal + a small discovery chime."""
    tink = modes(ns(0.9), [2093, 4870, 7350], [1, 0.4, 0.2], [0.5, 0.25, 0.12])
    c1 = chime(mtof(86), 0.8, tau=0.45)
    c2 = chime(mtof(91), 1.0, tau=0.6)
    out = mix((_dig(rng, 1.0), 0.8), (nz(tink), 0.6, 0.28), (click(rng, 0.002, 4000, 14000), 0.3, 0.28),
              (nz(c1), 0.32, 0.42), (nz(c2), 0.38, 0.52))
    return fit(reverb(out, "hall", 0.12), 1.5, 0.35)


@sfx("lantern_on", volume_db=-5.0)
def lantern_on(rng):
    """Latch click, warm glass chime, and a soft insect buzz waking up."""
    latch = mix((nz(modes(ns(0.05), [3100, 5200], [1, 0.5], [0.01, 0.006])), 1.0), (click(rng, 0.002, 3000, 12000), 0.4))
    glass = chime(mtof(83), 1.2, glass=True, tau=0.7)
    warm = chime(mtof(71), 1.2, tau=0.8)
    n = ns(1.3)
    t = tn(n)
    f = 205 * (1 + 0.01 * np.sin(2 * np.pi * 3 * t))
    buzz = harmonic_tone(f, n, [1 / k for k in range(1, 13)]) * (1 - 0.6 * (0.5 + 0.5 * np.sin(2 * np.pi * 38 * t)))
    buzz = bp(buzz, 300, 2500) * curve(t, [(0, 0), (0.15, 0), (0.4, 1), (0.9, 0.7), (1.3, 0)], "cos")
    out = mix((latch, 0.5), (nz(glass), 0.6, 0.02), (nz(warm), 0.3, 0.02), (nz(buzz), 0.12))
    return reverb(out, "small", 0.15)


@sfx("firefly_buzz_loop", loop=True, bus="Ambience", volume_db=-12.0, peak_db=-6.0)
def firefly_buzz_loop(rng):
    """A few soft wing-buzzes drifting in and out; whole-cycle frequencies
    and periodic modulators make the 2 s loop exactly periodic."""
    L = ns(2.0)
    u = np.arange(L) / L
    out = np.zeros(L)
    for f0 in (196.0, 233.0, 262.0):
        f0 = loop_freq(f0 * rng.uniform(0.98, 1.02), L)
        f = f0 * (1 + 0.01 * np.sin(2 * np.pi * int(rng.integers(2, 5)) * u + rng.uniform(0, 6.28)))
        tone = harmonic_tone(f, L, [1 / k ** 1.2 for k in range(1, 11)])
        wing = 1 - 0.5 * (0.5 + 0.5 * np.cos(2 * np.pi * int(rng.integers(70, 90)) * u))
        swell = np.clip(periodic_lfo(L, rng, 2, 1.0) - 0.4, 0, None)
        out += tone * wing * swell
    out = circ_filter(out, lambda f: gauss_band(f, 900, 1.2))
    air = circ_noise(L, rng, lambda f: gauss_band(f, 3000, 0.6))
    return nz(out) + 0.03 * air


# ---- 4d. Collectibles -------------------------------------------------------------
@sfx_family("coin", 3, volume_db=-5.0, sharp=True)
def coin(rng, idx):
    """Grace note up a fourth into a ringing chime (D6>G6, E6>A6, F#6>B6)."""
    a, b = ((86, 91), (88, 93), (90, 95))[idx]
    n1 = chime(mtof(a), 0.12, tau=0.2)
    n2 = chime(mtof(b), 0.6, tau=0.32)
    out = mix((click(rng, 0.002, 5000, 14000), 0.15), (nz(n1), 0.7), (nz(n2), 1.0, 0.055 * rng.uniform(0.95, 1.05)))
    return reverb(lp(out, 9500), "small", 0.12)


@sfx("gem", volume_db=-4.0)
def gem(rng):
    """Crystalline rising arpeggio with shimmer glints and echo."""
    parts = []
    for k, m in enumerate((91, 95, 98, 103)):                      # G6 B6 D7 G7
        parts.append((nz(chime(mtof(m), 0.8, glass=True, tau=0.35 + 0.05 * k)), 0.8 - 0.1 * k + 0.25 * (k == 3),
                      0.045 * k))
    n = ns(0.8)
    glints = np.zeros(n)
    for _ in range(7):
        f = rng.uniform(5000, 9000)
        place(glints, ns(rng.uniform(0.1, 0.6)), modes(ns(0.15), [f, f * 1.5], [1, 0.3], [0.04, 0.02]),
              rng.uniform(0.2, 0.6))
    out = mix(*parts, (nz(glints), 0.2))
    return fit(reverb(echo(out, 0.11, 0.25, 3, 6000), "hall", 0.15), 1.2, 0.3)


@sfx("treasure_big", volume_db=-2.0)
def treasure_big(rng):
    """Original 5-note fanfare: triplet pickup, accent, held top note."""
    seq = ((0.00, 0.09, 71), (0.09, 0.09, 74), (0.18, 0.1, 79), (0.30, 0.13, 83), (0.45, 0.62, 86))
    lead = mix(*[(brass(m, d, 0.9 if m < 86 else 1.0), 1.0, s) for s, d, m in seq])
    bright = mix(*[(steelpan(m + 12, d, 0.6), 1.0, s) for s, d, m in seq])
    chord = mix(*[(brass(m, 0.62, 0.7, bright=0.6), 0.5, 0.45) for m in (67, 71, 74)])
    out = mix((lead, 0.7), (bright, 0.35), (chord, 0.6), (nz(thump(0.6, 140, 98, 0.03, 0.25)), 0.5, 0.45),
              (perc_cymbal(rng, 0.9), 0.07, 0.45))
    return fit(reverb(out, "hall", 0.14), 1.3, 0.3)


@sfx("chest_open", volume_db=-3.0, sharp=True)
def chest_open(rng):
    lock = mix((nz(modes(ns(0.08), [1900, 3600, 5300], [1, 0.5, 0.3], [0.02, 0.012, 0.008])), 1.0),
               (click(rng, 0.003, 2000, 12000), 0.5))
    lid = creak(0.55, rng, [(0, 30), (0.3, 46), (0.55, 34)],
                [(260, 6, 1.0), (610, 8, 0.7), (1250, 10, 0.4), (2400, 12, 0.2)], [(0, 0), (0.06, 1), (0.4, 0.8), (0.55, 0)])
    knock = nz(modes(ns(0.25), [130, 290, 520], [1, 0.6, 0.3], [0.07, 0.05, 0.03]))
    sparkle = mix(*[(nz(chime(mtof(m), 0.7, tau=0.35)), 0.5 + 0.1 * k, 0.07 * k) for k, m in enumerate((91, 95, 98, 103))])
    out = mix((lock, 0.6), (nz(lid), 0.7, 0.05), (knock, 0.6, 0.6), (sparkle, 0.45, 0.45))
    return fit(reverb(out, "small", 0.15), 1.35, 0.3)


@sfx("sparkle_loop", loop=True, bus="Ambience", volume_db=-14.0, peak_db=-6.0)
def sparkle_loop(rng):
    """Very subtle random glints (wrapped circularly) over faint air."""
    L = ns(2.0)
    buf = np.zeros(L + ns(1.2))
    scale = [mtof(m) for m in (91, 93, 95, 98, 100, 103, 105, 107)]
    for _ in range(10):
        f = scale[int(rng.integers(0, len(scale)))]
        tau = rng.uniform(0.06, 0.2)
        g = modes(ns(tau * 5), [f, f * 2.0, f * 3.01], [1, 0.25, 0.08], [tau, tau * 0.5, tau * 0.3])
        place(buf, ns(rng.uniform(0, 2.0)), g, rng.uniform(0.25, 1.0))
    glints = fold_tail(buf, L)
    air = circ_noise(L, rng, lambda f: gauss_band(f, 9000, 0.4)) * periodic_lfo(L, rng, 3, 0.5)
    return nz(glints) + 0.012 * air


@sfx("heart_pickup", volume_db=-4.0)
def heart_pickup(rng):
    """Warm rising G-major chime."""
    parts = []
    for k, m in enumerate((79, 83, 86, 91)):
        n = ns(0.9 - 0.1 * k)
        tone = harmonic_tone(mtof(m), n, [1, 0.25, 0.08]) * env_perc(n, 0.004, 0.35) * fade_tail(n, 0.05)
        parts.append((tone, 0.7 + 0.1 * k, 0.07 * k))
    return fit(reverb(mix(*parts), "hall", 0.2), 1.1, 0.3)


# ---- 4e. Parrots -------------------------------------------------------------------
def _chirp(dur: float, f_pts, trill: float = 0.0, trill_rate: float = 45.0, index: float = 0.6) -> np.ndarray:
    """Bird syllable: FM tone following a pitch contour, sin^2 window."""
    n = ns(dur)
    t = tn(n)
    f = curve(t, f_pts, "exp")
    if trill:
        f = f * (1 + trill * np.sin(2 * np.pi * trill_rate * t))
    y = fm(f, n, 0.5, index) + 0.2 * np.sin(2 * phase_of(f, n))
    return y * np.sin(np.pi * np.arange(n) / n) ** 2


CHIRPS = (
    [(0.0, 0.075, [(0, 2300), (0.075, 3700)], 0.0)],
    [(0.0, 0.05, [(0, 3400), (0.05, 2500)], 0.0), (0.075, 0.065, [(0, 3000), (0.065, 3900)], 0.0)],
    [(0.0, 0.04, [(0, 2600), (0.04, 3300)], 0.0), (0.055, 0.04, [(0, 2700), (0.04, 3400)], 0.0),
     (0.11, 0.075, [(0, 2800), (0.04, 4100), (0.075, 3600)], 0.0)],
    [(0.0, 0.13, [(0, 2500), (0.13, 3300)], 0.1)],
)


@sfx_family("parrot_chirp", 4, volume_db=-5.0)
def parrot_chirp(rng, idx):
    p = rng.uniform(0.96, 1.04)
    out = mix(*[(_chirp(d, [(tt, f * p) for tt, f in pts], trill=tr), 1.0, s) for s, d, pts, tr in CHIRPS[idx]])
    return reverb(out, "outdoor", 0.08)


@sfx("parrot_squawk", volume_db=-3.0)
def parrot_squawk(rng):
    """Comedic 'RRAWK-awk': rough FM source through beak formants."""
    def syl(dur, pts):
        n = ns(dur)
        t = tn(n)
        f = curve(t, pts, "exp")
        rough = 1 + 0.5 * nz(lp(white(n, rng), 60))
        src = fm(f, n, 1.0, 2.2) * rough + 0.3 * np.sin(phase_of(f * 0.5, n))
        voiced = nz(reson(src, 1300, 4) + 0.7 * reson(src, 2600, 5) + 0.4 * reson(src, 3800, 6))
        breath = 0.12 * nz(bp(white(n, rng), 1800, 4000))
        return (voiced + breath) * curve(t, [(0, 0), (0.015, 1), (dur * 0.7, 0.8), (dur, 0)], "cos")
    a = syl(0.24, [(0, 650), (0.08, 980), (0.24, 760)])
    b = syl(0.11, [(0, 900), (0.11, 700)])
    return reverb(mix((a, 1.0), (b, 0.8, 0.27)), "outdoor", 0.1)


@sfx("cage_break", volume_db=-2.0, sharp=True)
def cage_break(rng):
    crack = mix((click(rng, 0.03, 900, 12000), 1.0),
                (nz(modes(ns(0.15), [320, 710, 1290], [1, 0.6, 0.3], [0.04, 0.025, 0.015])), 0.7))
    snap2 = mix((click(rng, 0.02, 1200, 12000), 0.8), (nz(modes(ns(0.12), [410, 880], [1, 0.5], [0.035, 0.02])), 0.6))
    pings = [(nz(modes(ns(0.6), [f, f * 2.76, f * 5.4], [1, 0.45, 0.2], [0.25, 0.12, 0.06])), 0.35, d)
             for f, d in ((1350, 0.02), (1720, 0.07), (2240, 0.13))]
    n = ns(0.8)
    splinter = grains(n, rng, 3500 * np.exp(-tn(n) / 0.07), lo=1500, hi=8000)
    clatter = np.zeros(n)
    for _ in range(8):
        f = rng.uniform(500, 1400)
        place(clatter, ns(rng.uniform(0.15, 0.7)), modes(ns(0.06), [f, f * 2.3], [1, 0.4], [0.02, 0.01]),
              rng.uniform(0.2, 0.7))
    return mix((crack, 1.0), (snap2, 0.7, 0.05), *pings, (nz(splinter), 0.4), (nz(clatter), 0.35))


@sfx("parrot_rescue", volume_db=-2.0)
def parrot_rescue(rng):
    """1.5 s celebratory jingle + wing flutter + happy chirps."""
    seq = ((0.0, 79), (0.08, 83), (0.16, 86), (0.24, 83), (0.32, 86), (0.40, 91))
    mal = mix(*[(marimba(m, 0.6, 0.9, rng), 1.0, s) for s, m in seq])
    lead = mix(*[(steelpan(m, 0.12, 0.7), 1.0, s) for s, m in seq])
    chord = mix(*[(steelpan(m, 0.9, 0.8), 1.0, 0.52) for m in (83, 86, 91)],
                *[(uke(m, 0.9, 0.8, rng), 0.8, 0.52 + 0.012 * k) for k, m in enumerate((67, 71, 74, 79))])
    n = ns(1.2)
    t = tn(n)
    flutter = bp(white(n, rng), 600, 2500) * (0.3 + 0.7 * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * t))) \
        * curve(t, [(0, 0), (0.1, 1), (0.8, 0.6), (1.2, 0)], "cos")
    chirps = mix((_chirp(0.07, [(0, 2500), (0.07, 3800)]), 1.0), (_chirp(0.09, [(0, 3000), (0.05, 4000), (0.09, 3400)]), 0.9, 0.2))
    out = mix((mal, 0.6), (lead, 0.45), (chord, 0.5), (nz(flutter), 0.2, 0.1), (chirps, 0.25, 0.75))
    return fit(reverb(out, "hall", 0.15), 1.6, 0.35)


# ---- 4f. Enemies -------------------------------------------------------------------
@sfx("crab_step", volume_db=-10.0, peak_db=-3.0, sharp=True)
def crab_step(rng):
    parts = []
    for d, a in ((0.0, 1.0), (0.014, 0.7), (0.027, 0.85), (0.043, 0.6)):
        p = rng.uniform(0.9, 1.15)
        c = mix((nz(modes(ns(0.02), [2400 * p, 3900 * p, 6100 * p], [1, 0.6, 0.3], [0.004, 0.003, 0.002])), 1.0),
                (click(rng, 0.0015, 3000, 12000), 0.4))
        parts.append((c, a, d))
    return mix(*parts)


@sfx("crab_pinch", volume_db=-4.0, sharp=True)
def crab_pinch(rng):
    swish = whoosh(0.06, rng, [(0, 3000), (0.06, 6000)], 0.6, [(0, 0), (0.02, 1), (0.05, 0.4), (0.06, 0)])
    snip = mix((nz(modes(ns(0.1), [3300, 5100, 7900], [1, 0.6, 0.35], [0.012, 0.008, 0.005])), 1.0),
               (click(rng, 0.002, 4000, 14000), 0.6))
    stop = nz(modes(ns(0.06), [2100, 4400], [1, 0.4], [0.01, 0.006]))
    return mix((swish, 0.4), (snip, 1.0, 0.055), (stop, 0.4, 0.07))


@sfx("crab_hit", volume_db=-3.0, sharp=True)
def crab_hit(rng):
    shell = modes(ns(0.25), [610, 1490, 2340, 3700], [1, 0.6, 0.4, 0.2], [0.06, 0.035, 0.022, 0.014])
    n = ns(0.15)
    bonk = np.sin(phase_of(curve(tn(n), [(0, 700), (0.05, 480), (0.15, 470)], "exp"), n)) * env_perc(n, 0.0008, 0.04)
    return mix((nz(shell), 0.8), (nz(bonk), 0.6), (nz(thump(0.1, 160, 90, 0.01, 0.03)), 0.5),
               (click(rng, 0.004, 2000, 10000), 0.5))


@sfx("crab_defeat", volume_db=-3.0)
def crab_defeat(rng):
    """Comedic cork pop, puff, then a spinning whirl flying off + tiny ding."""
    n = ns(0.05)
    pop = np.sin(phase_of(curve(tn(n), [(0, 1400), (0.03, 350), (0.05, 300)], "exp"), n)) * env_perc(n, 0.0005, 0.012)
    puff = whoosh(0.25, rng, [(0, 2500), (0.25, 900)], 1.2, [(0, 0), (0.005, 1), (0.25, 0)])
    m = ns(0.6)
    ts = tn(m)
    spin = harmonic_tone(curve(ts, [(0, 500), (0.6, 1400)], "exp"), m, [1, 0.3]) \
        * (1 - 0.6 * (0.5 + 0.5 * np.cos(phase_of(curve(ts, [(0, 10), (0.6, 24)]), m)))) \
        * curve(ts, [(0, 0), (0.05, 1), (0.4, 0.6), (0.6, 0)], "cos")
    ding = chime(mtof(96), 0.5, tau=0.25)
    return mix((nz(pop), 0.8), (puff, 0.5), (nz(spin), 0.35, 0.06), (nz(ding), 0.2, 0.62))


@sfx("enemy_alert", volume_db=-4.0, sharp=True)
def enemy_alert(rng):
    """Short bright '!' double blip."""
    def blip(dur, f0, f1):
        n = ns(dur)
        t = tn(n)
        f = curve(t, [(0, f0), (dur * 0.4, f1), (dur, f1)], "exp")
        return lp(pulse(f, n, 0.3), 6000) * curve(t, [(0, 0), (0.003, 1), (dur * 0.6, 0.8), (dur, 0)], "cos")
    return mix((blip(0.06, 1050, 1400), 0.8), (blip(0.1, 1400, 1900), 1.0, 0.075))


@sfx("snail_fuse_loop", loop=True, volume_db=-7.0)
def snail_fuse_loop(rng):
    """Sputtering fuse hiss with crackles; built from periodic noise."""
    L = ns(1.5)
    hiss = circ_noise(L, rng, lambda f: hp_gain(f, 3500, 2) * lp_gain(f, 12000, 2))
    sputter = 1 + 0.6 * nz(circ_filter(circ_noise(L, rng), lambda f: gauss_band(f, 12, 1.0)))
    sizzle = circ_noise(L, rng, lambda f: gauss_band(f, 2500, 0.6)) * periodic_lfo(L, rng, 6, 0.5)
    crackle = circ_grains(L, rng, 70, grain_ms=(0.3, 1.2), mag_fn=lambda f: gauss_band(f, 3500, 1.0), amp_pow=2.0)
    return 0.45 * hiss * sputter + 0.2 * sizzle + 2.0 * nz(crackle)


# ---- 4g. World ---------------------------------------------------------------------
def _clatter(rng, n, count, t_range, f_range):
    buf = np.zeros(n)
    for _ in range(count):
        f = rng.uniform(*f_range)
        place(buf, ns(rng.uniform(*t_range)), modes(ns(0.06), [f, f * 2.2], [1, 0.4], [0.02, 0.01]),
              rng.uniform(0.2, 0.8))
    return buf


@sfx("crate_break", volume_db=-2.0, sharp=True)
def crate_break(rng):
    n = ns(0.85)
    t = tn(n)
    planks = np.zeros(n)
    for d in (0.0, 0.012, 0.03, 0.055):
        fr = rng.uniform(200, 320) * np.array([1, 2.1, 3.4, 5.2])
        place(planks, ns(d), modes(ns(0.2), fr, [1, 0.6, 0.35, 0.2], [0.05, 0.03, 0.02, 0.012]), rng.uniform(0.6, 1.0))
    splinter = grains(n, rng, 4000 * np.exp(-t / 0.06), lo=1500, hi=8000)
    clatter = _clatter(rng, n, 7, (0.12, 0.72), (600, 1500))
    return mix((click(rng, 0.03, 800, 12000), 0.8), (nz(planks), 1.0), (nz(splinter), 0.5), (nz(clatter), 0.35),
               (nz(thump(0.15, 130, 70, 0.012, 0.04)), 0.6))


@sfx("barrel_break", volume_db=-2.0, sharp=True)
def barrel_break(rng):
    n = ns(1.1)
    t = tn(n)
    hollow = modes(ns(0.4), [105, 210, 330], [1, 0.6, 0.3], [0.12, 0.08, 0.05])
    staves = np.zeros(n)
    for d in (0.0, 0.015, 0.035):
        fr = rng.uniform(240, 380) * np.array([1, 2.3, 3.7])
        place(staves, ns(d), modes(ns(0.18), fr, [1, 0.5, 0.3], [0.045, 0.03, 0.015]), rng.uniform(0.6, 1.0))
    hoop = nz(modes(ns(0.9), np.array([620, 1480, 2390, 3300]) * rng.uniform(0.97, 1.03), [1, 0.6, 0.4, 0.25],
                    [0.5, 0.35, 0.25, 0.15]))
    splinter = grains(n, rng, 3500 * np.exp(-t / 0.08), lo=1300, hi=7500)
    clatter = _clatter(rng, n, 6, (0.15, 0.9), (500, 1300))
    return mix((click(rng, 0.03, 700, 12000), 0.8), (nz(hollow), 0.9), (nz(staves), 0.8), (hoop, 0.3, 0.02),
               (hoop, 0.15, 0.36), (nz(splinter), 0.45), (nz(clatter), 0.3), (nz(thump(0.2, 120, 60, 0.015, 0.06)), 0.6))


@sfx("switch_click", volume_db=-5.0, sharp=True)
def switch_click(rng):
    c1 = mix((nz(modes(ns(0.04), [1800, 3500, 5200], [1, 0.6, 0.3], [0.008, 0.005, 0.003])), 1.0),
             (click(rng, 0.002, 3000, 12000), 0.5))
    c2 = mix((nz(modes(ns(0.06), [1200, 2600, 4100], [1, 0.5, 0.3], [0.012, 0.007, 0.004])), 1.0),
             (click(rng, 0.002, 2000, 10000), 0.5), (nz(thump(0.05, 200, 120, 0.008, 0.015)), 0.5))
    return mix((c1, 0.7), (c2, 1.0, 0.045))


@sfx("door_open", volume_db=-3.0)
def door_open(rng):
    """Heavy stone/wood door: grinding rumble, low creak, settling thud."""
    dur = 1.15
    n = ns(dur)
    t = tn(n)
    grind = nz(shaped_noise(n, rng, lambda f, tt: gauss_band(f, 220, 1.0) + 0.5 * gauss_band(f, 650, 0.8)))
    grind = grind * (1 + 0.5 * nz(lp(white(n, rng), 18)))
    rumble = nz(lp(colored(n, rng, 2.0), 90))
    grit = nz(grains(n, rng, 600, lo=400, hi=2500))
    cr = creak(1.0, rng, [(0, 22), (0.5, 30), (1.0, 20)], [(180, 5, 1.0), (420, 7, 0.6), (900, 9, 0.3)],
               [(0, 0), (0.1, 1), (0.8, 0.7), (1.0, 0)])
    body = (0.6 * grind + 0.5 * rumble + 0.2 * grit) * curve(t, [(0, 0), (0.08, 1), (0.85, 0.9), (dur, 0)], "cos")
    return mix((body, 1.0), (nz(cr), 0.35, 0.05), (nz(thump(0.2, 90, 55, 0.02, 0.06)), 0.6, 0.98))


@sfx("bell_ring", volume_db=-3.0, sharp=True)
def bell_ring(rng):
    """Ship's bell, classic double strike."""
    def strike():
        return mix((bell(880.0, 3.0), 1.0), (click(rng, 0.004, 2000, 9000), 0.25))
    return fit(mix((strike(), 1.0), (strike(), 0.8, 0.34)), 2.4, 0.6)


@sfx("sail_flap", volume_db=-4.0)
def sail_flap(rng):
    parts = []
    for d, a in ((0.0, 1.0), (0.22, 0.7), (0.4, 0.85), (0.62, 0.5)):
        n = ns(0.25)
        flut = 1 - 0.7 * (0.5 + 0.5 * np.cos(2 * np.pi * rng.uniform(22, 30) * tn(n)))
        body = bp(white(n, rng), 250, 2200) * flut * env_perc(n, 0.003, 0.08)
        parts.append((mix((nz(body), 1.0), (click(rng, 0.004, 1500, 9000), 0.35)), a, d))
    wind = whoosh(0.9, rng, [(0, 500), (0.9, 700)], 1.0, [(0, 0), (0.2, 1), (0.9, 0)])
    return mix(*parts, (wind, 0.2))


@sfx("wood_creak", volume_db=-6.0)
def wood_creak(rng):
    return creak(1.0, rng, [(0, 18), (0.4, 34), (0.75, 26), (1.0, 16)],
                 [(190, 6, 1.0), (430, 8, 0.7), (870, 10, 0.4), (1650, 12, 0.2)],
                 [(0, 0), (0.12, 0.7), (0.5, 1), (1.0, 0)])


GULL_CALLS = (
    [(0.0, 0.28, [(0, 1250), (0.06, 1900), (0.28, 1300)]), (0.36, 0.3, [(0, 1200), (0.07, 1850), (0.3, 1250)])],
    [(0.0, 0.38, [(0, 1400), (0.08, 2000), (0.38, 1500)]), (0.46, 0.09, [(0, 1600), (0.09, 1350)]),
     (0.6, 0.09, [(0, 1550), (0.09, 1300)]), (0.74, 0.1, [(0, 1500), (0.1, 1200)])],
)


@sfx_family("seagull", 2, bus="Ambience", volume_db=-8.0)
def seagull(rng, idx):
    """Distant gull cries: rough FM voice through two formants, outdoor verb."""
    def syl(dur, pts):
        n = ns(dur)
        t = tn(n)
        f = curve(t, pts, "exp")
        src = fm(f, n, 1.0, 1.8) * (1 + 0.35 * nz(lp(white(n, rng), 80)))
        voiced = reson(src, 2200, 3) + 0.6 * reson(src, 3400, 4) + 0.3 * src
        return nz(voiced) * curve(t, [(0, 0), (0.02, 1), (dur * 0.6, 0.85), (dur, 0)], "cos")
    out = mix(*[(syl(d, pts), 1.0 if k == 0 else 0.8, s) for k, (s, d, pts) in enumerate(GULL_CALLS[idx])])
    return reverb(lp(out, 6000), "outdoor", 0.25)


@sfx("ocean_waves_loop", loop=True, bus="Ambience", volume_db=-6.0)
def ocean_waves_loop(rng):
    """Gentle surf: three periodic noise bands driven by wave envelopes
    (swell -> crash -> receding foam) that wrap seamlessly at 6 s."""
    P = 6.0
    L = ns(P)
    t = tn(L)
    low = circ_noise(L, rng, lambda f: lp_gain(f, 350, 2) * hp_gain(f, 30, 2))
    mid = circ_noise(L, rng, lambda f: gauss_band(f, 1100, 1.1))
    fizz = circ_noise(L, rng, lambda f: gauss_band(f, 4500, 0.9))

    def env(rise, fall, delay):
        def shape(d):
            d = d - delay
            return np.where(d < 0, np.exp(-(d / rise) ** 2), np.exp(-np.maximum(d, 0) / fall))
        return sum(s * periodic_events(t, P, [c], shape) for c, s in ((0.4, 1.0), (3.4, 0.8)))
    return (0.6 * low * (0.35 + env(1.1, 1.6, 0.0)) + 0.45 * mid * (0.15 + env(0.4, 1.2, 0.1))
            + 0.25 * fizz * (0.1 + env(0.25, 2.0, 0.35)))


@sfx("wind_loop", loop=True, bus="Ambience", volume_db=-8.0)
def wind_loop(rng):
    """Soft breeze: resonant noise bands fading in and out (gusts)."""
    L = ns(4.0)
    out = np.zeros(L)
    for fc, w in ((320, 0.35), (560, 0.3), (900, 0.3), (1500, 0.4)):
        band = circ_noise(L, rng, lambda f, fc=fc, w=w: gauss_band(f, fc, w))
        out += band * np.clip(periodic_lfo(L, rng, 3, 0.85), 0.05, None)
    broad = circ_noise(L, rng, lambda f: lp_gain(f, 2500, 1) * hp_gain(f, 80, 2))
    return out + 0.5 * broad * periodic_lfo(L, rng, 2, 0.4)


@sfx("boat_splash", volume_db=-3.0, sharp=True)
def boat_splash(rng):
    """Wooden bow slapping into a wave: hull knock, whump, spray, droplets."""
    dur = 1.2
    n = ns(dur)
    t = tn(n)
    hull = modes(ns(0.45), [92, 185, 290, 410], [1, 0.6, 0.35, 0.2], [0.12, 0.08, 0.05, 0.035])
    nw = ns(0.3)
    whump = mix((nz(thump(0.3, 95, 50, 0.03, 0.1)), 1.0), (nz(lp(white(nw, rng), 300) * env_perc(nw, 0.003, 0.07)), 0.6))
    spray = shaped_noise(n, rng, lambda f, tt: gauss_band(f, curve(tt, [(0, 2600), (dur, 1500)], "exp"), 1.6))
    spray = nz(spray) * curve(t, [(0, 0), (0.03, 1), (0.3, 0.5), (dur, 0)], "cos")
    hiss = nz(hp(white(n, rng), 5000)) * curve(t, [(0, 0), (0.04, 1), (0.5, 0.2), (0.9, 0), (dur, 0)], "cos")
    drops = _bubbles(rng, n, 14, (0.2, 1.05), (800, 2600), amp=(0.2, 0.7))
    return mix((nz(hull), 0.6), (whump, 0.8), (spray, 0.8, 0.02), (hiss, 0.25, 0.02), (nz(drops), 0.3))


# ---- 4h. UI ------------------------------------------------------------------------
@sfx("ui_move", bus="UI", volume_db=-8.0, peak_db=-3.0, sharp=True)
def ui_move(rng):
    tick = modes(ns(0.06), [1480, 3150, 4620], [1, 0.35, 0.15], [0.018, 0.008, 0.005])
    return mix((nz(tick), 1.0), (lp(click(rng, 0.002, 1500, 8000), 6000), 0.2))


def _pluck(rng, m, dur, t60, bright):
    y = ks_pluck(mtof(m), dur, rng, t60=t60, bright=bright)
    return nz(y * fade_tail(len(y), 0.05))


@sfx("ui_select", bus="UI", volume_db=-5.0)
def ui_select(rng):
    out = mix((_pluck(rng, 79, 0.5, 0.7, 0.75), 0.8), (_pluck(rng, 86, 0.45, 0.6, 0.7), 0.55, 0.035),
              (nz(chime(mtof(91), 0.3, tau=0.12)), 0.15, 0.035))
    return reverb(out, "small", 0.12)


@sfx("ui_back", bus="UI", volume_db=-5.0)
def ui_back(rng):
    out = mix((_pluck(rng, 74, 0.35, 0.5, 0.5), 0.7), (_pluck(rng, 67, 0.45, 0.6, 0.45), 0.9, 0.06))
    return reverb(out, "small", 0.1)


@sfx("ui_pause", bus="UI", volume_db=-5.0)
def ui_pause(rng):
    out = mix((marimba(86, 0.5, 1.0, rng), 0.9), (marimba(79, 0.7, 1.0, rng), 1.0, 0.11), (vibes(79, 0.8, 0.6), 0.3, 0.11))
    return fit(reverb(out, "small", 0.15), 0.75, 0.3)


@sfx("ui_map", bus="UI", volume_db=-6.0)
def ui_map(rng):
    dur = 0.6
    n = ns(dur)
    t = tn(n)
    crinkle = grains(n, rng, curve(t, [(0, 2200), (0.1, 2500), (0.35, 1500), (dur, 0)]), lo=1500, hi=9000,
                     grain_ms=(0.3, 1.5))
    swish = whoosh(0.5, rng, [(0, 1200), (0.25, 2600), (0.5, 1500)], 1.0, [(0, 0), (0.06, 1), (0.5, 0)])
    nf = ns(0.12)
    settle = lp(white(nf, rng), 1200) * env_perc(nf, 0.004, 0.03)
    return mix((nz(crinkle), 0.6), (swish, 0.5), (nz(settle), 0.4, 0.45))


@sfx("prompt_appear", bus="UI", volume_db=-6.0)
def prompt_appear(rng):
    n = ns(0.16)
    t = tn(n)
    f = curve(t, [(0, 660), (0.06, 990), (0.16, 990)], "exp")
    y = harmonic_tone(f, n, [1, 0, 0.12]) * curve(t, [(0, 0), (0.004, 1), (0.07, 0.6), (0.16, 0)], "cos")
    return reverb(echo(y, 0.07, 0.3, 2), "small", 0.1)


@sfx("checkpoint", bus="UI", volume_db=-3.0)
def checkpoint(rng):
    """Bright 3-note chime D6-G6-B6."""
    notes = ((0.0, 86), (0.1, 91), (0.2, 95))
    bells = [(nz(chime(mtof(m), 1.0 if k < 2 else 1.3, tau=0.4 if k < 2 else 0.7)), 0.8 + 0.1 * k, s)
             for k, (s, m) in enumerate(notes)]
    pans = [(steelpan(m, 0.3, 0.6), 0.4, s) for s, m in notes]
    return fit(reverb(mix(*bells, *pans), "hall", 0.18), 1.4, 0.4)


# =============================================================================
# 5. Music
# =============================================================================
# All cues are in G major (the boss fight in its relative E minor).  Chord
# table: (bass root MIDI, chord pitch classes, ukulele voicing on strings
# 4-3-2-1 of a re-entrant G4-C4-E4-A4 uke).
CHORDS = {
    "G": (43, (7, 11, 2), (67, 62, 67, 71)),
    "C": (48, (0, 4, 7), (67, 60, 64, 72)),
    "D": (50, (2, 6, 9), (69, 62, 66, 69)),
    "D7": (50, (2, 6, 9, 0), (69, 62, 66, 72)),
    "Em": (40, (4, 7, 11), (67, 64, 67, 71)),
    "Am": (45, (9, 0, 4), (69, 60, 64, 69)),
    "Bm": (47, (11, 2, 6), (71, 62, 66, 71)),
    # colours for the cave cue
    "Gmaj7": (43, (7, 11, 2, 6), (66, 62, 67, 71)),
    "A/G": (43, (9, 1, 4, 7), (67, 61, 64, 69)),
    "Em7": (40, (4, 7, 11, 2), (67, 62, 67, 71)),
    "Cmaj7": (48, (0, 4, 7, 11), (67, 60, 64, 71)),
    "Am7": (45, (9, 0, 4, 7), (67, 60, 64, 69)),
    "Dsus": (50, (2, 7, 9), (69, 62, 67, 69)),
    # the boss cue's dominant (E harmonic minor)
    "B7": (47, (11, 3, 6, 9), (69, 63, 66, 71)),
}
SCALE = (0, 2, 4, 6, 7, 9, 11)                      # G major pitch classes
HOOK = "G5:0:2 D5:2:1 G5:3:2 A5:5:1 B5:6:2"         # the main motif


@dataclass
class Song:
    bpm: float
    bars: int

    @property
    def spb(self) -> int:
        """Samples per beat (tempos are chosen so this is an integer)."""
        v = SR * 60.0 / self.bpm
        assert abs(v - round(v)) < 1e-9, "pick a tempo with integer samples/beat"
        return int(round(v))

    @property
    def length(self) -> int:
        return self.bars * 4 * self.spb

    def b2s(self, beat: float) -> int:
        return int(round(beat * self.spb))

    def sec(self, beats: float) -> float:
        return beats * 60.0 / self.bpm


class Mixer:
    """Mono tracks -> constant-power pan -> stereo, plus a shared reverb send.
    For loops, notes may start/ring past the end: render() folds the overhang
    (and the reverb tail) back onto the start, which is exactly what an
    endlessly repeating loop sounds like -> click-free loop point."""

    def __init__(self, n_body: int, loop: bool, tail: float = 6.0):
        self.n = n_body + ns(tail)
        self.loop_len = n_body if loop else None
        self.tracks: dict = {}

    def track(self, name: str, gain: float = 1.0, pan: float = 0.0, send: float = 0.15, fx=None):
        self.tracks[name] = dict(buf=np.zeros(self.n), gain=gain, pan=pan, send=send, fx=fx)

    def add(self, name: str, start: int, sig: np.ndarray, gain: float = 1.0):
        if start < 0:
            start = start + self.loop_len if self.loop_len else 0
        place(self.tracks[name]["buf"], start, sig, gain)

    def render(self, ir: np.ndarray) -> np.ndarray:
        L = np.zeros(self.n)
        R = np.zeros(self.n)
        send = np.zeros(self.n)
        for tr in self.tracks.values():
            x = tr["buf"]
            if tr["fx"] is not None:
                x = tr["fx"](x)[:self.n]
            x = x * tr["gain"]
            th = (np.clip(tr["pan"], -1, 1) + 1.0) * np.pi / 4.0
            L += np.cos(th) * x
            R += np.sin(th) * x
            send += tr["send"] * x
        wet = np.stack([sps.fftconvolve(send, ir[:, c]) for c in range(2)], axis=1)
        out = wet.copy()
        out[:self.n, 0] += L
        out[:self.n, 1] += R
        if self.loop_len:
            out = fold_tail(out, self.loop_len)
            out -= out.mean(axis=0)                 # DC removal after folding = seam-safe
        return out


def hum(rng, ms: float) -> int:
    """Humanising timing offset in samples."""
    return int(rng.uniform(-ms, ms) * SR / 1000.0) if ms > 0 else 0


def bars_to_notes(bars_text, first_bar: int = 0):
    """Per-bar strings 'NOTE:eighth_start:eighth_len ...' -> [(beat, beats, midi)]."""
    out = []
    for i, txt in enumerate(bars_text):
        for tok in (txt or "").split():
            nm, s, d = tok.split(":")
            out.append(((first_bar + i) * 4 + float(s) / 2.0, float(d) / 2.0, note(nm)))
    return out


def diatonic(m: int, steps: int) -> int:
    """Move a G-major note by scale steps (e.g. -2 = a third below)."""
    octave, pc = divmod(m, 12)
    idx = max(i for i, p in enumerate(SCALE) if p <= pc) + steps
    o, i = divmod(idx, len(SCALE))
    return (octave + o) * 12 + SCALE[i]


def harmony_below(chords, beat: float, m: int) -> int:
    """Consonant harmony note: the highest chord tone 3-9 semitones under m
    (falls back to a diatonic third)."""
    sym = chord_at(chords, int(beat // 4), (beat % 4) * 2)
    tones = chord_tones(sym, m - 9, m - 3)
    return max(tones) if tones else diatonic(m, -2)


def chord_at(chords, bar: int, eighth: float) -> str:
    parts = chords[bar].split("|")
    return parts[0] if len(parts) == 1 or eighth < 4 else parts[1]


def chord_tones(sym: str, lo: int, hi: int):
    return [m for m in range(lo, hi + 1) if m % 12 in CHORDS[sym][1]]


def close_voicing(sym: str, lo: int = 55):
    """Each chord pitch class once, stacked upward from `lo`."""
    out = []
    for pc in CHORDS[sym][1]:
        m = lo + ((pc - lo) % 12)
        out.append(m)
    return sorted(out)


def play(mx, track, song, notes, voice, rng, legato: float = 0.92, vel: float = 1.0, jitter: float = 3.0,
         transpose: int = 0, accent: float = 0.88):
    """Render (beat, beats, midi) notes with voice(m, seconds, velocity)."""
    for beat, dur, m in notes:
        v = vel * (1.0 if beat % 1 == 0 else accent) * rng.uniform(0.94, 1.04)
        mx.add(track, song.b2s(beat) + hum(rng, jitter), voice(m + transpose, song.sec(dur) * legato, v))


def bass_line(chords):
    """Bouncy 3-3-2 pizzicato pattern (root, fifth, root)."""
    out = []
    for b, sym in enumerate(chords):
        parts = sym.split("|")
        for h, s in enumerate(parts):
            r = CHORDS[s][0]
            f = r - 5 if r - 5 >= 38 else r + 7
            if len(parts) == 1:
                out += [(b * 4, 1.4, r), (b * 4 + 1.5, 1.4, f), (b * 4 + 3, 0.9, r)]
            else:
                out += [(b * 4 + 2 * h, 1.3, r), (b * 4 + 2 * h + 1.5, 0.45, f)]
    return out


# Calypso "island strum": (eighth, direction, velocity)
STRUM = ((0, "D", 1.0), (2, "D", 0.7), (3, "U", 0.55), (5, "U", 0.6), (6, "D", 0.8), (7, "U", 0.5))


def strums(mx, track, song, chords, rng, bars=None, vel=1.0, pattern=STRUM, spread=0.011):
    """Ukulele strums; each string is damped when the next strum arrives.
    vel may be a number or a function of the bar index."""
    bars = range(song.bars) if bars is None else bars
    vf = vel if callable(vel) else (lambda b: vel)
    ev = [(b * 4 + e / 2.0, chord_at(chords, b, e), d, v * vf(b)) for b in bars for e, d, v in pattern]
    if not ev:
        return
    ends = [e[0] for e in ev[1:]] + [ev[-1][0] + 1.0 if not mx.loop_len else song.bars * 4 + ev[0][0]]
    for (beat, sym, d, v), nxt in zip(ev, ends):
        voicing = CHORDS[sym][2]
        order = voicing if d == "D" else voicing[::-1][:3]
        for k, m in enumerate(order):
            off = k * spread * (0.8 if d == "U" else 1.0)
            dur = max(0.06, song.sec(nxt - beat) - off + 0.02)
            sig = uke(m, dur, v * rng.uniform(0.88, 1.05) * (0.85 if d == "U" else 1.0), rng)
            mx.add(track, song.b2s(beat) + ns(off) + hum(rng, 2.5), sig)


ARP = (0, 2, 3, 2, 4, 3, 2, 3)


def arpeggio(chords, bars, lo=55, hi=76, pattern=ARP, step=0.5):
    out = []
    for b in bars:
        for e, idx in enumerate(pattern):
            tones = chord_tones(chord_at(chords, b, e * step * 2), lo, hi)
            out.append((b * 4 + e * step, step, tones[min(idx, len(tones) - 1)]))
    return out


class Kit:
    """Pre-rendered percussion variations, picked at random per hit."""

    def __init__(self, rng):
        self.rng = rng
        r = rng
        self.s = {
            "kick": [perc_kick(r, 1.0, 0.8) for _ in range(2)],
            "kick_hard": [perc_kick(r, 1.0, 1.3) for _ in range(2)],
            "shaker": [perc_shaker(r) for _ in range(6)],
            "block": [perc_woodblock(r, 1.0) for _ in range(2)],
            "block_hi": [perc_woodblock(r, 1.33) for _ in range(2)],
            "conga_open": [perc_conga(r, "open", 1.0) for _ in range(2)],
            "conga_open_hi": [perc_conga(r, "open", 1.33) for _ in range(2)],
            "conga_slap": [perc_conga(r, "slap", 1.33) for _ in range(2)],
            "conga_mute": [perc_conga(r, "mute", 1.0) for _ in range(2)],
            "clave": [perc_clave(r) for _ in range(2)],
            "clap": [perc_clap(r) for _ in range(3)],
            "tamb": [perc_tambourine(r) for _ in range(4)],
            "tom_lo": [perc_tom(r, 98.0)],
            "tom_mid": [perc_tom(r, 131.0)],
            "tom_hi": [perc_tom(r, 165.0)],
            "crash": [perc_cymbal(r, 1.8)],
            "swell": [perc_cymbal(r, 1.2, swell=True)],
            "drip": [bubble(f, 0.08, 1.3, tau=0.02) for f in (900, 1150, 1350, 1600)],
        }

    def hit(self, mx, track, song, beat, name, vel=1.0, jitter=1.5):
        bank = self.s[name]
        mx.add(track, song.b2s(beat) + hum(self.rng, jitter), bank[int(self.rng.integers(len(bank)))], vel)


# ---- castaway_explore / castaway_combat_layer ------------------------------------
EXPLORE_SONG = Song(108, 32)                  # 24500 samples/beat -> 71.11 s
EXPLORE_CHORDS = ("G C D7 G G C Am|D7 G "     # A1
                  "G C D7 G G C Am|D7 G "     # A2
                  "C D Bm Em C D G D7 "       # B
                  "G C D7 G G C Am|D7 G|D7").split()   # A3 (+ turnaround)
_A2 = "A5:0:1 G5:1:1 E5:2:1 G5:3:3"
_A3 = "F#5:0:2 E5:2:1 D5:3:2 C5:5:1 A4:6:2"
_A4 = "B4:0:2 G4:2:4 D5:7:1"
_A6 = "C6:0:1 B5:1:1 A5:2:1 G5:3:2 E5:5:1 G5:6:2"
_A7 = "A5:0:2 F#5:2:1 D5:3:2 E5:5:1 F#5:6:2"
_A14 = "E6:0:1 D6:1:1 C6:2:1 B5:3:2 A5:5:1 G5:6:2"
EXPLORE_LEAD = [
    HOOK, _A2, _A3, _A4, HOOK, _A6, _A7, "G5:0:4 D5:5:1 E5:6:1 F#5:7:1",                    # A1
    HOOK, "A5:0:1 G5:1:1 E5:2:1 G5:3:2 C6:5:1 B5:6:1 A5:7:1", "F#5:0:2 E5:2:1 D5:3:2 C5:5:1 A4:6:1 C5:7:1",
    _A4, HOOK, _A14, "A5:0:2 C6:2:1 B5:3:1 A5:4:1 F#5:5:1 D5:6:2", "G5:0:3 B4:3:1 G4:4:2",   # A2
    "", "", "", "G5:4:1 F#5:5:1 E5:6:1 D5:7:1", "", "", "", "D5:5:1 E5:6:1 F#5:7:1",          # B (answers)
    HOOK, _A2, _A3, _A4, HOOK, _A14, _A7, "G5:0:2 D5:2:1 B4:3:1 G4:4:1 D5:5:1 E5:6:1 F#5:7:1",  # A3
]
EXPLORE_PAN_B = [
    "G5:0:1 G5:1:1 E5:2:1 G5:3:2 C6:5:3", "A5:0:1 A5:1:1 F#5:2:1 A5:3:2 D6:5:3",
    "B5:0:2 A5:2:1 F#5:3:2 D5:5:1 F#5:6:2", "E5:0:4",
    "G5:0:1 G5:1:1 E5:2:1 G5:3:2 C6:5:1 B5:6:1 A5:7:1", "F#5:0:2 A5:2:1 D6:3:2 C6:5:1 B5:6:1 A5:7:1",
    "G5:0:2 B5:2:1 D6:3:3 B5:6:2", "A5:0:2 F#5:2:1 D5:3:2",
]
SHAKER_16 = (0.55, 0.3, 0.9, 0.35)


def _section(b: int) -> str:
    return ("A1", "A2", "B", "A3")[b // 8]


def compose_explore(song: Song, rng) -> Mixer:
    ch = EXPLORE_CHORDS
    mx = Mixer(song.length, loop=True)
    mx.track("lead", 0.55, 0.12, 0.2)
    mx.track("pan", 0.45, -0.28, 0.25)
    mx.track("uke", 0.5, -0.4, 0.15, fx=uke_body)
    mx.track("bass", 0.42, 0.0, 0.04)
    mx.track("marimba", 0.16, 0.45, 0.2)
    mx.track("chords", 0.22, 0.3, 0.3)
    mx.track("kick", 0.5, 0.0, 0.02)
    mx.track("shaker", 0.2, 0.55, 0.1)
    mx.track("block", 0.35, -0.55, 0.15)
    mx.track("conga", 0.3, -0.2, 0.12)
    mx.track("clave", 0.3, 0.35, 0.18)
    acc = lambda m, d, v: accordion(m, d, v, rng)  # noqa: E731
    play(mx, "lead", song, bars_to_notes(EXPLORE_LEAD), acc, rng)
    pan_b = bars_to_notes(EXPLORE_PAN_B, 16)
    play(mx, "pan", song, pan_b, steelpan, rng, legato=1.0)
    a3 = [n for n in bars_to_notes(EXPLORE_LEAD) if n[0] >= 24 * 4]
    play(mx, "pan", song, [(b, d, harmony_below(ch, b, m)) for b, d, m in a3], steelpan, rng, vel=0.55)
    for b in range(16, 24):                                    # bellows chords under the B tune
        for m in close_voicing(ch[b].split("|")[0], 60):
            mx.add("chords", song.b2s(b * 4) + hum(rng, 4), accordion(m, song.sec(3.85), 0.6, rng, vib=0.3, bright=0.7))
    strums(mx, "uke", song, ch, rng, vel=lambda b: {"A1": 0.8, "A2": 0.9, "B": 0.9, "A3": 1.0}[_section(b)])
    play(mx, "bass", song, bass_line(ch), lambda m, d, v: pizz_bass(m, d, v, rng), rng, legato=1.0, jitter=1.5)
    arp = arpeggio(ch, list(range(8, 16)) + list(range(24, 32)))
    play(mx, "marimba", song, arp, lambda m, d, v: marimba(m, 0.8, v, rng), rng, vel=0.7, accent=0.8)
    kit = Kit(rng)
    for b in range(song.bars):
        o, sec = b * 4, _section(b)
        kit.hit(mx, "kick", song, o, "kick", 0.9, jitter=0)
        kit.hit(mx, "kick", song, o + 2, "kick", 0.7, jitter=0)
        if sec in ("B", "A3"):
            kit.hit(mx, "kick", song, o + 1.5, "kick", 0.45)
        if sec == "A1":
            for e in range(8):
                kit.hit(mx, "shaker", song, o + e / 2, "shaker", 0.6 if e % 2 else 0.35)
        else:
            for s in range(16):
                kit.hit(mx, "shaker", song, o + s / 4, "shaker", SHAKER_16[s % 4])
        if sec in ("A1", "A3"):
            kit.hit(mx, "block", song, o + 1.5, "block", 0.5)
            kit.hit(mx, "block", song, o + 3, "block_hi", 0.4)
        fill = b % 8 == 7
        if sec != "A1":
            for s, name, v in ((4, "conga_slap", 0.55), (6, "conga_mute", 0.3), (10, "conga_mute", 0.3),
                               (12, "conga_open", 0.75), (14, "conga_open_hi", 0.65)):
                if not (fill and s >= 12):
                    kit.hit(mx, "conga", song, o + s / 4, name, v)
        if sec == "B":
            for p in ((0, 6, 12) if b % 2 == 0 else (4, 8)):          # 3-2 son clave
                kit.hit(mx, "clave", song, o + p / 4, "clave", 0.6)
        if fill:
            for k, s in enumerate((12, 13, 14, 15)):
                kit.hit(mx, "conga", song, o + s / 4, "conga_open_hi" if k % 2 == 0 else "conga_open", 0.5 + 0.12 * k)
    return mx


def compose_combat(song: Song, rng) -> Mixer:
    """Percussion + driving-bass layer, sample-locked to castaway_explore."""
    ch = EXPLORE_CHORDS
    mx = Mixer(song.length, loop=True)
    mx.track("kick", 0.42, 0.0, 0.02)
    mx.track("clap", 0.8, 0.1, 0.15)
    mx.track("toms", 0.42, -0.15, 0.12)
    mx.track("tamb", 0.26, 0.5, 0.1)
    mx.track("crash", 0.24, -0.4, 0.2)
    mx.track("bass", 0.25, 0.0, 0.03)
    kit = Kit(rng)
    for b in range(song.bars):
        o = b * 4
        fill = b % 8 == 7
        for q in range(4):
            kit.hit(mx, "kick", song, o + q, "kick_hard", 0.95 if q % 2 == 0 else 0.8, jitter=0)
        if b % 2 == 1 and not fill:
            kit.hit(mx, "kick", song, o + 3.75, "kick_hard", 0.5, jitter=0)
        for q in (1, 3):
            kit.hit(mx, "clap", song, o + q, "clap", 0.8)
        for s, name, v in ((0, "tom_lo", 0.8), (3, "tom_mid", 0.55), (6, "tom_lo", 0.7), (10, "tom_mid", 0.6),
                           (12, "tom_lo", 0.75), (14, "tom_hi", 0.55)):
            if not (fill and s >= 12):
                kit.hit(mx, "toms", song, o + s / 4, name, v)
        for s in range(16):
            kit.hit(mx, "tamb", song, o + s / 4, "tamb", 0.7 if s % 4 == 2 else 0.35)
        if b % 8 == 0:
            kit.hit(mx, "crash", song, o, "crash", 0.7, jitter=0)
        if fill:
            for k, (s, name) in enumerate(((12, "tom_hi"), (13, "tom_hi"), (14, "tom_mid"), (15, "tom_lo"))):
                kit.hit(mx, "toms", song, o + s / 4, name, 0.6 + 0.1 * k)
            kit.hit(mx, "crash", song, o + 2.8, "swell", 0.5, jitter=0)
        for e in range(8):                                   # octave-pumping drive bass
            r = CHORDS[chord_at(ch, b, e)][0]
            m = (r, r + 12, r, r + 12, r, r + 12, r + 7, r + 12)[e]
            mx.add("bass", song.b2s(o + e / 2), drive_bass(m, song.sec(0.5) * 0.72, 1.0 if e % 2 == 0 else 0.75))
    return mx


# ---- cave_explore -------------------------------------------------------------------
CAVE_SONG = Song(84, 16)                      # 31500 samples/beat -> 45.71 s
CAVE_CHORDS = ("Gmaj7 A/G Gmaj7 A/G Em7 Cmaj7 Am7 Dsus|D "
               "Gmaj7 A/G Gmaj7 A/G Em7 Cmaj7 Am7 D7").split()
CAVE_MEL = [
    HOOK, "C#6:0:2 B5:2:1 A5:3:5", HOOK, "E6:0:2 C#6:2:1 A5:3:5",
    "B5:0:3 G5:3:2 E5:5:3", "E5:0:2 G5:2:1 B5:3:5", "C6:0:2 B5:2:1 A5:3:2 G5:5:1 E5:6:2",
    "G5:0:3 F#5:3:3 D5:6:1 E5:7:1",
    HOOK, "C#6:0:2 D6:2:1 C#6:3:2 A5:5:3", "B5:0:2 G5:2:1 D6:3:2 B5:5:1 G5:6:2", "E6:0:2 F#6:2:1 E6:3:2 C#6:5:3",
    "B5:0:3 G5:3:2 E5:5:3", "E5:0:2 G5:2:1 B5:3:5", "C6:0:2 B5:2:1 A5:3:2 G5:5:1 E5:6:2", "A5:0:4 F#5:4:2 D5:6:2",
]


def compose_cave(song: Song, rng) -> Mixer:
    """Sparse, lydian-tinted take on the hook: vibes with echo, soft pads,
    a gentle bass, harp arpeggios and cave drips in the second half."""
    ch = CAVE_CHORDS
    mx = Mixer(song.length, loop=True, tail=8.0)
    mx.track("vibes", 0.5, 0.15, 0.35, fx=lambda x: echo(x, song.sec(0.75), 0.32, 4, 2800))
    mx.track("padL", 0.3, -0.7, 0.4)
    mx.track("padR", 0.3, 0.7, 0.4)
    mx.track("bass", 0.55, 0.0, 0.1)
    mx.track("harp", 0.6, -0.35, 0.35)
    mx.track("drip", 0.32, 0.4, 0.5, fx=lambda x: echo(x, song.sec(0.5), 0.4, 3, 2500))
    mx.track("perc", 0.25, 0.5, 0.25)
    play(mx, "vibes", song, bars_to_notes(CAVE_MEL), lambda m, d, v: vibes(m, max(d + 0.8, 1.6), v), rng,
         legato=1.0, vel=0.8, jitter=4)
    for b in range(song.bars):
        for m in close_voicing(ch[b].split("|")[0], 55):
            for side in ("padL", "padR"):
                mx.add(side, song.b2s(b * 4) + hum(rng, 6), pad_voice(m, song.sec(4.0), rng, 0.8))
        for half in (0, 1):
            r = CHORDS[chord_at(ch, b, half * 4)][0]
            m = r if half == 0 else (r + 7 if r < 45 else r - 5)
            mx.add("bass", song.b2s(b * 4 + half * 2), pizz_bass(m, song.sec(1.9), 0.75 - 0.15 * half, rng))
    arp = arpeggio(ch, range(8, 16), lo=62, hi=86, pattern=(0, 1, 2, 3, 4, 3, 2, 1))
    play(mx, "harp", song, arp, lambda m, d, v: uke(m, 0.7, v, rng), rng, vel=0.6, accent=0.75)
    kit = Kit(rng)
    for b in range(song.bars):
        for _ in range(1 + (b >= 8)):
            kit.hit(mx, "drip", song, b * 4 + int(rng.integers(0, 16)) / 4.0, "drip", rng.uniform(0.4, 1.0), jitter=0)
        if b >= 8:
            for e in (1, 3, 5, 7):
                kit.hit(mx, "perc", song, b * 4 + e / 2, "shaker", 0.5)
            if b % 2 == 1:
                kit.hit(mx, "perc", song, b * 4 + 3.5, "block_hi", 0.6)
    return mx


# ---- title_theme ----------------------------------------------------------------------
TITLE_SONG = Song(112, 12)                    # 23625 samples/beat -> 25.71 s
TITLE_CHORDS = "G C D7 G G C Am|D7 G C D G|Em D7".split()
TITLE_LEAD = [
    HOOK, "A5:0:1 G5:1:1 E5:2:1 G5:3:2 C6:5:1 B5:6:1 A5:7:1", "F#5:0:2 E5:2:1 D5:3:2 C5:5:1 A4:6:1 C5:7:1",
    _A4, HOOK, _A14, "A5:0:2 C6:2:1 B5:3:1 A5:4:1 F#5:5:1 D5:6:2", "G5:0:4 D5:5:1 E5:6:1 F#5:7:1",
    "G5:0:1 G5:1:1 E5:2:1 G5:3:2 C6:5:3", "A5:0:1 A5:1:1 F#5:2:1 A5:3:2 D6:5:3",
    "B5:0:2 G5:2:1 D6:3:2 B5:5:1 G5:6:2", "A5:0:2 F#5:2:1 D5:3:2 D5:5:1 E5:6:1 F#5:7:1",
]


def compose_title(song: Song, rng) -> Mixer:
    """Rousing full-band statement of the theme; loops seamlessly."""
    ch = TITLE_CHORDS
    mx = Mixer(song.length, loop=True)
    for name, g, p, s in (("lead", 0.58, 0.1, 0.2), ("pan", 0.42, -0.3, 0.25), ("brass", 0.3, 0.35, 0.25),
                          ("uke", 0.5, -0.45, 0.15), ("bass", 0.42, 0.0, 0.04), ("marimba", 0.14, 0.5, 0.2),
                          ("kick", 0.55, 0.0, 0.02), ("conga", 0.3, -0.2, 0.12), ("shaker", 0.2, 0.55, 0.1),
                          ("tamb", 0.28, 0.4, 0.1), ("crash", 0.24, -0.4, 0.25)):
        mx.track(name, g, p, s, fx=uke_body if name == "uke" else None)
    lead = bars_to_notes(TITLE_LEAD)
    play(mx, "lead", song, lead, lambda m, d, v: accordion(m, d, v, rng), rng)
    pan_part = [(b, d, harmony_below(ch, b, m) if b < 32 else m) for b, d, m in lead]  # harmony, then unison
    play(mx, "pan", song, pan_part, steelpan, rng, legato=1.0, vel=0.62)
    for b in range(song.bars):
        for e in (0, 3):
            for m in close_voicing(chord_at(ch, b, e), 55):
                mx.add("brass", song.b2s(b * 4 + e / 2) + hum(rng, 3), brass(m, song.sec(0.35), 0.75))
    strums(mx, "uke", song, ch, rng, vel=1.0)
    play(mx, "bass", song, bass_line(ch), lambda m, d, v: pizz_bass(m, d, v, rng), rng, legato=1.0, jitter=1.5)
    play(mx, "marimba", song, arpeggio(ch, range(song.bars)), lambda m, d, v: marimba(m, 0.8, v, rng), rng,
         vel=0.6, accent=0.8)
    kit = Kit(rng)
    for b in range(song.bars):
        o = b * 4
        for q in range(4):
            kit.hit(mx, "kick", song, o + q, "kick", 0.85 if q % 2 == 0 else 0.6, jitter=0)
        for s, name, v in ((4, "conga_slap", 0.55), (6, "conga_mute", 0.3), (10, "conga_mute", 0.3),
                           (12, "conga_open", 0.75), (14, "conga_open_hi", 0.65)):
            kit.hit(mx, "conga", song, o + s / 4, name, v)
        for s in range(16):
            kit.hit(mx, "shaker", song, o + s / 4, "shaker", SHAKER_16[s % 4])
        for e in (1, 3, 5, 7):
            kit.hit(mx, "tamb", song, o + e / 2, "tamb", 0.6)
        if b in (0, 8):
            kit.hit(mx, "crash", song, o, "crash", 0.8, jitter=0)
        if b in (7, 11):
            kit.hit(mx, "crash", song, o + 2.8, "swell", 0.6, jitter=0)
    return mx


# ---- boss_claw ------------------------------------------------------------------------
BOSS_SONG = Song(126, 24)                     # 21000 samples/beat -> 45.71 s
BOSS_CHORDS = ("Em Em C D Em Em C|D B7 "      # A: the hook, in E minor
               "Em Em C D Em Em C|D B7 "      # A2: same tune, full band
               "C C D D Am Am B7 B7").split()  # B: the claw riff, half time
HOOK_MINOR = "E5:0:2 B4:2:1 E5:3:2 F#5:5:1 G5:6:2"   # the hook, a diatonic third down
BOSS_LEAD = [
    HOOK_MINOR, "F#5:0:1 E5:1:1 D#5:2:1 E5:3:5", "E5:0:2 C5:2:1 E5:3:2 F#5:5:1 G5:6:2",
    "A5:0:2 F#5:2:1 D5:3:2 E5:5:1 F#5:6:2", "G5:0:2 E5:2:1 G5:3:2 A5:5:1 B5:6:2",
    "C6:0:1 B5:1:1 A5:2:1 G5:3:2 F#5:5:1 E5:6:2", "E5:0:2 G5:2:1 F#5:3:1 E5:4:2 D5:6:2",
    "D#5:0:2 F#5:2:1 A5:3:2 B5:5:3",
]
BOSS_RIFF = [                                 # B: low brass, answered by claw clacks
    "C4:0:3 B3:3:1 C4:4:2 E4:6:2", "G4:0:6 F#4:6:1 E4:7:1",
    "D4:0:3 C#4:3:1 D4:4:2 F#4:6:2", "A4:0:6 G4:6:1 F#4:7:1",
    "E4:0:3 D4:3:1 C4:4:2 A3:6:2", "C4:0:2 E4:2:2 A4:4:4",
    "B4:0:2 A4:2:1 G4:3:2 F#4:5:1 D#4:6:2", "F#4:0:1 G4:1:1 F#4:2:1 D#4:3:1 B3:4:4",
]
BOSS_ARP = (0, 2, 1, 2, 0, 2, 1, 3, 0, 2, 1, 2, 3, 2, 1, 2)    # 16th marimba motor


def _boss_section(b: int) -> str:
    return ("A", "A2", "B")[b // 8]


def compose_boss(song: Song, rng) -> Mixer:
    """King Claw's fight: the hook turned minor over a galloping drive bass,
    tresillo brass stabs and a tom groove; a half-time B section where low
    brass plays the claw riff under pads, tolling bells and clacking claves."""
    ch = BOSS_CHORDS
    mx = Mixer(song.length, loop=True)
    for name, g, p, s in (("lead", 0.5, 0.1, 0.2), ("pan", 0.3, -0.3, 0.25), ("stabs", 0.3, 0.3, 0.2),
                          ("riff", 0.4, -0.1, 0.18), ("padL", 0.2, -0.7, 0.35), ("padR", 0.2, 0.7, 0.35),
                          ("bass", 0.32, 0.0, 0.03), ("marimba", 0.14, 0.5, 0.2), ("kick", 0.5, 0.0, 0.02),
                          ("clap", 0.9, 0.1, 0.15), ("toms", 0.42, -0.15, 0.12), ("tamb", 0.22, 0.5, 0.1),
                          ("conga", 0.28, -0.25, 0.12), ("shaker", 0.18, 0.55, 0.1), ("clave", 0.32, 0.4, 0.2),
                          ("crash", 0.24, -0.4, 0.25), ("bell", 0.3, 0.2, 0.4)):
        mx.track(name, g, p, s)
    acc = lambda m, d, v: accordion(m, d, v, rng, vib=0.6, bright=1.1)  # noqa: E731
    lead = bars_to_notes(BOSS_LEAD) + bars_to_notes(BOSS_LEAD, 8)
    play(mx, "lead", song, lead, acc, rng, vel=0.95)
    play(mx, "pan", song, [(b, d, harmony_below(ch, b, m)) for b, d, m in lead if b >= 32], steelpan, rng,
         legato=1.0, vel=0.5)
    riff = bars_to_notes(BOSS_RIFF, 16)
    play(mx, "riff", song, riff, lambda m, d, v: brass(m, d, v, bright=0.8), rng, legato=0.95)
    play(mx, "lead", song, riff, acc, rng, vel=0.4, transpose=12)
    play(mx, "marimba", song, arpeggio(ch, range(8, 16), lo=64, hi=88, pattern=BOSS_ARP, step=0.25),
         lambda m, d, v: marimba(m, 0.5, v, rng), rng, vel=0.6, accent=0.8)
    for b in range(song.bars):
        o, sec = b * 4, _boss_section(b)
        if sec == "B":
            if b % 2 == 0:                                   # pads hold each two-bar chord
                for m in close_voicing(ch[b], 55):
                    for side in ("padL", "padR"):
                        mx.add(side, song.b2s(o) + hum(rng, 6), pad_voice(m, song.sec(8.0), rng, 0.9, cutoff=1600))
            for q in range(4):                               # half-time bass: root + ghost octave
                r = CHORDS[ch[b]][0]
                mx.add("bass", song.b2s(o + q), drive_bass(r, song.sec(0.9), 1.0 if q % 2 == 0 else 0.8))
                mx.add("bass", song.b2s(o + q + 0.5), drive_bass(r + 12, song.sec(0.4), 0.45))
        else:
            for e in (0, 3, 6):                              # 3-3-2 brass stabs
                for m in close_voicing(chord_at(ch, b, e), 55):
                    mx.add("stabs", song.b2s(o + e / 2) + hum(rng, 3),
                           brass(m, song.sec(0.3), 0.8 if sec == "A2" else 0.65))
            for q in range(4):                               # galloping drive bass
                r = CHORDS[chord_at(ch, b, q * 2)][0]
                for off, octave, ln, v in ((0.0, 0, 0.42, 1.0), (0.5, 0, 0.2, 0.7), (0.75, 12, 0.2, 0.8)):
                    mx.add("bass", song.b2s(o + q + off), drive_bass(r + octave, song.sec(ln), v))
    for b in (16, 20):
        mx.add("bell", song.b2s(b * 4), bell(mtof(64), 3.0, 0.8))
    kit = Kit(rng)
    for b in range(song.bars):
        o, sec = b * 4, _boss_section(b)
        fill = b % 8 == 7
        if sec == "B":
            kit.hit(mx, "kick", song, o, "kick_hard", 1.0, jitter=0)
            kit.hit(mx, "kick", song, o + 2.5, "kick_hard", 0.75, jitter=0)
            kit.hit(mx, "clap", song, o + 2, "clap", 0.95)
            for s, name, v in ((0, "tom_lo", 0.9), (6, "tom_lo", 0.6), (8, "tom_mid", 0.5), (10, "tom_lo", 0.7)):
                kit.hit(mx, "toms", song, o + s / 4, name, v)
            for e in range(8):
                kit.hit(mx, "tamb", song, o + e / 2, "tamb", 0.55 if e % 2 else 0.3)
            for p in (1.5, 3.5):                             # claw clacks
                kit.hit(mx, "clave", song, o + p, "clave", 0.7)
                kit.hit(mx, "clave", song, o + p + 0.25, "block_hi", 0.45)
        else:
            for q in range(4):
                kit.hit(mx, "kick", song, o + q, "kick_hard", 0.95 if q % 2 == 0 else 0.75, jitter=0)
            for q in (1, 3):
                kit.hit(mx, "clap", song, o + q, "clap", 0.75)
            for s, name, v in ((0, "tom_lo", 0.7), (3, "tom_mid", 0.5), (6, "tom_lo", 0.6), (10, "tom_mid", 0.5),
                               (12, "tom_lo", 0.65), (14, "tom_hi", 0.5)):
                if not (fill and s >= 12):
                    kit.hit(mx, "toms", song, o + s / 4, name, v)
            for e in range(8):
                kit.hit(mx, "tamb", song, o + e / 2, "tamb", 0.6 if e % 2 else 0.35)
            if sec == "A2":
                for s, name, v in ((4, "conga_slap", 0.55), (6, "conga_mute", 0.3), (10, "conga_mute", 0.3),
                                   (12, "conga_open", 0.7), (14, "conga_open_hi", 0.6)):
                    if not (fill and s >= 12):
                        kit.hit(mx, "conga", song, o + s / 4, name, v)
                for s in range(16):
                    kit.hit(mx, "shaker", song, o + s / 4, "shaker", SHAKER_16[s % 4])
        if b % 8 == 0:
            kit.hit(mx, "crash", song, o, "crash", 0.8, jitter=0)
        if fill:
            for k, (s, name) in enumerate(((12, "tom_hi"), (13, "tom_hi"), (14, "tom_mid"), (15, "tom_lo"))):
                kit.hit(mx, "toms", song, o + s / 4, name, 0.65 + 0.1 * k)
            kit.hit(mx, "crash", song, o + 2.8, "swell", 0.55, jitter=0)
    return mx


# ---- stingers (one-shots) ---------------------------------------------------------------
def _strum_now(mx, track, t, sym, rng, vel=1.0, ring=1.5):
    for k, m in enumerate(CHORDS[sym][2]):
        mx.add(track, ns(t + 0.012 * k), uke(m, ring, vel, rng))


def _stinger_mixer(dur):
    mx = Mixer(ns(dur), loop=False, tail=2.5)
    for name, g, p, s in (("lead", 0.6, 0.1, 0.25), ("pan", 0.45, -0.3, 0.25), ("uke", 0.45, -0.4, 0.2),
                          ("bass", 0.7, 0.0, 0.05), ("brass", 0.45, 0.3, 0.25), ("perc", 0.4, 0.0, 0.2),
                          ("fx", 0.3, 0.35, 0.35)):
        mx.track(name, g, p, s, fx=uke_body if name == "uke" else None)
    return mx


def compose_stinger_discovery(rng) -> Mixer:
    """Harp-like sweep up, the hook in miniature, a big G-major landing."""
    mx = _stinger_mixer(3.0)
    for k, m in enumerate((55, 59, 62, 67, 71, 74, 79, 83)):
        mx.add("uke", ns(0.045 * k), uke(m, 1.6, 0.7 + 0.03 * k, rng))
    mx.add("fx", 0, perc_cymbal(rng, 0.55, swell=True), 0.8)
    motif = ((0.50, 0.24, 79), (0.74, 0.12, 74), (0.86, 0.24, 79), (1.10, 0.12, 81), (1.22, 0.24, 83), (1.46, 1.15, 86))
    for t, d, m in motif:
        mx.add("lead", ns(t), accordion(m, d, 1.0, rng))
        mx.add("pan", ns(t), steelpan(m, d, 0.6))
    land = 1.46
    _strum_now(mx, "uke", land, "G", rng, 1.0, 1.4)
    mx.add("bass", ns(land), pizz_bass(43, 1.4, 1.0, rng))
    for m in (67, 71, 74):
        mx.add("brass", ns(land), brass(m, 1.15, 0.6, bright=0.6), 0.6)
    for m in (79, 83):
        mx.add("pan", ns(land), steelpan(m, 1.2, 0.5))
    mx.add("perc", ns(land), perc_cymbal(rng, 1.6), 0.35)
    mx.add("perc", ns(land), thump(0.8, 140, 98, 0.03, 0.3), 0.6)
    return mx


def compose_stinger_parrot(rng) -> Mixer:
    """Marimba run, steel-pan trill, happy landing chord + bird whistle."""
    mx = _stinger_mixer(2.0)
    for t, m in ((0.0, 74), (0.07, 79), (0.14, 83), (0.21, 86)):
        mx.add("fx", ns(t), marimba(m, 0.6, 0.9, rng), 2.0)
    for k, m in enumerate((91, 93, 91, 93, 91)):
        mx.add("pan", ns(0.30 + 0.05 * k), steelpan(m, 0.08, 0.7))
    land = 0.58
    for m in (83, 86, 91):
        mx.add("pan", ns(land), steelpan(m, 1.0, 0.7))
    _strum_now(mx, "uke", land, "G", rng, 0.9, 1.0)
    mx.add("bass", ns(land), pizz_bass(43, 0.9, 0.9, rng))
    for t in (land, land + 0.08):
        mx.add("perc", ns(t), perc_shaker(rng, 0.7))
    mx.add("fx", ns(0.72), _chirp(0.08, [(0, 2600), (0.08, 3900)]), 0.5)
    mx.add("fx", ns(0.9), _chirp(0.1, [(0, 3000), (0.05, 4100), (0.1, 3500)]), 0.45)
    return mx


def compose_stinger_treasure(rng) -> Mixer:
    """Brass fanfare: triplet pickup, G - B - long D, chord + sparkle."""
    mx = _stinger_mixer(2.5)
    for k in range(3):
        mx.add("brass", ns(0.1 * k), brass(74, 0.08, 0.85))
        mx.add("perc", ns(0.1 * k), perc_tom(rng, 165.0, 0.5 + 0.1 * k), 0.6)
    for t, d, m in ((0.3, 0.25, 79), (0.58, 0.14, 83), (0.75, 1.1, 86)):
        mx.add("brass", ns(t), brass(m, d, 1.0))
        mx.add("lead", ns(t), accordion(m, d, 0.6, rng))
    land = 0.75
    for m in (55, 59, 62, 67):
        mx.add("brass", ns(land), brass(m, 1.0, 0.7, bright=0.6), 0.5)
    _strum_now(mx, "uke", land, "G", rng, 1.0, 1.3)
    mx.add("bass", ns(land), pizz_bass(43, 1.2, 1.0, rng))
    mx.add("perc", ns(land), thump(0.8, 140, 98, 0.03, 0.3), 0.8)
    mx.add("perc", ns(land), perc_cymbal(rng, 1.8), 0.4)
    for k, m in enumerate((91, 95, 98, 103)):
        mx.add("fx", ns(1.0 + 0.06 * k), chime(mtof(m), 0.9, tau=0.4), 0.8)
    return mx


def compose_stinger_victory(rng) -> Mixer:
    """Boss beaten: a building tom roll, the hook back in G major on brass,
    a big landing chord, cymbal and sparkle."""
    mx = _stinger_mixer(3.5)
    for k in range(8):
        mx.add("perc", ns(0.055 * k), perc_tom(rng, 131.0 if k % 2 else 165.0, 0.45 + 0.06 * k), 0.7)
    motif = ((0.46, 0.22, 79), (0.68, 0.11, 74), (0.79, 0.22, 79), (1.01, 0.11, 81), (1.12, 0.22, 83), (1.34, 1.4, 86))
    for t, d, m in motif:
        mx.add("brass", ns(t), brass(m, d, 1.0))
        mx.add("lead", ns(t), accordion(m, d, 0.65, rng))
        mx.add("pan", ns(t), steelpan(m - 12, d, 0.5))
    land = 1.34
    for m in (55, 59, 62, 67, 71):
        mx.add("brass", ns(land), brass(m, 1.3, 0.75, bright=0.6), 0.5)
    _strum_now(mx, "uke", land, "G", rng, 1.0, 1.6)
    mx.add("bass", ns(land), pizz_bass(43, 1.5, 1.0, rng))
    mx.add("perc", ns(land), thump(0.8, 140, 98, 0.03, 0.3), 0.9)
    mx.add("perc", ns(land), perc_cymbal(rng, 2.0), 0.45)
    for k, m in enumerate((91, 95, 98, 103)):
        mx.add("fx", ns(1.6 + 0.06 * k), chime(mtof(m), 0.9, tau=0.4), 0.8)
    return mx


def _trim_tail(x: np.ndarray, max_len: float, floor_db: float = -60.0, fade_s: float = 0.4) -> np.ndarray:
    """Cut a one-shot's reverb tail (below floor_db or at max_len) with a smooth fade."""
    env = np.max(np.abs(x), axis=1)
    above = np.nonzero(env > np.max(env) * db2a(floor_db))[0]
    end = int(above[-1]) + 1 if len(above) else len(x)
    x = x[:min(end, ns(max_len))].copy()
    x[:ns(0.002)] *= np.linspace(0.0, 1.0, ns(0.002))[:, None]      # click-free start
    k = min(ns(fade_s), len(x))
    x[len(x) - k:] *= (0.5 + 0.5 * np.cos(np.pi * (np.arange(k) + 1) / k))[:, None]
    return x


def bus_compress(x: np.ndarray, loop: bool, thresh_db: float = -10.0, ratio: float = 2.5,
                 window: float = 0.05) -> np.ndarray:
    """Gentle program compressor for a stereo mix (peak-normalised first).
    The envelope is a windowed max + moving average, computed circularly for
    loops so the gain curve itself is seamless at the loop point."""
    x = x / (np.max(np.abs(x)) + 1e-12)
    mode = "wrap" if loop else "nearest"
    env = ndimage.maximum_filter1d(np.max(np.abs(x), axis=1), size=ns(window), mode=mode)
    env = ndimage.uniform_filter1d(env, size=ns(window), mode=mode)
    T = db2a(thresh_db)
    gain = np.ones_like(env)
    over = env > T
    gain[over] = (env[over] / T) ** (1.0 / ratio - 1.0)
    return x * gain[:, None]


def _level_rms(x: np.ndarray, target: float) -> np.ndarray:
    return soft_limit(x * (target / (rms(x) + 1e-12)))


MUSIC_NAMES = ("castaway_explore", "castaway_combat_layer", "cave_explore", "title_theme", "boss_claw",
               "stinger_discovery", "stinger_parrot", "stinger_treasure", "stinger_victory")


def render_music(only: str | None = None) -> dict:
    """Render all cues -> {name: (stereo float array, meta)}."""
    want = [n for n in MUSIC_NAMES if not only or only in n]
    if not want:
        return {}
    ir = make_ir(rng_for("music_ir"), rt60=1.5, predelay=0.015, hf=0.45)
    out = {}
    # explore + combat are levelled together so that the layered sum peaks at -1 dBFS
    explore = bus_compress(compose_explore(EXPLORE_SONG, rng_for("castaway_explore")).render(ir), True)
    combat = bus_compress(compose_combat(EXPLORE_SONG, rng_for("castaway_combat_layer")).render(ir), True)
    combat *= db2a(-4.0)                     # a layer sits ~4 dB under the main mix
    g = db2a(-1.0) / np.max(np.abs(explore + combat))
    explore, combat = soft_limit(explore * g), soft_limit(combat * g)
    ref = rms(explore)
    meta = dict(bpm=EXPLORE_SONG.bpm, bars=EXPLORE_SONG.bars, loop=True)
    out["castaway_explore"] = (explore, meta)
    out["castaway_combat_layer"] = (combat, dict(meta, layer_of="castaway_explore"))
    if "cave_explore" in want:
        cave_ir = make_ir(rng_for("cave_ir"), rt60=2.6, predelay=0.025, hf=0.4)
        x = bus_compress(compose_cave(CAVE_SONG, rng_for("cave_explore")).render(cave_ir), True)
        out["cave_explore"] = (_level_rms(x, ref * db2a(-3.0)), dict(bpm=CAVE_SONG.bpm, bars=CAVE_SONG.bars, loop=True))
    if "title_theme" in want:
        x = bus_compress(compose_title(TITLE_SONG, rng_for("title_theme")).render(ir), True)
        out["title_theme"] = (_level_rms(x, ref * db2a(1.0)), dict(bpm=TITLE_SONG.bpm, bars=TITLE_SONG.bars, loop=True))
    if "boss_claw" in want:
        x = bus_compress(compose_boss(BOSS_SONG, rng_for("boss_claw")).render(ir), True)
        out["boss_claw"] = (_level_rms(x, ref * db2a(1.0)), dict(bpm=BOSS_SONG.bpm, bars=BOSS_SONG.bars, loop=True))
    for name, fn, length in (("stinger_discovery", compose_stinger_discovery, 3.0),
                             ("stinger_parrot", compose_stinger_parrot, 2.0),
                             ("stinger_treasure", compose_stinger_treasure, 2.5),
                             ("stinger_victory", compose_stinger_victory, 3.5)):
        if name in want:
            x = _trim_tail(bus_compress(fn(rng_for(name)).render(ir), False, -8.0, 2.0), length)
            x = nz(x, db2a(-1.0))
            out[name] = (x, dict(bpm=112, bars=round(len(x) / SR * 112 / 240.0, 2), loop=False))
    return {k: v for k, v in out.items() if k in want}


# =============================================================================
# 6. Writing, manifest, verification
# =============================================================================
def write_wav(path: Path, x: np.ndarray) -> None:
    """16-bit PCM with explicit rounding (bit-exact, deterministic)."""
    pcm = np.clip(np.round(np.asarray(x) * 32767.0), -32768, 32767).astype(np.int16)
    sf.write(str(path), pcm, SR, subtype="PCM_16")


def write_ogg(path: Path, x: np.ndarray) -> None:
    """Ogg Vorbis, VBR quality OGG_QUALITY (libsndfile maps compression level
    c to Vorbis quality 1-c).  Written in blocks: some libsndfile builds crash
    when a long buffer is handed to the Vorbis encoder in one call."""
    x = np.asarray(x, np.float32)
    with sf.SoundFile(str(path), "w", SR, x.shape[1], format="OGG", subtype="VORBIS",
                      compression_level=1.0 - OGG_QUALITY) as f:
        for i in range(0, len(x), 32768):
            f.write(x[i:i + 32768])


def onset_ms(x: np.ndarray) -> float:
    """Time until the signal first exceeds -40 dB re. its peak."""
    a = np.abs(x)
    return 1000.0 * int(np.argmax(a >= a.max() * db2a(-40))) / SR


def verify(manifest: dict) -> bool:
    """Re-read every output, check format/duration/level/loop seams, print a table."""
    print(f"\n{'name':<24}{'kind':<6}{'dur s':>7}{'ch':>3}{'peak':>7}{'rms':>7}{'onset':>7}{'seam':>6}  status")
    print("-" * 78)
    ok_all, total, counts = True, 0, {}
    for kind in ("sfx", "music"):
        for name, e in manifest[kind].items():
            path = AUDIO_DIR / e["file"].replace("res://audio/", "")
            probs = []
            if not path.exists():
                print(f"{name:<24}{kind:<6} MISSING")
                ok_all = False
                continue
            x, sr = sf.read(str(path), always_2d=True)
            mono = x.mean(axis=1)
            dur = x.shape[0] / sr
            pk, lv = a2db(np.max(np.abs(x))), a2db(rms(x))
            if sr != SR:
                probs.append(f"sr={sr}")
            if x.shape[1] != (1 if kind == "sfx" else 2):
                probs.append(f"ch={x.shape[1]}")
            if abs(dur - e["duration"]) > 0.002:
                probs.append("duration")
            if lv < -60:
                probs.append("silent")
            if pk > -0.3:
                probs.append("too hot")
            on = onset_ms(mono)
            if not e["loop"] and on > 5.0:
                probs.append("late onset")
            seam = seam_ratio(x) if e["loop"] else None
            if seam is not None and seam > 2.0:
                probs.append("seam")
            ok_all &= not probs
            total += path.stat().st_size
            group = kind if kind == "music" else e["bus"]
            counts[group] = counts.get(group, 0) + 1
            seam_s = f"{seam:6.2f}" if seam is not None else "     -"
            print(f"{name:<24}{kind:<6}{dur:7.3f}{x.shape[1]:3d}{pk:7.1f}{lv:7.1f}{on:7.1f}{seam_s}  "
                  f"{'ok' if not probs else 'FAIL: ' + ', '.join(probs)}")
    print("-" * 78)
    print("files: " + ", ".join(f"{k}={v}" for k, v in counts.items())
          + f"  |  total {sum(counts.values())} files, {total / 1e6:.2f} MB")
    print("all checks passed" if ok_all else "SOME CHECKS FAILED")
    return ok_all


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Generate PATCHY's procedural SFX and music.")
    ap.add_argument("--only", help="only (re)generate sounds whose name contains this text")
    ap.add_argument("--no-sfx", action="store_true", help="skip sound effects")
    ap.add_argument("--no-music", action="store_true", help="skip music")
    args = ap.parse_args(argv)
    t0 = time.time()
    SFX_DIR.mkdir(parents=True, exist_ok=True)
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    manifest = {"sfx": {}, "music": {}, "groups": {}}
    if (args.only or args.no_sfx or args.no_music) and MANIFEST_PATH.exists():
        old = json.loads(MANIFEST_PATH.read_text())          # partial run: keep other entries
        manifest["sfx"].update(old.get("sfx", {}))
        manifest["music"].update(old.get("music", {}))

    if not args.no_sfx:
        for spec in SFX:
            if args.only and args.only not in spec.name:
                continue
            x = finalize_sfx(spec.fn(rng_for(spec.name)), spec)
            write_wav(SFX_DIR / f"{spec.name}.wav", x)
            manifest["sfx"][spec.name] = {
                "file": f"res://audio/sfx/{spec.name}.wav", "duration": round(len(x) / SR, 4),
                "loop": spec.loop, "bus": spec.bus, "volume_db": spec.volume_db}
        print(f"sfx rendered in {time.time() - t0:.1f}s")
    order = {s.name: i for i, s in enumerate(SFX)}
    manifest["sfx"] = dict(sorted(manifest["sfx"].items(), key=lambda kv: order.get(kv[0], 1e9)))
    for spec in SFX:
        if spec.group:
            manifest["groups"].setdefault(spec.group, []).append(spec.name)

    if not args.no_music:
        t1 = time.time()
        for name, (x, meta) in render_music(args.only).items():
            write_ogg(MUSIC_DIR / f"{name}.ogg", x)
            entry = {"file": f"res://audio/music/{name}.ogg", "duration": round(x.shape[0] / SR, 4),
                     "loop": meta["loop"], "bpm": meta["bpm"], "bars": meta["bars"]}
            if meta.get("layer_of"):
                entry["layer_of"] = meta["layer_of"]
            entry.update({"time_signature": "4/4", "samples": int(x.shape[0])})
            manifest["music"][name] = entry
        print(f"music rendered in {time.time() - t1:.1f}s")
    morder = {n: i for i, n in enumerate(MUSIC_NAMES)}
    manifest["music"] = dict(sorted(manifest["music"].items(), key=lambda kv: morder.get(kv[0], 1e9)))

    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n")
    ok = verify(manifest)
    print(f"finished in {time.time() - t0:.1f}s -> {AUDIO_DIR}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
