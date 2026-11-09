"""Generate Nhịp's original, short two-note confirmation chime (no external audio)."""
from pathlib import Path
import math
import struct
import wave


def make_sound(destination: Path) -> None:
    rate = 44100
    duration = 0.70
    notes = [(0.0, 1318.51, 0.23), (0.115, 1760.0, 0.31)]
    samples = []
    for index in range(round(rate * duration)):
        time = index / rate
        value = 0.0
        for onset, frequency, amplitude in notes:
            age = time - onset
            if age < 0:
                continue
            attack = min(1.0, age / 0.006)
            decay = math.exp(-age / 0.105)
            bell = (math.sin(2 * math.pi * frequency * age)
                    + 0.18 * math.sin(2 * math.pi * frequency * 2.76 * age)
                    + 0.06 * math.sin(2 * math.pi * frequency * 4.08 * age))
            value += amplitude * attack * decay * bell
        tail = min(1.0, max(0.0, (duration - time) / 0.025))
        samples.append(round(max(-1.0, min(1.0, value * tail)) * 32767))
    with wave.open(str(destination), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(rate)
        audio.writeframes(struct.pack("<" + "h" * len(samples), *samples))


if __name__ == "__main__":
    make_sound(Path(__file__).with_name("CheckInSuccess.wav"))
