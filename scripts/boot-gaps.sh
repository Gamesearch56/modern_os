#!/usr/bin/env bash
# Read a boot log, a Hyprland log, or both, and name the gaps that put a
# laptop panel back on its firmware picture. A report runs this so the
# next bundle says which gap happened. --strict is for the test suite:
# a real report must still be collected when a gap is present.
set -euo pipefail

strict=0
files=()
for arg in "$@"; do
    case "$arg" in
        --strict) strict=1 ;;
        --) ;;
        *) files+=("$arg") ;;
    esac
done

if [ "${#files[@]}" -eq 0 ]; then
    files=(-)
fi

text="$(cat "${files[@]}" 2>/dev/null || true)"
found=0
note() {
    printf 'boot-gap: %s\n' "$1"
    found=1
}

if printf '%s\n' "$text" | grep -q "unknown parameter 'fastboot'" \
    || printf '%s\n' "$text" | grep -q 'i915.fastboot'; then
    note "i915.fastboot is set, and this kernel ignores it"
fi
if printf '%s\n' "$text" | grep -q 'getCurrentCRTC: No CRTC'; then
    note "compositor started with no CRTC, so the panel was not scanning"
fi
if printf '%s\n' "$text" | grep -q 'Cannot commit when a page-flip is awaiting'; then
    note "a frame was dropped because a page-flip was still in flight"
fi
if printf '%s\n' "$text" | grep -q 'Disabled KMS output'; then
    note "the previous compositor turned the display off as it exited"
fi

if [ "$found" -eq 0 ]; then
    printf 'boot-gap: none\n'
fi
[ "$strict" -eq 0 ] || [ "$found" -eq 0 ]
