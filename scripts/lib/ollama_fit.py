#!/usr/bin/env python3
"""How well an Ollama model fits the memory on this computer.

Q4-sized tags need about 0.55 GB per billion parameters, plus a little
context. A model that fits in graphics memory is a good fit. One that
fits in system memory with room left is also good when there is no
graphics memory to use. Anything tighter may run slowly. Past most of
the installed memory it will not load.
"""
import json
import re
import sys

_SIZE = re.compile(r"(\d+(?:\.\d+)?)b", re.IGNORECASE)


def params_b(name):
    tag = str(name or "").split(":", 1)[-1]
    found = [float(n) for n in _SIZE.findall(tag)]
    if not found:
        return None
    return max(found)


def weight_factor(name):
    text = str(name or "").lower()
    if "fp16" in text or "bf16" in text or "f16" in text:
        return 3.2
    if "q8" in text:
        return 1.8
    if "q2" in text or "q3" in text:
        return 0.7
    return 1.0


def need_gb(name):
    params = params_b(name)
    if params is None:
        return None
    return round(params * 0.55 * weight_factor(name) + 0.8, 1)


def rate(name, ram_bytes, vram_bytes):
    ram = float(ram_bytes or 0) / (1024 ** 3)
    vram = float(vram_bytes or 0) / (1024 ** 3)
    if vram < 2:
        vram = 0.0
    need = need_gb(name)
    if ram <= 0 or need is None:
        level, why = "unknown", "unknown"
    elif vram >= need:
        level, why = "good", "gpu"
    elif need > ram * 0.8:
        level, why = "poor", "poor"
    elif vram > 0 and need > vram:
        level, why = "maybe", "spill"
    elif need <= min(ram * 0.45, 6.5):
        level, why = "good", "ram"
    else:
        level, why = "maybe", "tight"
    return {
        "level": level,
        "why": why,
        "need": need if need is not None else 0,
        "ram": round(ram, 1),
        "vram": round(vram, 1),
    }


def main():
    if len(sys.argv) < 3:
        print("{}", end="")
        return 2
    try:
        ram = int(sys.argv[1])
        vram = int(sys.argv[2])
    except ValueError:
        print("{}", end="")
        return 2
    out = {}
    for name in sys.argv[3:]:
        if name:
            out[name] = rate(name, ram, vram)
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
