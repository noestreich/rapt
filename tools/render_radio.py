"""Rendert die Funksprüche aller Figuren als MP3 für die Webseite (Python-Spiegel von App/Sources/Audio/RadioVoice.swift).
Aufruf: python3 tools/render_radio.py [Takes pro Figur, Standard 3]   (benötigt numpy und ffmpeg)
Ausgabe: docs/assets/web/funk/funk_<name>_<take>.mp3"""
import json
import math
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/assets/web/funk"
SR = 44100.0
MASK = (1 << 64) - 1


class Rng:
    def __init__(self, seed):
        self.s = seed & MASK

    def unit(self):
        self.s = (self.s + 0x9E3779B97F4A7C15) & MASK
        z = self.s
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK
        return ((z ^ (z >> 31)) >> 11) / float(1 << 53)


class Res:
    def __init__(self):
        self.y1 = self.y2 = self.b1 = self.b2 = self.g = 0.0

    def tune(self, f, bw):
        r = math.exp(-math.pi * bw / SR)
        self.b1, self.b2, self.g = 2 * r * math.cos(2 * math.pi * f / SR), -r * r, 1 - r

    def __call__(self, x):
        y = self.g * x + self.b1 * self.y1 + self.b2 * self.y2
        self.y2, self.y1 = self.y1, y
        return y


VOWELS = [(800, 1200), (450, 1900), (300, 2300), (500, 900), (350, 800)]


def spec(style="human", pitch=150, speed=1, melody=0.15, vibrato=0, formant=1, breath=0.1, ring=0):
    return dict(style=style, pitch=pitch, speed=speed, melody=melody, vibrato=vibrato, formant=formant, breath=breath, ring=ring)


BASE = {  # wie Contact.swift
    "kira": spec(pitch=290, speed=1.3, melody=0.25, formant=1.3, breath=0.15),
    "boris": spec(pitch=95, speed=0.85, melody=0.1, formant=0.88, breath=0.08),
    "juki": spec(pitch=320, speed=1.45, melody=0.32, formant=1.33, breath=0.2),
    "zora": spec(pitch=215, speed=0.95, melody=0.16, vibrato=0.04, formant=1.16, breath=0.25),
    "k9": spec("dog", pitch=150),
    "robo": spec("robot", pitch=110, speed=1, melody=0, ring=0.7),
}
PRESETS = {
    "mann": spec(pitch=110, speed=0.95, melody=0.12, formant=0.92, breath=0.08),
    "mann-tief": spec(pitch=85, speed=0.85, melody=0.1, formant=0.85, breath=0.08),
    "frau": spec(pitch=210, speed=1.0, melody=0.18, formant=1.15, breath=0.2),
    "maedchen": spec(pitch=300, speed=1.35, melody=0.28, formant=1.3, breath=0.15),
    "junge": spec(pitch=250, speed=1.3, melody=0.25, formant=1.22, breath=0.12),
    "alt": spec(pitch=150, speed=0.85, melody=0.14, vibrato=0.06, formant=1.05, breath=0.3),
    "hund": spec("dog", pitch=150),
    "katze": spec("cat", pitch=420, breath=0.12),
    "roboter": spec("robot", pitch=110, speed=1, melody=0, ring=0.7),
}
WEBNAME = {"kira": "kira", "boris": "boris", "juki": "juki", "zora": "mama-zora", "k9": "k-9", "robo": "robo-7"}


def append(part, out, level):
    p = np.asarray(part, dtype=float)
    peak = max(1e-4, float(np.abs(p).max()) if len(p) else 1)
    out.extend((p / peak * level).tolist())


def silence(sec):
    return [0.0] * int(sec * SR)


