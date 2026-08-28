#!/usr/bin/env bash
# Region OCR: select a screen rectangle, run tesseract, print text.
# grim+slurp own the capture; this script only glues them so Modules
# never spawn a process (layer rule).
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { printf 'ocr-region: missing %s\n' "$1" >&2; exit 1; }; }
need grim
need slurp
need tesseract

geom="$(slurp)" || exit 1
grim -g "$geom" - | tesseract stdin stdout 2>/dev/null
