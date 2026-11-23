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

# grep -q on a pipe exits at the first match. With pipefail the writer's
# SIGPIPE makes a long log look clean, which is how a real report said
# "none" while Hyprland had already logged no CRTC.
has() {
    local rc=0
    set +e +o pipefail
    printf '%s\n' "$text" | grep -q -- "$1"
    rc=$?
    set -e -o pipefail
    [ "$rc" -eq 0 ]
}

if has "unknown parameter 'fastboot'" || has 'i915.fastboot'; then
    note "i915.fastboot is set, and this kernel ignores it"
fi
if has 'getCurrentCRTC: No CRTC'; then
    note "compositor started with no CRTC, so the panel was not scanning"
fi
if { has 'display already scanning' || has 'seat-cover: painted' || has 'seat-cover: frame held' \
        || has 'seat-cover: keeping live scanout' || has 'seat-cover: replaced scanout'; } \
    && has 'getCurrentCRTC: No CRTC'; then
    note "a cover left the panel connector without a CRTC"
fi
if has 'seat-cover: pin left the splash frame untouched'; then
    note "the splash pin did not program a frame before the login screen"
fi
if has 'Cannot commit when a page-flip is awaiting'; then
    note "a frame was dropped because a page-flip was still in flight"
fi
if has 'Disabled KMS output'; then
    note "the previous compositor turned the display off as it exited"
fi

if [ "$found" -eq 0 ]; then
    printf 'boot-gap: none\n'
fi
[ "$strict" -eq 0 ] || [ "$found" -eq 0 ]
