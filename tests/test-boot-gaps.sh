#!/usr/bin/env bash
# The firmware logo comes back when the panel has no CRTC. These checks
# do not modeset: they read the cmdline we generate, the handoff scripts,
# and a copy of the lines from a real boot log.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-boot-gaps: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-boot-gaps: ok %s\n' "$*"; }

APPLY="$ROOT/install/system/plymouth/apply.sh"
COVER="$ROOT/install/system/greetd/seat-cover.py"
GAPS="$ROOT/scripts/boot-gaps.sh"
KIOSK="$ROOT/install/system/greetd/kiosk.sh"
DESKTOP="$ROOT/install/system/greetd/desktop-session.sh"
GREETD="$ROOT/install/system/greetd/config.toml"
BOOT="$ROOT/iso/airootfs/etc/calamares/modules/bootloader.conf"

before_exec() {
    awk '
        /seat-cover\.py/ { cover = NR }
        /^exec / && /start-hyprland/ { exec_at = NR }
        END { exit !(cover && exec_at && cover < exec_at) }
    ' "$1"
}

# switch=false makes greetd wait until VT 1 is already active, so a boot
# that is not on VT 1 never reaches the login screen.
if ! grep -Fq 'i915.fastboot=1' "$APPLY" \
    && grep -Fq 'i915.enable_psr=0' "$APPLY" \
    && grep -Fq 'i915.enable_psr=0' "$BOOT" \
    && ! grep -q 'i915.fastboot' "$BOOT" \
    && ! grep -Fq 'switch = false' "$GREETD" \
    && before_exec "$KIOSK" \
    && before_exec "$DESKTOP" \
    && grep -Fq 'seat-cover.py' "$ROOT/install/lib/greetd.sh" \
    && ! grep -Fq 'Conflicts=plymouth-quit' "$KIOSK" \
    && ! grep -Fq 'display-handoff' "$DESKTOP"; then
    ok "the handoff paints a frame, drops master, and does not hold Plymouth"
else
    err "cmdline, greetd switch, or seat cover is missing"
fi

if python3 "$COVER" --self-test >/dev/null; then
    ok "seat cover struct sizes match this kernel and a read-only probe works"
else
    err "seat-cover --self-test failed"
fi

if MODERN_SEAT_COVER=0 python3 "$COVER" hold; then
    ok "seat cover can be turned off without touching the display"
else
    err "MODERN_SEAT_COVER=0 must skip the display"
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-boot-gaps-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cat >"$TMP/bad.txt" <<'EOF'
initrd=\initramfs-linux-zen.img quiet splash i915.fastboot=1
kernel: i915: unknown parameter 'fastboot' ignored
ERR from aquamarine ]: drm: getCurrentCRTC: No CRTC 0
ERR from aquamarine ]: drm: Cannot commit when a page-flip is awaiting
drm: Disabled KMS output eDP-1 before disconnect
EOF
bad="$("$GAPS" "$TMP/bad.txt" || true)"
if printf '%s\n' "$bad" | grep -Fq 'i915.fastboot is set' \
    && printf '%s\n' "$bad" | grep -Fq 'no CRTC' \
    && printf '%s\n' "$bad" | grep -Fq 'page-flip was still in flight' \
    && printf '%s\n' "$bad" | grep -Fq 'turned the display off'; then
    ok "a boot log like the reported one names each gap"
else
    err "bad log was not fully reported: $bad"
fi
if "$GAPS" --strict "$TMP/bad.txt" >/dev/null 2>&1; then
    err "strict mode must fail when a gap is present"
else
    ok "strict mode fails a log that still has the gaps"
fi

printf '%s\n' 'quiet splash i915.enable_psr=0' 'seat-cover: display already scanning' >"$TMP/clean.txt"
clean="$("$GAPS" --strict "$TMP/clean.txt")"
if [ "$clean" = "boot-gap: none" ]; then
    ok "a covered boot has no gap"
else
    err "clean log: $clean"
fi

if grep -Fq 'boot-gaps.sh' "$ROOT/scripts/lib/bug-report-session.sh" \
    && grep -Fq 'journalctl -b -k' "$ROOT/scripts/lib/bug-report-session.sh" \
    && grep -Fq 'seat-cover:' "$ROOT/scripts/lib/bug-report-session.sh"; then
    ok "a report keeps the kernel handover and the seat-cover line"
else
    err "bug reports still drop the lines that identify this gap"
fi

[ "$FAIL" -eq 0 ] || exit 1
printf 'test-boot-gaps: ok\n'