def human(v, rng):
    out, phase = [], 0.0
    f1, f2, f3 = Res(), Res(), Res()
    syl = 5 + int(rng.unit() * 5)
    for s in range(syl):
        length = (0.07 + rng.unit() * 0.06) / v["speed"]
        n = int(length * SR)
        vow = VOWELS[int(rng.unit() * 5) % 5]
        contour = 1 + v["melody"] * (rng.unit() - 0.5) * 2 - 0.08 * s / syl
        cons = rng.unit() < 0.6
        fm = v["formant"]
        f1.tune(vow[0] * fm, 90 * fm); f2.tune(vow[1] * fm, 120 * fm); f3.tune(2600 * fm, 200)
        soft = min(1, max(0, (fm - 1) * 3))
        part = []
        for i in range(n):
            t = i / SR
            f0 = v["pitch"] * contour * (1 + v["vibrato"] * math.sin(t * 2 * math.pi * 6))
            phase += f0 / SR
            saw = 2 * (phase - math.floor(phase)) - 1
            tri = 4 * abs(phase - math.floor(phase + 0.5)) - 1
            src = saw * (1 - soft * 0.6) + tri * soft * 0.6 + (rng.unit() * 2 - 1) * v["breath"]
            x = f1(src) + f2(src) * 0.6 + f3(src) * 0.25
            if cons and t < 0.018:
                x = (rng.unit() * 2 - 1) * 0.35 * (1 - t / 0.018)
            part.append(x * min(1, t / 0.01) * min(1, (length - t) / 0.02))
        append(part, out, 0.55 + rng.unit() * 0.25)
        out += silence((0.07 if rng.unit() < 0.25 else 0.015) / v["speed"])
    return out


def dog(v, rng):
    out = []
    f1, f2 = Res(), Res()
    for _ in range(3 + int(rng.unit() * 3)):
        pick, part, phase = rng.unit(), [], 0.0
        if pick < 0.55:
            length = 0.1 + rng.unit() * 0.06
            start = v["pitch"] * (2.6 + rng.unit() * 0.8)
            f1.tune(650, 180); f2.tune(1400, 260)
            for i in range(int(length * SR)):
                t = i / SR
                phase += start * (1 - 0.45 * t / length) / SR
                saw = 2 * (phase - math.floor(phase)) - 1
                src = saw * 0.7 + (rng.unit() * 2 - 1) * 0.5
                part.append((f1(src) + f2(src) * 0.7) * min(1, t / 0.004) * math.exp(-t * 14))
            append(part, out, 0.85); out += silence(0.06 + rng.unit() * 0.08)
        elif pick < 0.85:
            length = 0.25 + rng.unit() * 0.2
            f1.tune(380, 150); f2.tune(900, 250)
            for i in range(int(length * SR)):
                t = i / SR
                phase += v["pitch"] * 0.65 * (1 + 0.1 * math.sin(t * 40)) / SR
                saw = 2 * (phase - math.floor(phase)) - 1
                rough = 0.55 + 0.45 * math.sin(t * 2 * math.pi * 27)
                src = (saw + (rng.unit() * 2 - 1) * 0.3) * rough
                part.append((f1(src) + f2(src) * 0.5) * min(1, t / 0.03) * min(1, (length - t) / 0.05))
            append(part, out, 0.6); out += silence(0.04)
        else:
            length = 0.22 + rng.unit() * 0.1
            for i in range(int(length * SR)):
                t = i / SR
                phase += (v["pitch"] * 5 + 300 * math.sin(math.pi * t / length)) / SR
                part.append(math.sin(2 * math.pi * phase) * math.sin(math.pi * t / length))
            append(part, out, 0.5); out += silence(0.05)
    return out


def cat(v, rng):
    out = []
    f1, f2 = Res(), Res()
    for _ in range(2 + int(rng.unit() * 3)):
        pick, part, phase = rng.unit(), [], 0.0
        if pick < 0.6:
            length = 0.3 + rng.unit() * 0.25
            base = v["pitch"] * (0.9 + rng.unit() * 0.3)
            for i in range(int(length * SR)):
                t = i / SR
                u = t / length
                a = math.sin(math.pi * min(1, u * 1.6))
                fa = 350 + 650 * a if u < 0.6 else 900 - 500 * (u - 0.6) / 0.4
                fb = 2400 - 900 * a if u < 0.6 else 1500 - 600 * (u - 0.6) / 0.4
                if i % 64 == 0:
                    f1.tune(fa * 1.2, 140); f2.tune(fb * 1.2, 200)
                phase += base * (1 + 0.45 * math.sin(math.pi * min(1, u * 1.3))) / SR
                saw = 2 * (phase - math.floor(phase)) - 1
                src = saw * 0.8 + (rng.unit() * 2 - 1) * v["breath"]
                part.append((f1(src) + f2(src) * 0.7) * min(1, t / 0.02) * min(1, (length - t) / 0.08))
            append(part, out, 0.75); out += silence(0.08 + rng.unit() * 0.1)
        elif pick < 0.8:
            length = 0.14 + rng.unit() * 0.05
            f1.tune(500, 160); f2.tune(1300, 220)
            for i in range(int(length * SR)):
                t = i / SR
                phase += v["pitch"] * (0.8 + 0.6 * t / length) / SR
                saw = 2 * (phase - math.floor(phase)) - 1
                roll = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 32)
                part.append((f1(saw * roll) + f2(saw * roll) * 0.6) * min(1, t / 0.01) * min(1, (length - t) / 0.03))
            append(part, out, 0.6); out += silence(0.06)
        else:
            length = 0.45 + rng.unit() * 0.2
            f1.tune(220, 120)
            for i in range(int(length * SR)):
                t = i / SR
                pulse = max(0, math.sin(t * 2 * math.pi * 24)) ** 3
                part.append(f1((rng.unit() * 2 - 1) * pulse) * math.sin(math.pi * t / length))
            append(part, out, 0.5); out += silence(0.05)
    return out


