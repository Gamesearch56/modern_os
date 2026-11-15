#!/usr/bin/env bash
# scripts/wow-forever prints a gamescope HDR command and keeps Proton on
# X11 inside that container. It does not start the game.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ok() { printf 'test-wow-forever: ok %s\n' "$1"; }
err() {
    printf 'test-wow-forever: FAIL %s\n' "$1" >&2
    FAIL=1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/.config/modern" "$tmp/prefix/drive_c"

exe="$tmp/prefix/drive_c/Wow.exe"
printf 'exe\n' >"$exe"
printf '%s\n' 'PROTON_ENABLE_WAYLAND=1' >"$tmp/home/.config/modern/battlenet.env"
printf '%s\n' '{"input":{"kbLayout":"de","kbVariant":"nodeadkeys"},"monitors":{"primaryDescription":"Panel","profiles":{"Panel":{"mode":"2560x1440@143.91","sdr_max_luminance":250}}}}' \
    >"$tmp/home/.config/modern/config.json"

cat >"$tmp/bin/gamescope" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$tmp/bin/umu-run" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$tmp/bin/gamescope" "$tmp/bin/umu-run"

run() {
    env -u STEAM_COMPAT_DATA_PATH -u WINEPREFIX -u PROTONPATH -u GAMEID \
        HOME="$tmp/home" \
        XDG_CONFIG_HOME="$tmp/home/.config" \
        XDG_DATA_HOME="$tmp/home/.local/share" \
        XDG_STATE_HOME="$tmp/home/.local/state" \
        PATH="$tmp/bin:/usr/bin:/bin" \
        WOW_DRY_RUN=1 \
        "$ROOT/scripts/wow-forever"
}

out="$(WOW_EXE="$exe" run)"
check() {
    local label="$1" pattern="$2"
    if printf '%s\n' "$out" | grep -q -- "$pattern"; then
        ok "$label"
    else
        err "$label"
    fi
}
check wayland 'PROTON_ENABLE_WAYLAND=0'
check dxvk 'DXVK_HDR=1'
check wsi 'ENABLE_HDR_WSI=1'
check proton-hdr 'PROTON_ENABLE_HDR=1'
check hdr-enabled '--hdr-enabled'
check backend '--backend wayland'
check width '-w 2560'
check height '-h 1440'
check nits '--hdr-sdr-content-nits 250'
check force-output '--hdr-debug-force-output'
check steam-client 'STEAM_COMPAT_CLIENT_INSTALL_PATH='
check inside '--inside'
if printf '%s\n' "$out" | grep -Fq -- "$exe"; then
    ok 'launches wow directly'
else
    err 'launches wow directly'
fi
if printf '%s\n' "$out" | grep -Eq 'Battle\.net\.exe|-launcherlogin'; then
    err 'no battlenet launch'
else
    ok 'no battlenet launch'
fi
check layout 'XKB_DEFAULT_LAYOUT=de'
check variant 'XKB_DEFAULT_VARIANT=nodeadkeys'
game_line="$(printf '%s\n' "$out" | grep -E '^(gamemoderun|gamescope) ' || true)"
if printf '%s\n' "$game_line" | grep -Fq -- "$exe"; then
    err 'host command embeds the exe'
else
    ok 'exe stays inside'
fi

if WOW_EXE="$tmp/missing.exe" run >/dev/null 2>&1; then
    err 'missing exe should fail'
else
    ok 'missing exe'
fi

# shellcheck source=lib/wow-hdr.sh
source "$ROOT/scripts/lib/wow-hdr.sh"
hdr="$tmp/Config.wtf"
printf 'SET Gamma "1"\r\nSET HDROutput "0"\r\n' >"$hdr"
WOW_CONFIG="$hdr" wow_hdr_apply on 1000
if grep -q 'SET HDROutput "1"' "$hdr" \
    && grep -q 'SET HDRPeakBrightness "1000"' "$hdr" \
    && grep -q 'SET useHDRBrightness "1"' "$hdr" \
    && grep -q 'SET Gamma "1"' "$hdr" \
    && grep -q $'\r' "$hdr"; then
    ok 'hdr on'
else
    err 'hdr on'
fi
WOW_CONFIG="$hdr" wow_hdr_apply off
if grep -q 'SET HDROutput "0"' "$hdr" \
    && grep -q 'SET useHDRBrightness "0"' "$hdr" \
    && grep -q 'SET useHDRPeakBrightness "0"' "$hdr" \
    && grep -q 'SET Gamma "1"' "$hdr"; then
    ok 'hdr off'
else
    err 'hdr off'
fi
lock="$tmp/wow-hdr.lock"
WOW_HDR_LOCK="$lock" bash -c 'exec 9>"$WOW_HDR_LOCK"; flock 9; sleep 2' &
sleep 0.2
WOW_HDR_LOCK="$lock" WOW_CONFIG="$hdr" wow_hdr_apply on 1000
WOW_HDR_ASSUME_IDLE=1 WOW_HDR_LOCK="$lock" WOW_CONFIG="$hdr" wow_hdr_off_if_idle
if grep -q 'SET HDROutput "1"' "$hdr"; then
    ok 'lock holds hdr'
else
    err 'lock holds hdr'
fi
wait || true

if command -v gcc >/dev/null 2>&1 && [ -f /usr/include/X11/Xatom.h ]; then
    clipbin="$tmp/xclipboard"
    if gcc -O2 -o "$clipbin" "$ROOT/scripts/lib/xclipboard.c" -lX11 -lXfixes; then
        if env DISPLAY= "$clipbin" get >/dev/null 2>&1; then
            err 'clipboard without display'
        else
            ok 'clipboard helper builds'
        fi
    else
        err 'clipboard helper builds'
    fi
elif command -v gcc >/dev/null 2>&1; then
    printf 'test-wow-forever: skip clipboard helper (no X11 headers)\n'
fi

if [ "$FAIL" -ne 0 ]; then
    printf '%s\n' "$out" >&2
    exit 1
fi
