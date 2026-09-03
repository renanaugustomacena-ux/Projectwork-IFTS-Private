#!/usr/bin/env python3
"""Sintetizza gli effetti sonori "cozy" del gioco e li scrive come WAV 16-bit mono.

Tutti i suoni sono generati proceduralmente (niente campioni esterni), con
timbri morbidi: sinusoidi/triangolari con inviluppi ADSR dolci, leggero
vibrato, riverbero a delay con feedback e rumore filtrato per polvere, tuono
e fusa. Nessuna onda quadra aggressiva.

Output: v1/assets/audio/sfx/synth/<nome>.wav
  - 22050 Hz per gli UI / one-shot brevi, 44100 Hz per tuono e fusa
  - picco normalizzato a -3 dBFS (loop a -9 dBFS)
  - fade-in/out di 5 ms sugli one-shot per evitare click
  - i loop iniziano/finiscono su uno zero-crossing e hanno un crossfade
    testa/coda per ripetersi senza scatti

Il generatore e' deterministico: stesso script -> stessi byte (seed fisso per
ogni suono, nessuna dipendenza dall'orario).

Uso: python tools/gen_sfx.py [--out DIR] [--only nome1,nome2] [--list]
Dipendenze: numpy (pip install numpy). Il modulo `wave` e' nella stdlib.
"""
from __future__ import annotations

import argparse
import math
import struct
import sys
import wave
from pathlib import Path

import numpy as np

REPO_ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = REPO_ROOT / "v1/assets/audio/sfx/synth"

SR_UI = 22050  # sample rate per UI e one-shot brevi
SR_HI = 44100  # sample rate per tuono / fusa (rumore a banda larga)

PEAK_DB_ONESHOT = -3.0
PEAK_DB_LOOP = -9.0
EDGE_FADE_S = 0.005  # 5 ms

# Seed base: ogni suono usa BASE_SEED + indice stabile (vedi SOUNDS in fondo),
# cosi' aggiungere un suono nuovo non cambia il rumore di quelli esistenti.
BASE_SEED = 20260903

TWO_PI = 2.0 * math.pi


# ---------------------------------------------------------------------------
# Primitive: tempo, oscillatori, inviluppi
# ---------------------------------------------------------------------------
def tline(dur: float, sr: int) -> np.ndarray:
    """Asse dei tempi in secondi, `dur` secondi a `sr` Hz."""
    n = max(1, int(round(dur * sr)))
    return np.arange(n, dtype=np.float64) / sr


def phase_from_freq(freq: np.ndarray | float, sr: int, n: int | None = None) -> np.ndarray:
    """Integra una frequenza (costante o array) nella fase in radianti.
    Serve per glissandi e vibrato senza discontinuita' di fase."""
    if np.isscalar(freq):
        assert n is not None
        freq = np.full(n, float(freq))
    return TWO_PI * np.cumsum(np.asarray(freq, dtype=np.float64)) / sr


def sine(freq, dur: float, sr: int, phase0: float = 0.0) -> np.ndarray:
    n = len(tline(dur, sr))
    return np.sin(phase_from_freq(freq, sr, n) + phase0)


def triangle(freq, dur: float, sr: int) -> np.ndarray:
    """Onda triangolare morbida (solo armoniche dispari, decadono 1/n^2)."""
    n = len(tline(dur, sr))
    ph = phase_from_freq(freq, sr, n)
    return 2.0 / math.pi * np.arcsin(np.sin(ph))


def soft_harmonics(freq, dur: float, sr: int, n_harm: int = 6, rolloff: float = 1.6) -> np.ndarray:
    """Somma di armoniche con ampiezza 1/k^rolloff: timbro "legnoso" ma morbido."""
    n = len(tline(dur, sr))
    ph = phase_from_freq(freq, sr, n)
    out = np.zeros(n)
    for k in range(1, n_harm + 1):
        out += np.sin(ph * k) / (k**rolloff)
    return out / np.max(np.abs(out) + 1e-9)


def vibrato(base_freq, dur: float, sr: int, rate: float = 5.5, depth: float = 0.01, delay: float = 0.0) -> np.ndarray:
    """Restituisce un array di frequenza con vibrato sinusoidale (depth relativa).
    `delay` fa partire il vibrato dopo un po', come farebbe un musicista."""
    t = tline(dur, sr)
    ramp = np.clip((t - delay) / max(0.02, dur - delay), 0.0, 1.0) if delay > 0 else 1.0
    base = np.full(len(t), base_freq) if np.isscalar(base_freq) else np.asarray(base_freq)
    return base * (1.0 + depth * ramp * np.sin(TWO_PI * rate * t))


