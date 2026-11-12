#!/usr/bin/env python3
"""Generate the same preview notification sounds used by the Android build workflow.

The Flutter pubspec declares assets/tones/, which must exist in a fresh CI checkout.
This generator produces only short ORIGINAL alert signals, not commercial media.
"""
import math
import struct
import wave
from pathlib import Path

OUT = Path("assets/tones")
OUT.mkdir(parents=True, exist_ok=True)
SAMPLE_RATE = 22050
TONES = {
    "urgent": [(880, .16), (0, .09), (1100, .18), (0, .08), (880, .23)],
    "news": [(523, .22), (659, .22), (784, .32)],
    "soft": [(392, .36), (523, .40)],
    "default": [(660, .18), (0, .08), (660, .22)],
}
for name, notes in TONES.items():
    samples = []
    for frequency, duration in notes:
        count = int(SAMPLE_RATE * duration)
        for i in range(count):
            fade = min(1, i / (SAMPLE_RATE * .015), (count - i) / (SAMPLE_RATE * .045))
            value = 0 if frequency == 0 else math.sin(2 * math.pi * frequency * i / SAMPLE_RATE) * max(0, fade) * .3
            samples.append(struct.pack("<h", int(value * 32767)))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(SAMPLE_RATE)
        target.writeframes(b"".join(samples))
print(f"Generated {len(TONES)} notification sounds in {OUT}")
