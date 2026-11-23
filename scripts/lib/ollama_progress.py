#!/usr/bin/env python3
"""Turn Ollama's cursor-drawn pull log into plain lines on stdout."""
import re
import sys

_ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
_BAR = re.compile(r"[\u2800-\u28FF\u2580-\u259F]")
# One line per layer per whole percent. Byte and speed updates on the
# same percent are how a pull used to fill the settings window.
_LAYER = re.compile(r"^pulling\s+(\S+):\s+(\d+)%")


def clean(frame):
    text = _BAR.sub("", _ANSI.sub("", frame))
    return re.sub(r"[ \t]+", " ", text).strip()


def emit(frame, last, last_pct):
    text = clean(frame)
    if not text or text == last[0]:
        return
    layer = _LAYER.match(text)
    if layer:
        key = (layer.group(1), layer.group(2))
        if key == last_pct[0]:
            return
        last_pct[0] = key
        text = "pulling %s: %s%%" % (layer.group(1), layer.group(2))
    print(text, flush=True)
    last[0] = text


def main():
    data = ""
    last = [""]
    last_pct = [None]
    while True:
        chunk = sys.stdin.read(256)
        if not chunk:
            break
        data += chunk
        parts = re.split(r"\n|\r|\x1b\[1G", data)
        data = parts.pop()
        for part in parts:
            emit(part, last, last_pct)
    emit(data, last, last_pct)
    return 0


if __name__ == "__main__":
    sys.exit(main())
