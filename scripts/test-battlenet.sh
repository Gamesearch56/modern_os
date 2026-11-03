#!/usr/bin/env bash
# scripts/battlenet against a fake home: finds an existing prefix without
# battlenet.env, installs into its own prefix on first start, and tells
# the user (notification) whenever it cannot start.
# Stub bodies are single-quoted on purpose: they expand when the stub runs.
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ok() { printf 'test-battlenet: ok %s\n' "$1"; }
err() {
    printf 'test-battlenet: FAIL %s\n' "$1" >&2
    FAIL=1
}

if command -v umu-run >/dev/null 2>&1; then
    printf 'test-battlenet: skip (a real umu-run is on PATH)\n'
    exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
EXE_REL="drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"

stub() {
    local name="$1" body="$2"
    printf '#!/usr/bin/env bash\n%s\n' "$body" >"$tmp/bin/$name"
    chmod +x "$tmp/bin/$name"
}

# Fresh home per case; $1 = space-separated stubs to provide.
reset() {
    rm -rf "${tmp:?}/home" "${tmp:?}/bin" "${tmp:?}/calls"
    mkdir -p "$tmp/home" "$tmp/bin" "$tmp/calls"
    stub notify-send 'printf "%s\n" "$*" >>"'"$tmp"'/calls/notify"'
    stub gamemoderun 'exec "$@"'
    local s
    for s in $1; do
        case "$s" in
            umu) stub umu-run 'printf "%s|%s\n" "$WINEPREFIX" "$*" >>"'"$tmp"'/calls/umu"' ;;
            umu-crash) stub umu-run 'exit 3' ;;
            curl) stub curl 'while [ $# -gt 0 ]; do [ "$1" = -o ] && { printf MZ >"$2"; }; shift; done; touch "'"$tmp"'/calls/curl"' ;;
            curl-fail) stub curl 'exit 6' ;;
        esac
    done
}

run() {
    local rc=0
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" LANG=C \
        XDG_CONFIG_HOME="$tmp/home/.config" "$ROOT/scripts/battlenet" >/dev/null 2>&1 || rc=$?
    printf '%s\n' "$rc"
}

reset "umu"
steam_pfx="$tmp/home/.local/share/Steam/steamapps/compatdata/4242/pfx"
mkdir -p "$(dirname "$steam_pfx/$EXE_REL")" && : >"$steam_pfx/$EXE_REL"
rc="$(run)"
if [ "$rc" = 0 ] && grep -Fq "$steam_pfx|$steam_pfx/$EXE_REL --in-process-gpu" "$tmp/calls/umu" 2>/dev/null; then
    ok "an install in a Steam prefix starts without battlenet.env"
else
    err "Steam prefix detection (rc $rc)"
fi

reset "umu curl"
rc="$(run)"
own="$tmp/home/.local/share/modern/battlenet/pfx"
if [ "$rc" = 0 ] && [ -f "$tmp/calls/curl" ] \
    && grep -Fq "$own|$tmp/home/.cache/modern/Battle.net-Setup.exe" "$tmp/calls/umu" 2>/dev/null \
    && grep -Fq 'not installed yet' "$tmp/calls/notify"; then
    ok "first start downloads the installer into its own prefix"
else
    err "first-start install (rc $rc)"
fi

reset "umu curl-fail"
rc="$(run)"
if [ "$rc" = 1 ] && [ ! -f "$tmp/calls/umu" ] && grep -Fq 'Could not download' "$tmp/calls/notify"; then
    ok "a failed download is reported"
else
    err "download failure (rc $rc)"
fi

reset ""
mkdir -p "$(dirname "$steam_pfx/$EXE_REL")" && : >"$steam_pfx/$EXE_REL"
rc="$(run)"
if [ "$rc" = 1 ] && grep -Fq 'umu-launcher' "$tmp/calls/notify"; then
    ok "no Proton runner is reported"
else
    err "missing runner (rc $rc)"
fi

reset "umu-crash"
mkdir -p "$(dirname "$steam_pfx/$EXE_REL")" && : >"$steam_pfx/$EXE_REL"
rc="$(run)"
if [ "$rc" = 1 ] && grep -Fq 'battlenet.log' "$tmp/calls/notify"; then
    ok "a client that dies at once points at the log"
else
    err "quick crash (rc $rc)"
fi

reset ""
mkdir -p "$(dirname "$steam_pfx/$EXE_REL")" && : >"$steam_pfx/$EXE_REL"
proton_dir="$tmp/home/.local/share/Steam/steamapps/common/Proton - Experimental"
mkdir -p "$proton_dir"
printf '#!/usr/bin/env bash\nprintf "%%s|%%s\\n" "$STEAM_COMPAT_DATA_PATH" "$*" >"%s/calls/proton"\n' "$tmp" >"$proton_dir/proton"
chmod +x "$proton_dir/proton"
rc="$(run)"
if [ "$rc" = 0 ] && grep -Fq "${steam_pfx%/pfx}|waitforexitandrun $steam_pfx/$EXE_REL" "$tmp/calls/proton" 2>/dev/null; then
    ok "without umu-run, Steam's Proton runs the client"
else
    err "Proton fallback (rc $rc)"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-battlenet: ok\n'