def robot(v, rng):
    out = []
    f1, f2 = Res(), Res()
    steps = [1, 1, 1.5, 2, 0.75]
    syl = 6 + int(rng.unit() * 5)
    ring = 0.0
    for s in range(syl):
        length = 0.09 / v["speed"]
        f0 = v["pitch"] * steps[int(rng.unit() * 5) % 5]
        vow = VOWELS[int(rng.unit() * 5) % 5]
        f1.tune(vow[0], 60); f2.tune(vow[1], 80)
        part, phase = [], 0.0
        for i in range(int(length * SR)):
            t = i / SR
            phase += f0 / SR
            sq = 1.0 if phase - math.floor(phase) < 0.5 else -1.0
            x = f1(sq) + f2(sq) * 0.7
            ring += 330 / SR
            x *= (1 - v["ring"]) + v["ring"] * math.sin(2 * math.pi * ring)
            part.append(x if t < length * 0.85 else 0)
        append(part, out, 0.7)
        if s % 3 == 2 or rng.unit() < 0.2:
            freq = 1200 + rng.unit() * 900
            append([math.sin(2 * math.pi * freq * i / SR) for i in range(int(0.04 * SR))], out, 0.45)
        out += silence(0.02 / v["speed"])
    return out


def radio(inp):
    rng = Rng((len(inp) * 2654435761) & MASK)
    sq = int(0.06 * SR)
    out = [(rng.unit() * 2 - 1) * 0.35 * (1 - i / sq) + (0.6 if i < 40 else 0) for i in range(sq)]
    hp = lp1 = lp2 = last = held = 0.0
    a_high = math.exp(-2 * math.pi * 450 / SR)
    a_low = 1 - math.exp(-2 * math.pi * 2800 / SR)
    for i, x in enumerate(inp):
        hp = a_high * (hp + x - last); last = x
        lp1 += a_low * (hp - lp1); lp2 += a_low * (lp1 - lp2)
        y = math.tanh(lp2 * 2.6)
        if i % 3 == 0:
            held = round(y * 20) / 20
        out.append((held + (rng.unit() * 2 - 1) * 0.025) * 0.8)
    out += [(rng.unit() * 2 - 1) * 0.3 * (1 - i / sq) + (-0.5 if i < 30 else 0) for i in range(sq)]
    return out


def render(v, seed):
    rng = Rng(seed)
    return radio({"human": human, "dog": dog, "cat": cat, "robot": robot}[v["style"]](v, rng))


def main():
    takes = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    OUT.mkdir(parents=True, exist_ok=True)
    holders = json.loads((ROOT / "App/Resources/portraits.json").read_text())
    ids = sorted({i for v in holders.values() for i in v})
    for cid in ids:
        parts = cid.split("--")
        v = PRESETS.get(parts[2], BASE[parts[0]]) if len(parts) == 3 else BASE[cid]
        name = parts[1] if len(parts) == 3 else WEBNAME[cid]
        for k in range(1, takes + 1):
            seed = sum(map(ord, cid)) * 7919 + k
            pcm = np.clip(np.asarray(render(v, seed)), -1, 1)
            wav = OUT / f"funk_{name}_{k}.wav"
            with wave.open(str(wav), "wb") as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(int(SR))
                w.writeframes((pcm * 32000).astype("<i2").tobytes())
            mp3 = wav.with_suffix(".mp3")
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-ac", "1", "-b:a", "96k", str(mp3)], check=True)
            wav.unlink()
            print(mp3.relative_to(ROOT))


if __name__ == "__main__":
    main()
