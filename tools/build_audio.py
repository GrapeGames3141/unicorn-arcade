#!/usr/bin/env python3
"""Synthesize Unicorn Arcade's sound effects and music-box loop.

Everything is generated from simple bell/sine tones, so the audio is original
and license-free. Usage (from the repository root):

    python3 tools/build_audio.py          # needs numpy; ffmpeg for the .ogg

Outputs land in godot/assets/audio/.
"""
import subprocess
import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "godot" / "assets" / "audio"


def note(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def bell(freq: float, seconds: float, decay: float = 6.0, bright: float = 0.35) -> np.ndarray:
    """Music-box tone: fundamental plus two quickly fading partials."""
    t = np.arange(int(RATE * seconds)) / RATE
    tone = np.sin(2 * np.pi * freq * t) * np.exp(-decay * t)
    tone += bright * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-decay * 1.8 * t)
    tone += bright * 0.4 * np.sin(2 * np.pi * freq * 3.01 * t) * np.exp(-decay * 2.6 * t)
    attack = np.minimum(1.0, t / 0.004)
    return tone * attack


def soft(freq: float, seconds: float, decay: float = 5.0) -> np.ndarray:
    """Rounded, mellow tone for gentle 'try again' feedback."""
    t = np.arange(int(RATE * seconds)) / RATE
    tone = np.sin(2 * np.pi * freq * t) + 0.18 * np.sin(2 * np.pi * freq * 2 * t)
    return tone * np.exp(-decay * t) * np.minimum(1.0, t / 0.012)


def place(buffer: np.ndarray, tone: np.ndarray, start: float, gain: float = 1.0, wrap: bool = False) -> None:
    index = int(start * RATE)
    if wrap:
        positions = (index + np.arange(len(tone))) % len(buffer)
        np.add.at(buffer, positions, tone * gain)
    else:
        end = min(len(buffer), index + len(tone))
        buffer[index:end] += tone[: end - index] * gain


def finish(buffer: np.ndarray, peak: float) -> np.ndarray:
    fade = int(RATE * 0.01)
    buffer[-fade:] *= np.linspace(1.0, 0.0, fade)
    return buffer / np.max(np.abs(buffer)) * peak


def write_wav(name: str, buffer: np.ndarray) -> Path:
    path = OUT / name
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes((np.clip(buffer, -1, 1) * 32767).astype("<i2").tobytes())
    return path


def sequence(notes, step: float, length: float, tone=bell, tail: float = 0.5, **kwargs) -> np.ndarray:
    buffer = np.zeros(int(RATE * (step * len(notes) + tail)))
    for index, midi in enumerate(notes):
        place(buffer, tone(note(midi), length, **kwargs), index * step)
    return buffer


def build_effects() -> None:
    # Soft pluck for every button press.
    write_wav("tap.wav", finish(bell(note(76), 0.09, decay=38.0, bright=0.15), 0.35))
    # Rising two-note chime for a right answer.
    write_wav("correct.wav", finish(sequence([81, 88], 0.085, 0.4, decay=9.0, tail=0.35), 0.6))
    # Low, rounded double "boop" - noticeable but never scolding.
    write_wav("wrong.wav", finish(sequence([64, 59], 0.14, 0.3, tone=soft, tail=0.2, decay=9.0), 0.5))
    # Bright two-step coin sparkle.
    write_wav("coin.wav", finish(sequence([83, 88], 0.07, 0.45, decay=8.0, tail=0.4), 0.55))
    # Bubble pop for blasts and cleared tiles.
    t = np.arange(int(RATE * 0.11)) / RATE
    sweep = np.sin(2 * np.pi * (950 * t - 3000 * t * t)) * np.exp(-26 * t)
    write_wav("pop.wav", finish(sweep, 0.5))
    # Level complete: rising arpeggio that resolves on a sparkling high chord.
    win = sequence([72, 76, 79, 84], 0.11, 0.9, decay=4.0, tail=1.0)
    for midi in (84, 88, 91):
        place(win, bell(note(midi), 0.9, decay=3.5), 0.46, 0.5)
    write_wav("win.wav", finish(win, 0.7))
    # Try again: three mellow falling notes ending on a hopeful rise.
    write_wav("lose.wav", finish(sequence([67, 64, 60, 62], 0.17, 0.5, tone=soft, tail=0.45, decay=5.0), 0.5))


def build_music() -> None:
    """A calm 16-bar music-box lullaby that loops seamlessly."""
    beat = 60.0 / 80.0
    bars = 16
    total = int(RATE * beat * 4 * bars)
    music = np.zeros(total)
    # I - vi - IV - V with gentle variations; MIDI roots and chord tones.
    chords = [
        (48, [60, 64, 67, 72]), (45, [57, 60, 64, 69]), (41, [53, 57, 60, 65]), (43, [55, 59, 62, 67]),
        (48, [60, 64, 67, 72]), (45, [57, 60, 64, 69]), (41, [53, 57, 60, 65]), (43, [55, 59, 62, 67]),
        (41, [53, 57, 60, 65]), (48, [60, 64, 67, 72]), (50, [57, 62, 65, 69]), (43, [55, 59, 62, 67]),
        (48, [60, 64, 67, 72]), (45, [57, 60, 64, 69]), (41, [53, 57, 60, 65]), (43, [55, 59, 62, 67]),
    ]
    arpeggio = [0, 1, 2, 3, 2, 1, 2, 1]
    # Pentatonic melody, one phrase per four bars (None = rest), quarter notes.
    melody = [
        76, None, 79, 76, 72, None, 74, None, 69, None, 72, 74, 67, None, None, None,
        76, None, 79, 81, 84, None, 81, None, 79, None, 76, 74, 79, None, None, None,
        81, None, 79, 76, 79, None, 76, None, 74, None, 76, 77, 74, None, None, None,
        76, None, 79, 76, 72, None, 69, None, 72, None, 74, 71, 72, None, None, None,
    ]
    for bar, (root, tones) in enumerate(chords):
        start = bar * 4 * beat
        # Warm bass note and a slow chord pad under each bar.
        place(music, soft(note(root), beat * 3.6, decay=0.9), start, 0.22, wrap=True)
        t = np.arange(int(RATE * beat * 4.6)) / RATE
        swell = np.sin(np.pi * np.minimum(1.0, t / (beat * 4.6))) ** 2
        for midi in tones[:3]:
            place(music, np.sin(2 * np.pi * note(midi) * t) * swell, start - beat * 0.3, 0.035, wrap=True)
        for step, tone_index in enumerate(arpeggio):
            place(music, bell(note(tones[tone_index] + 12), 1.4, decay=3.2, bright=0.25), start + step * beat / 2, 0.16, wrap=True)
    for index, midi in enumerate(melody):
        if midi is not None:
            place(music, bell(note(midi + 12), 2.2, decay=2.2, bright=0.3), index * beat, 0.3, wrap=True)
    music = music / np.max(np.abs(music)) * 0.55
    wav = write_wav("music_meadow_loop.wav", music)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3",
                    str(OUT / "music_meadow_loop.ogg")], check=True)
    wav.unlink()


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    build_effects()
    build_music()
    print("Audio written to", OUT)
