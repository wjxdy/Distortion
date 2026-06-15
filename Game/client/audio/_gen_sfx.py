#!/usr/bin/env python3
# 用标准库合成占位音效（零依赖、无需联网）。运行：python3 _gen_sfx.py
# 输出到本目录：blip.wav（对话出字）、click.wav（按钮）、reveal.wav（真相碎片）。
import wave, struct, math, random, os

SR = 44100
OUT = os.path.dirname(os.path.abspath(__file__))

def write_wav(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        data = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32767)
            data += struct.pack("<h", v)
        w.writeframes(bytes(data))
    print("wrote", name, "(%.2fs)" % (len(samples) / SR))

def blip():
    n = int(SR * 0.07)
    return [0.35 * math.sin(2 * math.pi * 880 * i / SR) * math.exp(-i / n * 5.0) for i in range(n)]

def click():
    n = int(SR * 0.03)
    return [0.30 * math.sin(2 * math.pi * 1500 * i / SR) * math.exp(-i / n * 8.0) for i in range(n)]

def reveal():
    # 记忆裂开：低频下坠 + 高频微光 + 一点噪声，整体衰减，赛博味
    n = int(SR * 0.6)
    out = []
    for i in range(n):
        t = i / SR
        p = i / n
        f = 220.0 * (1 - p) + 60.0 * p
        low = 0.40 * math.sin(2 * math.pi * f * t)
        shimmer = 0.15 * math.sin(2 * math.pi * 1320 * t) * math.exp(-p * 6.0)
        noise = 0.08 * (random.random() * 2 - 1) * math.exp(-p * 10.0)
        out.append((low + shimmer + noise) * math.exp(-p * 2.5))
    return out

if __name__ == "__main__":
    write_wav("blip.wav", blip())
    write_wav("click.wav", click())
    write_wav("reveal.wav", reveal())
    print("done ->", OUT)
