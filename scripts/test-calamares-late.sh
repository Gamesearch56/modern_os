#!/usr/bin/env bash
# Hermetic calamares-late.sh clone tests. No root, no GitHub.
# shellcheck disable=SC2015
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATE="$ROOT/iso/airootfs/usr/lib/modern/calamares-late.sh"
FAIL=0
err() { printf 'test-calamares-late: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-calamares-late: ok %s\n' "$*"; }

[ -x "$LATE" ] || { err "missing $LATE"; exit 1; }

if grep -F 'DisableSandbox' "$LATE" >/dev/null \
    && grep -F -- '--disable-sandbox' "$LATE" >/dev/null \
    && grep -F 'pacman --disable-sandbox -Sy --noconfirm archlinux-keyring' "$LATE" >/dev/null \
    && grep -F 'pacman-key --init' "$LATE" >/dev/null \
    && grep -F 'pacman-key --populate archlinux' "$LATE" >/dev/null \
    && grep -F '[multilib]' "$LATE" >/dev/null \
    && grep -F 'sudo pacman --disable-sandbox -S --needed --noconfirm' "$LATE" >/dev/null \
    && grep -F 'matugen-bin' "$LATE" >/dev/null \
    && grep -F 'bibata-cursor-theme-bin' "$LATE" >/dev/null \
    && grep -F 'overlay_pin_aur_names' "$LATE" >/dev/null \
    && grep -F 'bibata-cursor-theme([[:space:]]|#|$)' "$LATE" >/dev/null \
    && grep -F 'NoExtract = etc/resolv.conf etc/nsswitch.conf' "$LATE" >/dev/null \
    && grep -F 'chattr +i' "$LATE" >/dev/null \
    && grep -F 'ensure_pipewire_jack' "$LATE" >/dev/null \
    && grep -F 'pipewire-jack' "$LATE" >/dev/null \
    && grep -F 'IgnorePkg' "$LATE" >/dev/null \
    && grep -F 'overlay_pin_install_native' "$LATE" >/dev/null \
    && grep -F 'modern ISO pin overlay' "$LATE" >/dev/null; then
    ok "desktop phase syncs pacman databases, enables multilib, patches pin pacman"
else
    err "desktop phase must init the target keyring, IgnorePkg jack2, overlay pin install_native, and pacman -Sy before install.sh"
fi

if grep -F 'install.sh --profile m0 --yes failed' "$LATE" >/dev/null \
    && grep -F 'install/install.log' "$LATE" >/dev/null \
    && grep -E 'tail -n 40' "$LATE" >/dev/null; then
    ok "desktop phase puts install.sh stdout and install.log in the error dialog"
else
    err "desktop phase must dump install.sh output on failure (Calamares hides stderr)"
fi

if grep -F 'install -d -m 0750 /etc /etc/sudoers.d' "$LATE" >/dev/null; then
    err "desktop phase must not chmod /etc to 0750 (gitconfig EACCES)"
elif grep -F 'chmod a+rx /etc' "$LATE" >/dev/null \
    && grep -F 'install -d -m 0750 /etc/sudoers.d' "$LATE" >/dev/null; then
    ok "desktop phase leaves /etc world-executable"
else
    err "desktop phase must chmod a+rx /etc and only 0750 sudoers.d"
fi

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

run_late() {
    local -a extra=()
    if [ -n "${MODERN_LATE_CLONE_URL:-}" ]; then
        extra+=(MODERN_LATE_CLONE_URL="$MODERN_LATE_CLONE_URL")
    fi
    if [ -n "${MODERN_LATE_BUNDLE:-}" ]; then
        extra+=(MODERN_LATE_BUNDLE="$MODERN_LATE_BUNDLE")
    fi
    if [ -n "${MODERN_LATE_RESOLV:-}" ]; then
        extra+=(MODERN_LATE_RESOLV="$MODERN_LATE_RESOLV")
    fi
    if [ -n "${MODERN_LATE_NSSWITCH:-}" ]; then
        extra+=(MODERN_LATE_NSSWITCH="$MODERN_LATE_NSSWITCH")
    fi
    env -u MODERN_PROTECT_HOME \
        MODERN_LATE_TEST=1 \
        MODERN_LATE_LOG="$WORKDIR/late.log" \
        MODERN_LATE_PIN_FILE="$WORKDIR/iso-pin" \
        MODERN_LATE_USER_HOME="$WORKDIR/home" \
        MODERN_CALAMARES_USER=tester \
        "${extra[@]}" \
        bash "$LATE" "$@"
}

: >"$WORKDIR/iso-pin"
if out="$(run_late clone 2>&1)"; then
    err "empty pin must fail"
else
    printf '%s\n' "$out" | grep -q 'ISO pin is not a release tag' \
        && grep -q 'ISO pin is not a release tag' "$WORKDIR/late.log" \
        && ok "invalid pin dies on stdout and in the log" \
        || err "invalid pin message missing from stdout or log: $out"
fi

printf 'v0.0.99\n' >"$WORKDIR/iso-pin"
missing="$WORKDIR/missing.git"
git init -q --bare "$missing"
if out="$(MODERN_LATE_CLONE_URL="$missing" run_late clone 2>&1)"; then
    err "missing tag clone must fail"
else
    printf '%s\n' "$out" | grep -q 'git clone of v0.0.99 failed' \
        && ok "missing-tag clone reports git failure on stdout" \
        || err "clone failure not on stdout: $out"
fi

