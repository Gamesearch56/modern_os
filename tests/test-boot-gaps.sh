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

if grep -Fq 'MODERN_SEAT_KEEP_CRTC=1' "$KIOSK" \
    && grep -Fq 'seat-nomodeset.so' "$KIOSK" \
    && grep -Fq 'seat-nomodeset.so' "$DESKTOP" \
    && ! grep -Fq 'MODERN_SEAT_KEEP_CRTC=1' "$DESKTOP" \
    && grep -Fq '_plymouth_release_master' "$COVER" \
    && grep -Fq '_copy_scanning_picture' "$COVER" \
    && grep -Fq '_prepare_splash_copies' "$COVER" \
    && grep -Fq 'flipping the splash copied before Plymouth let go' "$COVER" \
    && grep -Fq 'choose_scanning_fb' "$COVER" \
    && grep -Fq 'copying the splash plane, not the firmware framebuffer' "$COVER" \
    && grep -Fq 'install_image_seat' "$ROOT/iso/airootfs/usr/lib/modern/calamares-late.sh" \
    && grep -Fq 'seat-cover.next' "$ROOT/scripts/iso-build.sh"; then
    ok "login keeps the CRTC and the installed system gets this image's handoff"
else
    err "the greeter must keep the CRTC, and the ISO must install that handoff over the release pin"
fi

if python3 -c '
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
start = text.find("def _first_adopt")
body = text[start:text.find("\ndef ", start + 1)]
prep = body.find("_prepare_splash_copies")
drop = body.find("_plymouth_release_master")
sys.exit(0 if 0 < prep < drop else 1)
' "$COVER"; then
    ok "the splash is copied before Plymouth drops the display"
else
    err "the splash copy must happen before Plymouth drops master, or the copy is the firmware logo"
fi

if command -v gcc >/dev/null 2>&1 && pkg-config --exists libdrm; then
    work="$(mktemp -d)"
    cat >"$work/drv.c" <<'EOF'
#include <dlfcn.h>
int main(void) {
    void *h = dlopen("./seat-nomodeset.so", RTLD_NOW);
    int (*ok)(void);
    if (!h)
        return 1;
    ok = dlsym(h, "modern_seat_layout_ok");
    return ok && ok() == 1 ? 0 : 2;
}
EOF
    read -r -a drm_cflags < <(pkg-config --cflags --libs libdrm)
    if gcc -shared -fPIC -O2 -Wall -Wextra -Wl,-z,defs -pthread \
        -o "$work/seat-nomodeset.so" \
        "$ROOT/install/system/greetd/seat-nomodeset.c" \
        "${drm_cflags[@]}" \
        && gcc -O2 -o "$work/drv" "$work/drv.c" -ldl \
        && (cd "$work" && ./drv); then
        ok "login handoff helper matches this libdrm"
    else
        err "login handoff helper failed to compile or its libdrm layout probe failed"
    fi
    rm -rf "$work"
fi

if MODERN_SEAT_COVER=0 python3 "$COVER" hold \
    && MODERN_SEAT_COVER=0 python3 "$COVER" pin \
    && grep -Fq 'def pin' "$COVER" \
    && grep -Fq 'KillMode=process' "$ROOT/install/system/plymouth/modern-splash-pin.service"; then
    ok "seat cover can be turned off without touching the display"
else
    err "MODERN_SEAT_COVER=0 must skip the display"
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-boot-gaps-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cat >"$TMP/bad.txt" <<'EOF'
initrd=\initramfs-linux-zen.img quiet splash i915.fastboot=1
kernel: i915: unknown parameter 'fastboot' ignored
seat-cover: display already scanning
ERR from aquamarine ]: drm: getCurrentCRTC: No CRTC 0
ERR from aquamarine ]: drm: Cannot commit when a page-flip is awaiting
drm: Disabled KMS output eDP-1 before disconnect
EOF
bad="$("$GAPS" "$TMP/bad.txt" || true)"
if printf '%s\n' "$bad" | grep -Fq 'i915.fastboot is set' \
    && printf '%s\n' "$bad" | grep -Fq 'no CRTC' \
    && printf '%s\n' "$bad" | grep -Fq 'page-flip was still in flight' \
    && printf '%s\n' "$bad" | grep -Fq 'turned the display off' \
    && printf '%s\n' "$bad" | grep -Fq 'panel connector without a CRTC'; then
    ok "a boot log like the reported one names each gap"
else
    err "bad log was not fully reported: $bad"
fi
if "$GAPS" --strict "$TMP/bad.txt" >/dev/null 2>&1; then
    err "strict mode must fail when a gap is present"
else
    ok "strict mode fails a log that still has the gaps"
fi

# The match is on the first line and the rest is larger than a pipe
# buffer, so a SIGPIPE from grep -q used to hide it.
{
    printf '%s\n' 'ERR from aquamarine ]: drm: getCurrentCRTC: No CRTC 0'
    dd if=/dev/zero bs=1024 count=256 status=none | tr '\0' 'x'
    printf '\n'
} >"$TMP/long.txt"
long="$("$GAPS" "$TMP/long.txt" || true)"
if printf '%s\n' "$long" | grep -Fq 'no CRTC'; then
    ok "a long boot log still reports a missing CRTC"
else
    err "long log hid the gap: $long"
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
    && grep -Fq 'seat-cover:' "$ROOT/scripts/lib/bug-report-session.sh" \
    && grep -Fq 'modern-splash-pin' "$ROOT/scripts/lib/bug-report-session.sh"; then
    ok "a report keeps the kernel handover and the seat-cover line"
else
    err "bug reports still drop the lines that identify this gap"
fi

[ "$FAIL" -eq 0 ] || exit 1
printf 'test-boot-gaps: ok\n'
