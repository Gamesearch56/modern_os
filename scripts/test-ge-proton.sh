#!/usr/bin/env bash
# install.sh fetches a private GE-Proton for Battle.net, and a second
# run does not download it again.
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
if grep -Fq 'ge_proton_ensure "$TARGET"' "$INSTALL" \
    && grep -Fq 'install/lib/ge-proton.sh' "$INSTALL" \
    && grep -Fq 'ge_proton_dir "$HOME"' "$BN"; then
    ok "install places GE-Proton and battlenet prefers that private runner"
else
    err "install.sh must call ge_proton_ensure and battlenet must use ge_proton_dir"
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
GE_PROTON_SHA512="$(sha512sum "$fixture" | awk '{print $1}')"
export GE_PROTON_SHA512
GE_PROTON_URL="https://proton.test/GE-Proton11-12-x86_64.tar.gz"
export GE_PROTON_URL

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
