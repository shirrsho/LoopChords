"""Generates two short metronome click samples.

Run from project root:  python3 tool/generate_clicks.py

Writes 16-bit mono WAVs with a fast exponential decay:
  assets/audio/tick.wav  -> accented downbeat (higher pitch)
  assets/audio/tock.wav  -> other beats (lower pitch)
"""
import math
import os
import struct
import wave

OUT_DIR = "assets/audio"
RATE = 44100
DURATION = 0.045  # seconds
DECAY_TAU = 0.009  # envelope time constant


def write_click(path, freq):
    n = int(RATE * DURATION)
    frames = bytearray()
    for i in range(n):
        t = i / RATE
        env = math.exp(-t / DECAY_TAU)
        # main tone plus a touch of a higher partial for a sharper "click"
        sample = (
            0.85 * math.sin(2 * math.pi * freq * t)
            + 0.15 * math.sin(2 * math.pi * freq * 2 * t)
        ) * env
        val = max(-1.0, min(1.0, sample))
        frames += struct.pack("<h", int(val * 32767))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    print("Wrote", path, f"({n} frames)")


os.makedirs(OUT_DIR, exist_ok=True)
write_click(f"{OUT_DIR}/tick.wav", 1500)
write_click(f"{OUT_DIR}/tock.wav", 900)