origin="$WORKDIR/origin.git"
git init -q --bare "$origin"
src="$WORKDIR/src"
git init -q "$src"
git -C "$src" config user.email test@example.com
git -C "$src" config user.name tester
git -C "$src" config commit.gpgsign false
mkdir -p "$src/install"
printf 'repo\n' >"$src/README"
git -C "$src" add README install
git -C "$src" commit -q -m "seed"
git -C "$src" tag v0.9.9
git -C "$src" push -q "$origin" v0.9.9

printf 'v0.9.9\n' >"$WORKDIR/iso-pin"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_CLONE_URL="$origin" run_late clone 2>&1)"; then
    [ -f "$WORKDIR/home/modern_dotfile/README" ] \
        && printf '%s\n' "$out" | grep -q 'cloned v0.9.9' \
        && ok "clone of local file:// tag lands the tree" \
        || err "clone succeeded but tree missing: $out"
else
    err "local tag clone failed: $out"
fi

bundle="$WORKDIR/bundle"
mkdir -p "$bundle/install"
printf 'from-bundle\n' >"$bundle/README"
printf 'v0.1.0\n' >"$WORKDIR/iso-pin"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$bundle" MODERN_LATE_CLONE_URL="$missing" run_late clone 2>&1)"; then
    [ -f "$WORKDIR/home/modern_dotfile/README" ] \
        && grep -q from-bundle "$WORKDIR/home/modern_dotfile/README" \
        && printf '%s\n' "$out" | grep -q 'using ISO bundle' \
        && ok "ISO bundle copy does not need git" \
        || err "bundle copy succeeded but tree missing: $out"
else
    err "ISO bundle copy failed: $out"
fi

dangling="$WORKDIR/etc/resolv.conf"
mkdir -p "$WORKDIR/etc"
ln -s "$WORKDIR/etc/missing-resolv" "$dangling"
printf 'v0.1.0\n' >"$WORKDIR/iso-pin"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$bundle" MODERN_LATE_RESOLV="$dangling" run_late clone 2>&1)"; then
    grep -q 'nameserver 1.1.1.1' "$dangling" \
        && [ ! -L "$dangling" ] \
        && ok "dangling resolv.conf symlink is replaced before write" \
        || err "resolv.conf still broken after clone: $(ls -l "$dangling" 2>&1) $out"
else
    err "clone with dangling resolv.conf failed: $out"
fi

stub="$WORKDIR/etc/stub-resolv.conf"
printf 'nameserver 127.0.0.53\noptions edns0 trust-ad\n' >"$stub"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$bundle" MODERN_LATE_RESOLV="$stub" run_late clone 2>&1)"; then
    grep -q 'nameserver 1.1.1.1' "$stub" \
        && ! grep -q '127.0.0.53' "$stub" \
        && ok "systemd stub nameserver is replaced with public DNS" \
        || err "stub resolv.conf not rewritten: $(cat "$stub") $out"
else
    err "clone with stub resolv.conf failed: $out"
fi

upstream="$WORKDIR/etc/upstream-resolv.conf"
printf 'nameserver 8.8.8.8\n' >"$upstream"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$bundle" MODERN_LATE_RESOLV="$upstream" run_late clone 2>&1)"; then
    grep -qx 'nameserver 8.8.8.8' "$upstream" \
        && ok "upstream nameserver is left in place" \
        || err "upstream resolv.conf was rewritten: $(cat "$upstream") $out"
else
    err "clone with upstream resolv.conf failed: $out"
fi

mixed="$WORKDIR/etc/mixed-resolv.conf"
printf 'nameserver 127.0.0.53\nnameserver 8.8.8.8\n' >"$mixed"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$bundle" MODERN_LATE_RESOLV="$mixed" run_late clone 2>&1)"; then
    grep -qx 'nameserver 8.8.8.8' "$mixed" \
        && ! grep -q '127.0.0.53' "$mixed" \
        && ok "loopback nameserver is stripped when an upstream exists" \
        || err "mixed resolv.conf not stripped: $(cat "$mixed") $out"
else
    err "clone with mixed resolv.conf failed: $out"
fi

nss="$WORKDIR/etc/nsswitch.conf"
printf 'passwd: files\nhosts: mymachines resolve [!UNAVAIL=return] files dns\n' >"$nss"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$bundle" MODERN_LATE_NSSWITCH="$nss" run_late clone 2>&1)"; then
    grep -qx 'hosts: files dns' "$nss" \
        && grep -q '^passwd: files' "$nss" \
        && ok "nsswitch hosts is files dns (not systemd-resolved)" \
        || err "nsswitch not rewritten: $(cat "$nss") $out"
else
    err "clone with nsswitch rewrite failed: $out"
fi

aur="$WORKDIR/20-theming.aur.txt"
printf '%s\n' \
    'matugen' \
    'bibata-cursor-theme     # gtk-cursor-theme-name' \
    'matugen-bin' \
    'bibata-cursor-theme-bin' >"$aur"
sed -i -E \
    -e 's/^[[:space:]]*matugen([[:space:]]|#|$)/matugen-bin\1/' \
    -e 's/^[[:space:]]*bibata-cursor-theme([[:space:]]|#|$)/bibata-cursor-theme-bin\1/' \
    "$aur"
if grep -qx 'matugen-bin' "$aur" \
    && grep -qE '^bibata-cursor-theme-bin[[:space:]]+#' "$aur" \
    && ! grep -qE '^matugen$' "$aur" \
    && ! grep -qE '^bibata-cursor-theme[[:space:]]' "$aur"; then
    ok "pin AUR rewrite maps commented bibata-cursor-theme to -bin"
else
    err "pin AUR rewrite missed comment-bearing bibata line: $(cat "$aur")"
fi

[ "$FAIL" -eq 0 ]
