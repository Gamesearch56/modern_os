#!/usr/bin/env bash
# pacman-conf.sh keeps installer options under [options] and repairs a
# pacman.conf where an older installer appended them to a repo section.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-pacman-conf: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-pacman-conf: ok %s\n' "$*"; }

# shellcheck source=../scripts/lib/pacman-conf.sh
source "$ROOT/scripts/lib/pacman-conf.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
conf="$TMP/pacman.conf"

stock() {
    printf '[options]\nHoldPkg = pacman glibc\nDownloadUser = alpm\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n\n[extra]\nInclude = /etc/pacman.d/mirrorlist\n' >"$conf"
}

section_of() {
    awk -v want="$1" '/^\[/ { s = $0 } $0 == want { print s; exit }' "$conf"
}

stock
pacman_conf_set "$conf" "DisableSandbox"
pacman_conf_set "$conf" "DisableSandbox"
if [ "$(section_of DisableSandbox)" = "[options]" ] && [ "$(grep -c '^DisableSandbox$' "$conf")" -eq 1 ]; then
    ok "an option goes under [options], once"
else
    err "pacman_conf_set misplaced or duplicated: $(cat "$conf")"
fi

stock
sed -i 's/^DownloadUser = alpm/#DownloadUser = alpm/' "$conf"
printf '\n%s\nDisableSandbox\n\nNoExtract = etc/resolv.conf\n\nIgnorePkg = jack2\n\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' \
    "$PACMAN_CONF_SANDBOX_NOTE" >>"$conf"
pacman_conf_repair "$conf"
if [ "$(section_of 'NoExtract = etc/resolv.conf')" = "[options]" ] \
    && [ "$(section_of 'IgnorePkg = jack2')" = "[options]" ] \
    && [ "$(section_of 'DownloadUser = alpm')" = "[options]" ] \
    && ! grep -q 'DisableSandbox' "$conf" \
    && grep -q '^\[multilib\]' "$conf"; then
    ok "repair moves options out of [extra] and drops the chroot-only lines"
else
    err "repair result: $(cat "$conf")"
fi
before="$(cat "$conf")"
pacman_conf_repair "$conf"
[ "$before" = "$(cat "$conf")" ] || err "repair must leave a clean file alone"

grep -Fq 'pacman_conf_repair' "$ROOT/scripts/update-apply.sh" \
    || err "the system update must repair pacman.conf"

if [ "$FAIL" -eq 0 ]; then
    ok "done"
else
    exit 1
fi
