#!/usr/bin/env bash
# The library can still install a private runner. The system update does
# not: install.sh must not download it. A failed fetch must not fail.
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ok() { printf 'test-ge-proton: ok %s\n' "$1"; }
err() {
    printf 'test-ge-proton: FAIL %s\n' "$1" >&2
    FAIL=1
}

INSTALL="$ROOT/install/install.sh"
BN="$ROOT/scripts/battlenet"
if ! grep -Fq 'ge_proton_ensure' "$INSTALL" \
    && ! grep -Fq 'ge-proton.sh' "$INSTALL" \
    && ! grep -Fq 'ge_proton_dir' "$BN"; then
    ok "the system update does not download GE-Proton"
else
    err "install.sh or battlenet still fetches a private GE-Proton"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
LOG_FILE="$tmp/install.log"
export LOG_FILE
# shellcheck source=../install/lib/log.sh
source "$ROOT/install/lib/log.sh"
# shellcheck source=../install/lib/ge-proton.sh
source "$ROOT/install/lib/ge-proton.sh"

fixture="$tmp/GE-Proton11-12-x86_64.tar.gz"
stage="$tmp/stage/GE-Proton11-12-x86_64"
mkdir -p "$stage"
printf 'GE-Proton11-12\n' >"$stage/version"
printf '#!/bin/sh\nexit 0\n' >"$stage/proton"
chmod +x "$stage/proton"
tar -C "$tmp/stage" -czf "$fixture" GE-Proton11-12-x86_64
# Same runner layout, different bytes, so a skipped checksum would install it.
tampered="$tmp/tampered.tar.gz"
tamper_stage="$tmp/tamper/GE-Proton11-12-x86_64"
mkdir -p "$tamper_stage"
printf 'GE-Proton11-12\n' >"$tamper_stage/version"
printf '#!/bin/sh\nexit 0\n' >"$tamper_stage/proton"
chmod +x "$tamper_stage/proton"
printf 'tampered\n' >"$tamper_stage/extra"
tar -C "$tmp/tamper" -czf "$tampered" GE-Proton11-12-x86_64
GE_PROTON_SHA512="$(sha512sum "$fixture" | awk '{print $1}')"
export GE_PROTON_SHA512
GE_PROTON_URL="https://proton.test/GE-Proton11-12-x86_64.tar.gz"
export GE_PROTON_URL

# ok: real archive. fail: DNS/transfer error. bad: bytes that miss the pin.
CURL_MODE=ok
curl() {
    local out=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -o)
                out="$2"
                shift 2
                ;;
            *) shift ;;
        esac
    done
    printf 'x\n' >>"$tmp/curls"
    if [ "$CURL_MODE" = "fail" ]; then
        printf 'Could not resolve host github.com\n' >&2
        rm -f "$out"
        return 6
    fi
    if [ "$CURL_MODE" = "bad" ]; then
        cp "$tampered" "$out"
        return 0
    fi
    cp "$fixture" "$out"
}

home="$tmp/home"
if ge_proton_ensure "$home" && ge_proton_ensure "$home"; then
    if [ "$(wc -l <"$tmp/curls")" -eq 1 ] \
        && [ -x "$home/.local/share/modern/proton/GE-Proton11-12-x86_64/proton" ] \
        && grep -Fq 'GE-Proton11-12' "$home/.local/share/modern/proton/GE-Proton11-12-x86_64/version"; then
        ok "GE-Proton11-12 is installed once and reused"
    else
        err "install was not idempotent"
    fi
else
    err "ge_proton_ensure failed"
fi

CURL_MODE=fail
DRY_RUN=0
offline="$tmp/offline"
# Bare call, as install.sh does. An `if` would disable set -e inside the function.
set +e
(
    set -euo pipefail
    ge_proton_ensure "$offline"
)
offline_rc=$?
set -euo pipefail
if [ "$offline_rc" -ne 0 ]; then
    err "a failed GE-Proton download must not fail ge_proton_ensure (rc $offline_rc)"
elif [ -e "$offline/.local/share/modern/proton/GE-Proton11-12-x86_64" ] \
    || [ -e "$offline/.cache/modern/GE-Proton11-12-x86_64.tar.gz" ] \
    || [ -e "$offline/.cache/modern/GE-Proton11-12-x86_64.tar.gz.part" ]; then
    err "failed download must not leave a runner or archive"
elif ! grep -Fq 'continuing without it' "$LOG_FILE"; then
    err "failed download must log a warning and continue"
else
    ok "failed GitHub download does not fail the install"
fi

CURL_MODE=ok
if ge_proton_ensure "$offline" \
    && [ -x "$offline/.local/share/modern/proton/GE-Proton11-12-x86_64/proton" ] \
    && grep -Fq 'GE-Proton11-12' "$offline/.local/share/modern/proton/GE-Proton11-12-x86_64/version"; then
    ok "GE-Proton downloads once the host resolves"
else
    err "GE-Proton must still install after a failed download"
fi

CURL_MODE=bad
bad="$tmp/bad"
set +e
(
    set -euo pipefail
    ge_proton_ensure "$bad"
)
bad_rc=$?
set -euo pipefail
if [ "$bad_rc" -eq 0 ]; then
    err "checksum mismatch must still fail the step"
elif [ -e "$bad/.local/share/modern/proton/GE-Proton11-12-x86_64" ]; then
    err "checksum mismatch must not install a runner"
else
    ok "checksum mismatch still aborts the step"
fi
CURL_MODE=ok

DRY_RUN=1
rm -rf "$home"
if ge_proton_ensure "$home" && [ ! -e "$home/.local/share/modern/proton/GE-Proton11-12-x86_64" ]; then
    ok "dry-run does not download GE-Proton"
else
    err "dry-run must not install GE-Proton"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-ge-proton: ok\n'
