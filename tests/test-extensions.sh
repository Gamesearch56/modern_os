#!/usr/bin/env bash
# Extensions stay outside the clone. An unmodded start does not wrap
# the shell. A release clone is immutable around an update; a branch
# checkout is not.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-extensions: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-extensions: ok %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-ext-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
chmod +x "$ROOT/scripts/extension-apply.sh" "$ROOT/scripts/repo-protect.sh"

# --- unmodded shell start is exactly qs -c modern -----------------------
cat >"$TMP/qs" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$STUB_DIR/qs.args"
exit 0
EOF
cat >"$TMP/bwrap" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$STUB_DIR/bwrap.args"
while [ $# -gt 0 ]; do
    if [ "$1" = -- ]; then
        shift
        exec "$@"
    fi
    shift
done
exit 1
EOF
chmod +x "$TMP/qs" "$TMP/bwrap"
mkdir -p "$TMP/share" "$TMP/state" "$TMP/run" "$TMP/config/quickshell/modern"
printf '0\n' >"$TMP/codes"
STUB_DIR="$TMP" XDG_DATA_HOME="$TMP/share" XDG_STATE_HOME="$TMP/state" \
    XDG_RUNTIME_DIR="$TMP/run" XDG_CONFIG_HOME="$TMP/config" \
    MODERN_SHELL_CMD="$TMP/qs" MODERN_SHELL_ALIVE=/bin/true \
    MODERN_BWRAP="$TMP/bwrap" "$ROOT/scripts/shell-run.sh"
if [ "$(cat "$TMP/qs.args")" = "-c modern" ] && [ ! -e "$TMP/bwrap.args" ]; then
    ok "a missing extensions folder starts qs -c modern without bubblewrap"
else
    err "unmodded start: qs=$(cat "$TMP/qs.args" 2>/dev/null) bwrap=$(cat "$TMP/bwrap.args" 2>/dev/null)"
fi

# --- overlay prefers the user's file and does not write the clone -------
REPO="$TMP/repo"
SHIP="$REPO/stow/shell/.config/quickshell/modern"
mkdir -p "$SHIP/Modules/Viewer"
printf 'shipped-stage\n' >"$SHIP/Modules/Viewer/Stage.qml"
printf 'shipped-shell\n' >"$SHIP/shell.qml"
EXT="$TMP/share/modern/extensions/stow/shell/.config/quickshell/modern"
mkdir -p "$EXT/Modules/Viewer"
printf 'mod-stage\n' >"$EXT/Modules/Viewer/Stage.qml"
chmod 700 "$TMP/share/modern/extensions"
before="$(find "$REPO" -printf '%p %s\n' | sort | md5sum)"
overlay="$(MODERN_REPO="$REPO" XDG_DATA_HOME="$TMP/share" XDG_STATE_HOME="$TMP/state" \
    "$ROOT/scripts/extension-apply.sh" overlay)"
after="$(find "$REPO" -printf '%p %s\n' | sort | md5sum)"
stage="$(readlink "$overlay/Modules/Viewer/Stage.qml")"
shell="$(readlink "$overlay/shell.qml")"
if [ "$before" = "$after" ] && [ "$stage" = "$EXT/Modules/Viewer/Stage.qml" ] \
    && [ "$shell" = "$SHIP/shell.qml" ]; then
    ok "the overlay uses the mod and leaves the clone unchanged"
else
    err "overlay: stage=$stage shell=$shell same=$([ "$before" = "$after" ] && echo yes || echo no)"
fi

# bubblewrap is asked to bind that overlay, and qs is still -c modern
rm -f "$TMP/qs.args" "$TMP/bwrap.args"
mkdir -p "$TMP/config/quickshell/modern"
STUB_DIR="$TMP" XDG_DATA_HOME="$TMP/share" XDG_STATE_HOME="$TMP/state" \
    XDG_RUNTIME_DIR="$TMP/run" XDG_CONFIG_HOME="$TMP/config" \
    MODERN_REPO="$REPO" MODERN_SHELL_CMD="$TMP/qs" MODERN_SHELL_ALIVE=/bin/true \
    MODERN_BWRAP="$TMP/bwrap" "$ROOT/scripts/shell-run.sh"
if [ "$(cat "$TMP/qs.args")" = "-c modern" ] && grep -Fq -- "--bind $overlay" "$TMP/bwrap.args"; then
    ok "a modded start binds the overlay and still runs qs -c modern"
else
    err "modded start: qs=$(cat "$TMP/qs.args" 2>/dev/null) bwrap=$(cat "$TMP/bwrap.args" 2>/dev/null)"
fi

# --- refused shapes -------------------------------------------------------
refuse() {
    local name="$1"
    shift
    if ! "$@" >/dev/null 2>"$TMP/err"; then
        ok "$name"
    else
        err "$name was accepted ($(cat "$TMP/err" 2>/dev/null))"
    fi
}
scripts_root="$TMP/refuse-scripts/modern/extensions"
mkdir -p "$scripts_root/scripts"
printf 'x\n' >"$scripts_root/scripts/evil.sh"
chmod 700 "$scripts_root"
refuse "a scripts path" env XDG_DATA_HOME="$TMP/refuse-scripts" \
    "$ROOT/scripts/extension-apply.sh" overlay

link_root="$TMP/refuse-link/modern/extensions"
mkdir -p "$link_root/stow/hypr/.config/hypr"
ln -s /tmp "$link_root/stow/hypr/.config/hypr/escaped"
chmod 700 "$link_root"
refuse "a symlink" env XDG_DATA_HOME="$TMP/refuse-link" \
    "$ROOT/scripts/extension-apply.sh" overlay

open_root="$TMP/refuse-open/modern/extensions"
mkdir -p "$open_root"
chmod 770 "$open_root"
refuse "a group-writable folder" env XDG_DATA_HOME="$TMP/refuse-open" \
    "$ROOT/scripts/extension-apply.sh" overlay

# --- release clone is locked around the checkout; a branch is not -------
HOME_DIR="$TMP/home"
CLONE="$HOME_DIR/modern_os"
REMOTE="$TMP/remote.git"
mkdir -p "$HOME_DIR"
git_cfg() { git -c core.hooksPath=/dev/null -c user.email=t@e -c user.name=t "$@"; }
git_cfg init -q --bare "$REMOTE"
git_cfg clone -q "$REMOTE" "$CLONE" 2>/dev/null || true
mkdir -p "$CLONE/install"
printf 'keep\n' >"$CLONE/install/keep"
git_cfg -C "$CLONE" add -A
git_cfg -C "$CLONE" commit -qm v0.1.0
git_cfg -C "$CLONE" tag -a v0.1.0 -m v0.1.0
git_cfg -C "$CLONE" push -q origin HEAD:refs/heads/main v0.1.0
printf 'next\n' >>"$CLONE/install/keep"
git_cfg -C "$CLONE" add -A
git_cfg -C "$CLONE" commit -qm v0.1.1
git_cfg -C "$CLONE" tag -a v0.1.1 -m v0.1.1
git_cfg -C "$CLONE" push -q origin v0.1.1
git_cfg -C "$CLONE" checkout -q --detach v0.1.0

cat >"$TMP/chattr" <<EOF
#!/bin/sh
tag="\$(git -C "$CLONE" -c core.hooksPath=/dev/null describe --tags --exact-match 2>/dev/null || echo none)"
printf '%s %s\n' "\$1" "\$tag" >>"$TMP/chattr.log"
exit 0
EOF
chmod +x "$TMP/chattr"
: >"$TMP/chattr.log"
HOME="$HOME_DIR" XDG_RUNTIME_DIR="$TMP/run" XDG_CONFIG_HOME="$TMP/config" \
    MODERN_TEST_FIXTURE=1 MODERN_DESKTOP_REPO="$CLONE" MODERN_DESKTOP_REMOTE="$REMOTE" \
    MODERN_CHATTR="$TMP/chattr" "$ROOT/scripts/desktop-sync.sh" apply >/dev/null
first="$(head -n 1 "$TMP/chattr.log")"
last="$(tail -n 1 "$TMP/chattr.log")"
head_now="$(git -C "$CLONE" describe --tags --exact-match)"
if [ "$first" = "-i v0.1.0" ] && [ "$last" = "+i v0.1.1" ] && [ "$head_now" = v0.1.1 ]; then
    ok "a release clone is unlocked for the checkout and locked again"
else
    err "protect log: first=$first last=$last head=$head_now"
fi

git_cfg -C "$CLONE" checkout -q -B dev v0.1.1
: >"$TMP/chattr.log"
HOME="$HOME_DIR" XDG_RUNTIME_DIR="$TMP/run" MODERN_TEST_FIXTURE=1 \
    MODERN_DESKTOP_REPO="$CLONE" MODERN_CHATTR="$TMP/chattr" \
    "$ROOT/scripts/repo-protect.sh" lock
HOME="$HOME_DIR" XDG_RUNTIME_DIR="$TMP/run" MODERN_TEST_FIXTURE=1 \
    MODERN_DESKTOP_REPO="$CLONE" MODERN_CHATTR="$TMP/chattr" \
    "$ROOT/scripts/repo-protect.sh" unlock
if [ ! -s "$TMP/chattr.log" ]; then
    ok "a branch checkout is left writable"
else
    err "a branch was marked: $(cat "$TMP/chattr.log")"
fi

[ "$FAIL" -eq 0 ] || exit 1
printf 'test-extensions: ok\n'