def glide(f_start: float, f_end: float, dur: float, sr: int, curve: float = 1.0) -> np.ndarray:
    """Glissando esponenziale (in pitch) da f_start a f_end. curve>1 = arriva prima."""
    t = tline(dur, sr)
    x = (t / t[-1]) ** curve if len(t) > 1 else t
    return f_start * (f_end / f_start) ** x


def adsr(n: int, sr: int, a: float, d: float, s: float, r: float, curve: float = 2.0) -> np.ndarray:
    """Inviluppo ADSR con curve morbide (attacco lineare, decadimento e rilascio
    a potenza `curve`). Se a+d+r > durata, il sustain viene compresso a zero."""
    a_n = int(a * sr)
    d_n = int(d * sr)
    r_n = int(r * sr)
    s_n = max(0, n - a_n - d_n - r_n)
    if s_n == 0:  # non c'e' spazio: scala tutto proporzionalmente
        tot = max(1, a_n + d_n + r_n)
        a_n = int(n * a_n / tot)
        d_n = int(n * d_n / tot)
        r_n = n - a_n - d_n
    att = np.linspace(0.0, 1.0, a_n, endpoint=False) if a_n else np.zeros(0)
    dec = 1.0 - (1.0 - s) * (np.linspace(0.0, 1.0, d_n, endpoint=False) ** (1.0 / curve)) if d_n else np.zeros(0)
    sus = np.full(s_n, s)
    rel = s * (1.0 - np.linspace(0.0, 1.0, r_n, endpoint=True)) ** curve if r_n else np.zeros(0)
    env = np.concatenate([att, dec, sus, rel])
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]


def exp_decay(n: int, sr: int, tau: float, attack: float = 0.002) -> np.ndarray:
    """Inviluppo percussivo: attacco brevissimo, poi decadimento esponenziale."""
    t = np.arange(n) / sr
    env = np.exp(-t / tau)
    a_n = max(1, int(attack * sr))
    env[:a_n] *= np.linspace(0.0, 1.0, a_n, endpoint=False)
    return env


# ---------------------------------------------------------------------------
# Rumore (deterministico) e filtri
# ---------------------------------------------------------------------------
def white(rng: np.random.Generator, n: int) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, n)


def pink(rng: np.random.Generator, n: int) -> np.ndarray:
    """Rumore rosa (filtro di Paul Kellet, -3 dB/ottava)."""
    w = white(rng, n)
    out = np.empty(n)
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    for i in range(n):
        x = w[i]
        b0 = 0.99886 * b0 + x * 0.0555179
        b1 = 0.99332 * b1 + x * 0.0750759
        b2 = 0.96900 * b2 + x * 0.1538520
        b3 = 0.86650 * b3 + x * 0.3104856
        b4 = 0.55000 * b4 + x * 0.5329522
        b5 = -0.7616 * b5 - x * 0.0168980
        out[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + x * 0.5362) * 0.11
        b6 = x * 0.115926
    return out / (np.max(np.abs(out)) + 1e-9)


def brown(rng: np.random.Generator, n: int, leak: float = 0.995) -> np.ndarray:
    """Rumore marrone: integrazione con perdita del rumore bianco (-6 dB/ottava)."""
    w = white(rng, n)
    out = np.empty(n)
    acc = 0.0
    for i in range(n):
        acc = leak * acc + w[i] * 0.02
        out[i] = acc
    return out / (np.max(np.abs(out)) + 1e-9)


def lowpass(x: np.ndarray, cutoff: float, sr: int, passes: int = 1) -> np.ndarray:
    """Passa-basso a un polo (RC). `passes` > 1 per una pendenza piu' ripida."""
    alpha = 1.0 - math.exp(-TWO_PI * cutoff / sr)
    y = np.asarray(x, dtype=np.float64)
    for _ in range(passes):
        out = np.empty_like(y)
        acc = 0.0
        for i in range(len(y)):
            acc += alpha * (y[i] - acc)
            out[i] = acc
        y = out
    return y


def highpass(x: np.ndarray, cutoff: float, sr: int, passes: int = 1) -> np.ndarray:
    """Passa-alto: segnale meno la sua versione passa-basso."""
    y = np.asarray(x, dtype=np.float64)
    for _ in range(passes):
        y = y - lowpass(y, cutoff, sr)
    return y


def bandpass(x: np.ndarray, lo: float, hi: float, sr: int, passes: int = 1) -> np.ndarray:
    return highpass(lowpass(x, hi, sr, passes), lo, sr, passes)


