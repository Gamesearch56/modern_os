#!/usr/bin/env python3
"""Turn Ollama's cursor-drawn pull log into plain lines on stdout."""
import re
import sys

_ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
_BAR = re.compile(r"[\u2800-\u28FF\u2580-\u259F]")


def clean(frame):
    text = _BAR.sub("", _ANSI.sub("", frame))
    return re.sub(r"[ \t]+", " ", text).strip()


def emit(frame, last):
    text = clean(frame)
    if not text or text == last[0]:
        return
    print(text, flush=True)
    last[0] = text


def main():
    data = ""
    last = [""]
    while True:
        chunk = sys.stdin.read(256)
        if not chunk:
            break
        data += chunk
        parts = re.split(r"\n|\x1b\[1G", data)
        data = parts.pop()
        for part in parts:
            emit(part, last)
    emit(data, last)
    return 0


if __name__ == "__main__":
    sys.exit(main())