def resonant_bp(x: np.ndarray, freq, q: float, sr: int) -> np.ndarray:
    """Passa-banda risonante (biquad RBJ). `freq` puo' essere un array per una
    formante che si muove nel tempo (coefficienti ricalcolati ogni campione)."""
    n = len(x)
    freqs = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, dtype=np.float64)
    out = np.empty(n)
    x1 = x2 = y1 = y2 = 0.0
    last_f = None
    b0 = b1 = b2 = a1 = a2 = 0.0
    for i in range(n):
        f = freqs[i]
        if f != last_f:
            w0 = TWO_PI * f / sr
            alpha = math.sin(w0) / (2.0 * q)
            a0 = 1.0 + alpha
            b0 = alpha / a0
            b1 = 0.0
            b2 = -alpha / a0
            a1 = -2.0 * math.cos(w0) / a0
            a2 = (1.0 - alpha) / a0
            last_f = f
        xi = x[i]
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, xi
        y2, y1 = y1, yi
        out[i] = yi
    return out


# ---------------------------------------------------------------------------
# Effetti: riverbero, mix, normalizzazione, loop
# ---------------------------------------------------------------------------
def reverb(x: np.ndarray, sr: int, mix: float = 0.25, decay: float = 0.6, tail: float = 0.6, damp: float = 3500.0) -> np.ndarray:
    """Riverbero semplice: 3 delay in feedback con smorzamento degli acuti,
    tempi primi tra loro per evitare risonanze metalliche. Allunga il buffer
    di `tail` secondi per lasciare spazio alla coda."""
    n = len(x) + int(tail * sr)
    dry = np.concatenate([x, np.zeros(n - len(x))])
    wet = np.zeros(n)
    for delay_ms, gain in ((29.7, decay), (37.1, decay * 0.9), (41.1, decay * 0.8)):
        d = int(delay_ms * sr / 1000.0)
        comb = np.zeros(n)
        # elaborazione a blocchi di lunghezza d: ogni blocco dipende solo dal precedente
        prev = np.zeros(d)
        alpha = 1.0 - math.exp(-TWO_PI * damp / sr)
        lp_state = 0.0
        for start in range(0, n, d):
            end = min(start + d, n)
            fb = prev[: end - start].copy()
            # smorzamento a un polo dentro il loop di feedback
            for i in range(len(fb)):
                lp_state += alpha * (fb[i] - lp_state)
                fb[i] = lp_state
            blk = dry[start:end] + gain * fb
            comb[start:end] = blk
            prev = np.concatenate([blk, np.zeros(d - len(blk))]) if len(blk) < d else blk
        wet += comb / 3.0
    return (1.0 - mix) * dry + mix * wet


def mix_at(base: np.ndarray, part: np.ndarray, at: float, sr: int, gain: float = 1.0) -> np.ndarray:
    """Somma `part` dentro `base` a partire dal tempo `at` (allunga se serve)."""
    start = int(at * sr)
    need = start + len(part)
    if need > len(base):
        base = np.concatenate([base, np.zeros(need - len(base))])
    base[start:need] += gain * part
    return base


def normalize(x: np.ndarray, peak_db: float) -> np.ndarray:
    peak = np.max(np.abs(x))
    if peak < 1e-9:
        return x
    return x * (10.0 ** (peak_db / 20.0)) / peak


def edge_fade(x: np.ndarray, sr: int, secs: float = EDGE_FADE_S) -> np.ndarray:
    """Fade-in/out lineare ai bordi (anti-click sugli one-shot)."""
    n = min(len(x) // 2, max(1, int(secs * sr)))
    y = x.copy()
    ramp = np.linspace(0.0, 1.0, n, endpoint=False)
    y[:n] *= ramp
    y[-n:] *= ramp[::-1]
    return y


def make_loop(x: np.ndarray, loop_len: float, sr: int, xfade: float = 0.05) -> np.ndarray:
    """Trasforma un segnale piu' lungo di `loop_len` in un loop pulito:
    1. la coda oltre `loop_len` viene fusa (crossfade) sulla testa;
    2. il loop viene ruotato in modo da iniziare su uno zero-crossing
       ascendente, cosi' anche l'ultimo campione e' vicino a zero."""
    n = int(loop_len * sr)
    xf = int(xfade * sr)
    assert len(x) >= n + xf, "il segnale sorgente deve essere lungo almeno loop_len + xfade"
    body = x[:n].copy()
    tail = x[n : n + xf]
    fade_in = np.linspace(0.0, 1.0, xf)
    body[:xf] = body[:xf] * fade_in + tail * (1.0 - fade_in)
    # cerca lo zero-crossing ascendente piu' vicino al centro del crossfade
    # (dove il segnale e' gia' "fuso" e non a ridosso dei bordi)
    search_from = xf // 2
    zc = np.where((body[search_from:-1] <= 0.0) & (body[search_from + 1 :] > 0.0))[0]
    if len(zc):
        body = np.roll(body, -(search_from + zc[0] + 1))
    return body


def write_wav(path: Path, x: np.ndarray, sr: int) -> None:
    data = np.clip(x, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def note(name: str) -> float:
    """Nome nota (es. 'C5', 'F#4') -> frequenza in Hz, A4 = 440."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    key = name[:-1]
    octave = int(name[-1])
    semis = names[key] + (octave - 4) * 12
    return 440.0 * 2.0 ** (semis / 12.0)


# ---------------------------------------------------------------------------
# Blocchi riutilizzabili
# ---------------------------------------------------------------------------
def soft_tick(freq_from: float, freq_to: float, dur: float, sr: int, tau: float = 0.02, noise_rng=None) -> np.ndarray:
    """Tick morbido: sinusoide con leggero glissando + decadimento esponenziale
    + (opzionale) un pizzico di rumore filtrato sull'attacco."""
    n = len(tline(dur, sr))
    tone = sine(glide(freq_from, freq_to, dur, sr, curve=0.7), dur, sr) * exp_decay(n, sr, tau)
    if noise_rng is not None:
        nz = bandpass(white(noise_rng, n), 1500.0, 6000.0, sr) * exp_decay(n, sr, 0.004)
        tone += 0.25 * nz
    return tone


def bell(freq: float, dur: float, sr: int, tau: float = 0.12, harm2: float = 0.35, vib: float = 0.004) -> np.ndarray:
    """"Ding" morbido: fondamentale + un'armonica (2x) che decade piu' in fretta,
    con un filo di vibrato che lo rende meno sintetico."""
    n = len(tline(dur, sr))
    f = vibrato(freq, dur, sr, rate=6.0, depth=vib, delay=0.05)
    fund = sine(f, dur, sr) * exp_decay(n, sr, tau)
    h2 = sine(f * 2.0, dur, sr) * exp_decay(n, sr, tau * 0.45)
    h3 = sine(f * 3.0, dur, sr) * exp_decay(n, sr, tau * 0.25)
    return fund + harm2 * h2 + harm2 * 0.3 * h3


def soft_note(freq: float, dur: float, sr: int, a: float = 0.02, r: float = 0.12, vib: float = 0.006) -> np.ndarray:
    """Nota sostenuta morbida (triangolare + sinusoide) con ADSR dolce e vibrato."""
    n = len(tline(dur, sr))
    f = vibrato(freq, dur, sr, rate=5.5, depth=vib, delay=0.08)
    tone = 0.6 * sine(f, dur, sr) + 0.4 * triangle(f, dur, sr)
    return tone * adsr(n, sr, a, 0.08, 0.7, r)


# ---------------------------------------------------------------------------
# I singoli suoni. Ogni funzione riceve (sr, rng) e restituisce un array float.
# ---------------------------------------------------------------------------
def sfx_ui_click(sr, rng):
    return soft_tick(1900.0, 1300.0, 0.08, sr, tau=0.018, noise_rng=rng)


def sfx_ui_hover(sr, rng):
    # piu' tenue: meno rumore, decadimento piu' corto, pitch piu' morbido
    return soft_tick(1500.0, 1250.0, 0.06, sr, tau=0.012)


def sfx_ui_open(sr, rng):
    out = np.zeros(1)
    out = mix_at(out, bell(note("C6"), 0.09, sr, tau=0.03, harm2=0.2), 0.0, sr)
    out = mix_at(out, bell(note("E6"), 0.12, sr, tau=0.04, harm2=0.2), 0.06, sr)
    return out


def sfx_ui_close(sr, rng):
    out = np.zeros(1)
    out = mix_at(out, bell(note("E6"), 0.09, sr, tau=0.03, harm2=0.2), 0.0, sr)
    out = mix_at(out, bell(note("C6"), 0.12, sr, tau=0.04, harm2=0.2), 0.06, sr)
    return out


def sfx_deco_place(sr, rng):
    # thud: sinusoide grave con pitch che scende, decadimento ~150 ms
    thud_d = 0.2
    n = len(tline(thud_d, sr))
    thud = sine(glide(110.0, 55.0, thud_d, sr, curve=0.5), thud_d, sr) * exp_decay(n, sr, 0.05)
    # "clic" legno: rumore in banda 1.5-4 kHz brevissimo + armoniche legnose
    click_d = 0.03
    cn = len(tline(click_d, sr))
    click = bandpass(white(rng, cn), 1500.0, 4000.0, sr) * exp_decay(cn, sr, 0.005)
    wood = soft_harmonics(620.0, click_d, sr, n_harm=4, rolloff=1.2) * exp_decay(cn, sr, 0.006)
    out = thud
    out = mix_at(out, click, 0.0, sr, gain=0.35)
    out = mix_at(out, wood, 0.0, sr, gain=0.3)
    return out


def sfx_deco_remove(sr, rng):
    d = 0.07
    n = len(tline(d, sr))
    return sine(glide(1100.0, 350.0, d, sr, curve=0.8), d, sr) * exp_decay(n, sr, 0.02)


def sfx_deco_rotate(sr, rng):
    return soft_tick(1300.0, 1100.0, 0.06, sr, tau=0.014, noise_rng=rng)


def sfx_deco_scale(sr, rng):
    d = 0.1
    n = len(tline(d, sr))
    return sine(glide(800.0, 1700.0, d, sr, curve=1.2), d, sr) * exp_decay(n, sr, 0.03)


def sfx_coin(sr, rng):
    # ding pentatonico: E6 con un tocco di G6 (terza minore -> pentatonica) + armonica
    out = bell(note("E6"), 0.3, sr, tau=0.09, harm2=0.4)
    out = mix_at(out, bell(note("G6"), 0.25, sr, tau=0.07, harm2=0.3), 0.03, sr, gain=0.5)
    return out


def sfx_purchase(sr, rng):
    out = np.zeros(1)
    out = mix_at(out, bell(note("C6"), 0.2, sr, tau=0.06), 0.0, sr)
    out = mix_at(out, bell(note("E6"), 0.25, sr, tau=0.07), 0.11, sr)
    # "cassa": clic meccanico + piccolo "ka-ching" smorzato
    cn = len(tline(0.08, sr))
    cassa = bandpass(white(rng, cn), 800.0, 3000.0, sr) * exp_decay(cn, sr, 0.012)
    ching = bell(note("A6"), 0.14, sr, tau=0.03, harm2=0.5)
    out = mix_at(out, cassa, 0.24, sr, gain=0.45)
    out = mix_at(out, ching, 0.25, sr, gain=0.35)
    return out


def sfx_eat(sr, rng):
    out = np.zeros(1)
    for i, (f0, f1) in enumerate(((240.0, 150.0), (220.0, 140.0), (250.0, 160.0))):
        d = 0.09
        n = len(tline(d, sr))
        # "nom": triangolare grave con glissando in discesa e un soffio di rumore
        nom = triangle(glide(f0, f1, d, sr), d, sr) * adsr(n, sr, 0.015, 0.03, 0.5, 0.04)
        puff = lowpass(white(rng, n), 900.0, sr, passes=2) * exp_decay(n, sr, 0.02)
        out = mix_at(out, nom, i * 0.13, sr)
        out = mix_at(out, puff, i * 0.13, sr, gain=0.3)
    return out


def sfx_drink(sr, rng):
    # sorso: rumore in banda che sale (labbra/liquido) + bolla sinusoidale
    d = 0.18
    n = len(tline(d, sr))
    sip = resonant_bp(white(rng, n), glide(700.0, 1600.0, d, sr), 4.0, sr) * adsr(n, sr, 0.03, 0.05, 0.6, 0.08)
    bd = 0.07
    bn = len(tline(bd, sr))
    bubble = sine(glide(380.0, 950.0, bd, sr, curve=1.4), bd, sr) * exp_decay(bn, sr, 0.025)
    out = sip / (np.max(np.abs(sip)) + 1e-9)
    out = mix_at(out, bubble, 0.13, sr, gain=0.55)
    return out


def _swish(rng, dur: float, sr: int, lo: float, hi: float, peak_at: float = 0.4) -> np.ndarray:
    """Fruscio: rumore rosa in banda con inviluppo a campana (asimmetrico)."""
    n = len(tline(dur, sr))
    t = np.linspace(0.0, 1.0, n)
    env = np.where(t < peak_at, (t / peak_at) ** 1.5, ((1.0 - t) / (1.0 - peak_at)) ** 1.2)
    nz = bandpass(pink(rng, n), lo, hi, sr)
    return nz / (np.max(np.abs(nz)) + 1e-9) * env


def sfx_clean_start(sr, rng):
    # due strofinate veloci di straccio
    out = np.zeros(1)
    out = mix_at(out, _swish(rng, 0.16, sr, 1800.0, 6000.0), 0.0, sr)
    out = mix_at(out, _swish(rng, 0.17, sr, 1500.0, 5500.0), 0.14, sr, gain=0.8)
    return out


def sfx_clean_done(sr, rng):
    out = np.zeros(1)
    for i, nm in enumerate(("C6", "E6", "G6")):
        out = mix_at(out, bell(note(nm), 0.18, sr, tau=0.05, harm2=0.3), i * 0.07, sr)
    # shimmer: sinusoide alta con vibrato + un velo di rumore brillante
    sd = 0.4
    sn = len(tline(sd, sr))
    shimmer = sine(vibrato(note("C7"), sd, sr, rate=7.0, depth=0.01), sd, sr) * exp_decay(sn, sr, 0.12)
    sparkle = highpass(white(rng, sn), 5000.0, sr, passes=2) * exp_decay(sn, sr, 0.08)
    out = mix_at(out, shimmer, 0.2, sr, gain=0.35)
    out = mix_at(out, sparkle, 0.2, sr, gain=0.12)
    return reverb(out, sr, mix=0.2, decay=0.5, tail=0.15)


def sfx_clean_loop_broom(sr, rng):
    # due colpi di scopa per secondo (andata piu' forte, ritorno piu' leggero)
    src = np.zeros(1)
    src = mix_at(src, _swish(rng, 0.42, sr, 900.0, 4500.0, peak_at=0.35), 0.02, sr)
    src = mix_at(src, _swish(rng, 0.38, sr, 800.0, 4000.0, peak_at=0.4), 0.52, sr, gain=0.65)
    # letto continuo di rumore molto tenue per non avere silenzio assoluto tra i colpi
    bed_n = int(1.1 * sr)
    bed = bandpass(pink(rng, bed_n), 600.0, 3000.0, sr)
    src = mix_at(src, bed / (np.max(np.abs(bed)) + 1e-9), 0.0, sr, gain=0.08)
    return make_loop(src, 1.0, sr, xfade=0.05)


def sfx_clean_loop_vacuum(sr, rng):
    n = int(1.1 * sr)
    p = pink(rng, n)
    # motore: risonanza stretta a ~120 Hz + seconda armonica a 240 Hz
    motor = resonant_bp(p, 120.0, 12.0, sr)
    motor2 = resonant_bp(p, 240.0, 10.0, sr)
    # soffio dell'aria: rumore rosa passa-basso
    air = lowpass(p, 1800.0, sr, passes=2)
    # leggero flutter del motore (~7 Hz) per non essere una linea piatta
    t = tline(1.1, sr)
    flutter = 1.0 + 0.06 * np.sin(TWO_PI * 7.0 * t)
    m = motor / (np.max(np.abs(motor)) + 1e-9)
    m2 = motor2 / (np.max(np.abs(motor2)) + 1e-9)
    a = air / (np.max(np.abs(air)) + 1e-9)
    src = (0.7 * m + 0.25 * m2 + 0.4 * a) * flutter
    return make_loop(src, 1.0, sr, xfade=0.06)


def _creak(f_from: float, f_to: float, dur: float, sr: int, rng) -> np.ndarray:
    """Cigolio morbido: armoniche legnose con pitch che scivola e un jitter
    lento sulla frequenza (il legno che "cede" a scatti piccolissimi)."""
    n = len(tline(dur, sr))
    base = glide(f_from, f_to, dur, sr, curve=1.0)
    jitter = lowpass(white(rng, n), 40.0, sr, passes=2)
    jitter = jitter / (np.max(np.abs(jitter)) + 1e-9)
    f = base * (1.0 + 0.03 * jitter)
    tone = soft_harmonics(f, dur, sr, n_harm=5, rolloff=1.4)
    return tone * adsr(n, sr, 0.03, 0.05, 0.6, 0.08)


def sfx_sit(sr, rng):
    out = _creak(210.0, 150.0, 0.22, sr, rng)
    # cuscino: thud tenue alla fine
    td = 0.12
    tn = len(tline(td, sr))
    thud = sine(glide(90.0, 60.0, td, sr), td, sr) * exp_decay(tn, sr, 0.04)
    return mix_at(out, thud, 0.12, sr, gain=0.6)


def sfx_stand(sr, rng):
    out = _creak(150.0, 205.0, 0.2, sr, rng)
    # molla che si rilascia: soffio tenue
    pn = len(tline(0.08, sr))
    puff = lowpass(white(rng, pn), 1200.0, sr, passes=2) * exp_decay(pn, sr, 0.02)
    return mix_at(out, puff, 0.0, sr, gain=0.25)


def sfx_save(sr, rng):
    d = 0.45
    out = np.zeros(1)
    for nm, g in (("C5", 1.0), ("E5", 0.8), ("G5", 0.7)):
        out = mix_at(out, soft_note(note(nm), d, sr, a=0.04, r=0.2), 0.0, sr, gain=g)
    return reverb(out, sr, mix=0.18, decay=0.45, tail=0.1)


def sfx_toast(sr, rng):
    out = bell(note("A5"), 0.35, sr, tau=0.1, harm2=0.45)
    out = mix_at(out, bell(note("E6"), 0.3, sr, tau=0.08, harm2=0.3), 0.04, sr, gain=0.4)
    return out


def sfx_badge(sr, rng):
    out = np.zeros(1)
    for i, nm in enumerate(("C5", "E5", "G5", "C6")):
        out = mix_at(out, bell(note(nm), 0.35, sr, tau=0.11, harm2=0.35), i * 0.16, sr, gain=0.8 + 0.06 * i)
    # accordo finale tenuto sotto l'ultima nota
    for nm in ("E5", "G5"):
        out = mix_at(out, soft_note(note(nm), 0.4, sr, a=0.05, r=0.25), 0.48, sr, gain=0.35)
    return reverb(out, sr, mix=0.3, decay=0.65, tail=0.3)


def sfx_cat_purr_loop(sr, rng):
    loop_len = 2.0
    n = int((loop_len + 0.12) * sr)
    t = np.arange(n) / sr
    base = lowpass(brown(rng, n), 350.0, sr)
    base = base / (np.max(np.abs(base)) + 1e-9)
    # vibrazione delle fusa: impulsi a ~25 Hz (coseno raddrizzato, morbido)
    purr_rate = 25.0
    pulse = (0.5 + 0.5 * np.cos(TWO_PI * purr_rate * t)) ** 2.0
    # respiro: inspirazione un po' piu' intensa dell'espirazione, periodo = loop
    breath = 0.55 + 0.45 * np.sin(TWO_PI * t / loop_len - math.pi / 2)
    breath = 0.35 + 0.65 * breath ** 1.3
    return make_loop(base * pulse * breath, loop_len, sr, xfade=0.08)


def sfx_cat_meow(sr, rng):
    d = 0.35
    n = len(tline(d, sr))
    t = np.linspace(0.0, 1.0, n)
    # fondamentale: sale poi scende ("mi-a-o"), con vibrato
    f0 = np.where(t < 0.45, 480.0 * (700.0 / 480.0) ** (t / 0.45), 700.0 * (380.0 / 700.0) ** ((t - 0.45) / 0.55))
    f0 = vibrato(f0, d, sr, rate=7.0, depth=0.02, delay=0.06)
    src = soft_harmonics(f0, d, sr, n_harm=10, rolloff=1.1)
    # formante: glissando 600 -> 900 -> 500 Hz
    formant = np.where(t < 0.45, 600.0 + 300.0 * (t / 0.45), 900.0 - 400.0 * ((t - 0.45) / 0.55))
    voiced = resonant_bp(src, formant, 3.5, sr)
    voiced = voiced / (np.max(np.abs(voiced)) + 1e-9)
    # un po' di sorgente diretta per non perdere il corpo
    out = 0.75 * voiced + 0.35 * src
    env = adsr(n, sr, 0.04, 0.06, 0.8, 0.12, curve=1.5)
    return out * env


def sfx_cat_hiss(sr, rng):
    d = 0.4
    n = len(tline(d, sr))
    nz = highpass(white(rng, n), 3200.0, sr, passes=2)
    env = adsr(n, sr, 0.03, 0.1, 0.55, 0.2, curve=1.8)
    return nz * env


def sfx_thunder_far(sr, rng):
    d = 2.5
    n = len(tline(d, sr))
    t = np.arange(n) / sr
    rumble = lowpass(brown(rng, n), 140.0, sr, passes=2)
    rumble = rumble / (np.max(np.abs(rumble)) + 1e-9)
    # inviluppo lungo: cresce in ~0.35 s, poi svanisce; un paio di "onde" lente sopra
    env = adsr(n, sr, 0.35, 0.6, 0.5, 1.2, curve=2.2)
    waves = 1.0 + 0.25 * np.sin(TWO_PI * 1.3 * t + 0.4) + 0.15 * np.sin(TWO_PI * 3.1 * t)
    return rumble * env * waves


def sfx_thunder_near(sr, rng):
    # crack: rumore bianco brevissimo, ancora abbastanza scuro da non essere aggressivo
    cd = 0.06
    cn = len(tline(cd, sr))
    crack = lowpass(white(rng, cn), 2500.0, sr) * exp_decay(cn, sr, 0.012, attack=0.0005)
    crack = crack / (np.max(np.abs(crack)) + 1e-9)
    # rombo: rumore marrone con onde irregolari, decade in ~2 s
    rd = 2.0
    rn = len(tline(rd, sr))
    t = np.arange(rn) / sr
    rumble = lowpass(brown(rng, rn), 180.0, sr, passes=2)
    rumble = rumble / (np.max(np.abs(rumble)) + 1e-9)
    waves = 1.0 + 0.3 * np.sin(TWO_PI * 1.7 * t) + 0.2 * np.sin(TWO_PI * 4.3 * t + 1.0)
    rumble = rumble * exp_decay(rn, sr, 0.55, attack=0.02) * waves
    out = np.zeros(1)
    out = mix_at(out, crack, 0.0, sr, gain=1.0)
    out = mix_at(out, rumble, 0.03, sr, gain=0.9)
    return out


def sfx_mess_spawn(sr, rng):
    d = 0.25
    n = len(tline(d, sr))
    puff = lowpass(pink(rng, n), 1400.0, sr, passes=2)
    puff = puff / (np.max(np.abs(puff)) + 1e-9)
    return puff * adsr(n, sr, 0.02, 0.06, 0.4, 0.15, curve=1.8)


def sfx_pet_fed(sr, rng):
    out = np.zeros(1)
    out = mix_at(out, soft_note(note("G5"), 0.18, sr, a=0.02, r=0.08), 0.0, sr)
    out = mix_at(out, soft_note(note("C6"), 0.26, sr, a=0.02, r=0.14), 0.15, sr, gain=0.9)
    return reverb(out, sr, mix=0.15, decay=0.4, tail=0.08)


def sfx_trust_up(sr, rng):
    out = np.zeros(1)
    for i, nm in enumerate(("C5", "E5", "G5", "B5")):
        out = mix_at(out, bell(note(nm), 0.28, sr, tau=0.08, harm2=0.25), i * 0.11, sr, gain=0.7 + 0.08 * i)
    return reverb(out, sr, mix=0.2, decay=0.5, tail=0.15)


# ---------------------------------------------------------------------------
# Catalogo: nome file -> (funzione, sample rate, e' un loop?)
# L'ordine determina il seed (BASE_SEED + indice): NON riordinare le voci
# esistenti, aggiungere solo in coda.
# ---------------------------------------------------------------------------
SOUNDS: list[tuple[str, object, int, bool]] = [
    ("ui_click", sfx_ui_click, SR_UI, False),
    ("ui_hover", sfx_ui_hover, SR_UI, False),
    ("ui_open", sfx_ui_open, SR_UI, False),
    ("ui_close", sfx_ui_close, SR_UI, False),
    ("deco_place", sfx_deco_place, SR_UI, False),
    ("deco_remove", sfx_deco_remove, SR_UI, False),
    ("deco_rotate", sfx_deco_rotate, SR_UI, False),
    ("deco_scale", sfx_deco_scale, SR_UI, False),
    ("coin", sfx_coin, SR_UI, False),
    ("purchase", sfx_purchase, SR_UI, False),
    ("eat", sfx_eat, SR_UI, False),
    ("drink", sfx_drink, SR_UI, False),
    ("clean_start", sfx_clean_start, SR_UI, False),
    ("clean_done", sfx_clean_done, SR_UI, False),
    ("clean_loop_broom", sfx_clean_loop_broom, SR_UI, True),
    ("clean_loop_vacuum", sfx_clean_loop_vacuum, SR_UI, True),
    ("sit", sfx_sit, SR_UI, False),
    ("stand", sfx_stand, SR_UI, False),
    ("save", sfx_save, SR_UI, False),
    ("toast", sfx_toast, SR_UI, False),
    ("badge", sfx_badge, SR_UI, False),
    ("cat_purr_loop", sfx_cat_purr_loop, SR_HI, True),
    ("cat_meow", sfx_cat_meow, SR_UI, False),
    ("cat_hiss", sfx_cat_hiss, SR_UI, False),
    ("thunder_far", sfx_thunder_far, SR_HI, False),
    ("thunder_near", sfx_thunder_near, SR_HI, False),
    ("mess_spawn", sfx_mess_spawn, SR_UI, False),
    ("pet_fed", sfx_pet_fed, SR_UI, False),
    ("trust_up", sfx_trust_up, SR_UI, False),
]

# Alcuni one-shot devono essere volutamente piu' tenui degli altri
PEAK_OVERRIDE_DB = {
    "ui_hover": -9.0,
    "mess_spawn": -8.0,
    "thunder_far": -6.0,
}


def render(name: str, fn, sr: int, is_loop: bool, index: int) -> np.ndarray:
    rng = np.random.default_rng(BASE_SEED + index)
    x = np.asarray(fn(sr, rng), dtype=np.float64)
    if not is_loop:
        x = edge_fade(x, sr)
    peak_db = PEAK_DB_LOOP if is_loop else PEAK_OVERRIDE_DB.get(name, PEAK_DB_ONESHOT)
    return normalize(x, peak_db)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=OUT_DIR, help="cartella di output (default: %(default)s)")
    ap.add_argument("--only", default="", help="lista di nomi separati da virgola da rigenerare")
    ap.add_argument("--list", action="store_true", help="elenca i suoni e esci")
    args = ap.parse_args(argv)

    if args.list:
        for name, _fn, sr, is_loop in SOUNDS:
            print(f"{name:22s} {sr} Hz {'loop' if is_loop else 'one-shot'}")
        return 0

    wanted = {s.strip() for s in args.only.split(",") if s.strip()}
    args.out.mkdir(parents=True, exist_ok=True)
    for index, (name, fn, sr, is_loop) in enumerate(SOUNDS):
        if wanted and name not in wanted:
            continue
        x = render(name, fn, sr, is_loop, index)
        path = args.out / f"{name}.wav"
        write_wav(path, x, sr)
        print(f"{name:22s} {len(x) / sr:6.3f} s  {sr} Hz  peak {20 * math.log10(np.max(np.abs(x)) + 1e-12):5.1f} dBFS  -> {path.relative_to(REPO_ROOT) if path.is_relative_to(REPO_ROOT) else path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
