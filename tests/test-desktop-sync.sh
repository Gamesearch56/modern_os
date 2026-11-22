#!/usr/bin/env bash
# Local bare-git fixture for desktop-sync.sh. No GitHub network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC="$ROOT/scripts/desktop-sync.sh"
FAIL=0

err() { printf 'test-desktop-sync: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-desktop-sync: ok %s\n' "$*"; }

command -v git >/dev/null 2>&1 || { echo "git required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-dsync-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-desktop-sync: refusing protected home" >&2; exit 1 ;;
    esac
fi

git_cfg() {
    git -c core.hooksPath=/dev/null "$@"
}

REMOTE="$TMP/remote.git"
CLONE="$TMP/clone"
git_cfg init --bare "$REMOTE" >/dev/null
git_cfg clone "$REMOTE" "$CLONE" >/dev/null
git_cfg -C "$CLONE" config user.email test@example.com
git_cfg -C "$CLONE" config user.name test
printf 'one\n' >"$CLONE/readme"
git_cfg -C "$CLONE" add readme
git_cfg -C "$CLONE" commit -m init >/dev/null
git_cfg -C "$CLONE" tag -a v0.1.0 -m v0.1.0
git_cfg -C "$CLONE" push origin HEAD >/dev/null
git_cfg -C "$CLONE" push origin v0.1.0 >/dev/null
printf 'two\n' >>"$CLONE/readme"
git_cfg -C "$CLONE" add readme
git_cfg -C "$CLONE" commit -m two >/dev/null
git_cfg -C "$CLONE" tag -a v0.2.0 -m v0.2.0
git_cfg -C "$CLONE" tag -a v0.2.0-rc1 -m rc
git_cfg -C "$CLONE" push origin HEAD >/dev/null
git_cfg -C "$CLONE" push origin v0.2.0 v0.2.0-rc1 >/dev/null
git_cfg -C "$CLONE" checkout --detach v0.1.0 >/dev/null 2>&1

export MODERN_TEST_FIXTURE=1
export MODERN_DESKTOP_REPO="$CLONE"
export MODERN_DESKTOP_REMOTE="$REMOTE"
export XDG_RUNTIME_DIR="$TMP"
export XDG_STATE_HOME="$TMP/state"

status_field() {
    "$SYNC" status | jq -r "$1"
}

if [ "$(status_field .pending)" != "true" ]; then
    err "behind v0.2.0 should be pending; got $("$SYNC" status)"
else
    ok "behind latest tag is pending"
fi
[ "$(status_field .from)" = "v0.1.0" ] || err "from should be v0.1.0"
[ "$(status_field .to)" = "v0.2.0" ] || err "to should ignore rc and pick v0.2.0"

"$SYNC" apply >/dev/null
cur="$(git_cfg -C "$CLONE" describe --tags --exact-match HEAD)"
[ "$cur" = "v0.2.0" ] || err "apply did not land on v0.2.0 (got $cur)"
[ "$(status_field .pending)" = "false" ] || err "at latest tag should not be pending"
[ "$(status_field .reason)" = "current" ] || err "reason should be current"
ok "apply fast-forwards to latest tag; then current"

printf 'dirt\n' >>"$CLONE/readme"
if [ "$(status_field .reason)" != "current" ] || [ "$(status_field .pending)" != "false" ]; then
    err "dirty tree should still report the release: $("$SYNC" status)"
else
    ok "dirty tree still reports the current release"
fi
if "$SYNC" apply >/dev/null 2>&1; then
    err "apply should refuse a dirty tree"
else
    ok "apply refuses dirty tree"
fi
git_cfg -C "$CLONE" checkout -- . >/dev/null

# Hyprland reloads when checkout unlinks the watched lua file. The
# pause has to land before that rewrite, and the watch comes back after.
watchlog="$TMP/hyprctl.log"
mkdir -p "$TMP/bin"
cat >"$TMP/bin/hyprctl" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >>"$watchlog"
if [ "\$1" = eval ] && printf '%s' "\$2" | grep -q 'disable_autoreload = true'; then
    cp "$CLONE/readme" "$TMP/readme-at-pause"
fi
exit 0
EOF
chmod +x "$TMP/bin/hyprctl"
git_cfg -C "$CLONE" checkout --detach v0.1.0 >/dev/null 2>&1
if PATH="$TMP/bin:$PATH" MODERN_TEST_HYPR_WATCH=1 "$SYNC" apply >/dev/null \
    && ! grep -q two "$TMP/readme-at-pause" \
    && grep -q two "$CLONE/readme" \
    && grep -q 'disable_autoreload = true' "$watchlog" \
    && grep -q 'disable_autoreload = false' "$watchlog"; then
    ok "checkout pauses the config watch before replacing files"
else
    err "config watch was not paused before checkout: $(cat "$watchlog" 2>/dev/null || true)"
fi

# A release checkout at ~/modern_os is the installed system. The
# ISO overlay dirties tracked files; apply must drop that and still
# refuse an untracked file.
old_home="$HOME"
old_repo="$MODERN_DESKTOP_REPO"
inst_home="$TMP/home"
mkdir -p "$inst_home"
cp -a "$CLONE" "$inst_home/modern_os"
export HOME="$inst_home"
export MODERN_DESKTOP_REPO="$inst_home/modern_os"
printf 'overlay\n' >>"$inst_home/modern_os/readme"
if "$SYNC" apply >/dev/null 2>"$TMP/apply-overlay.err"; then
    if ! grep -q overlay "$inst_home/modern_os/readme"; then
        ok "installed release checkout drops installer edits"
    else
        err "installer edit survived apply"
    fi
else
    err "installed release checkout refused installer edits: $(cat "$TMP/apply-overlay.err")"
fi
printf 'stray\n' >"$inst_home/modern_os/stray.txt"
if "$SYNC" apply >/dev/null 2>"$TMP/apply-stray.err"; then
    err "untracked file in the home clone should still refuse apply"
else
    ok "untracked file in the home clone still refuses apply"
fi
rm -f "$inst_home/modern_os/stray.txt"
export HOME="$old_home"
export MODERN_DESKTOP_REPO="$old_repo"

git_cfg -C "$CLONE" checkout -B feature/x >/dev/null 2>&1
printf 'feat\n' >>"$CLONE/readme"
git_cfg -C "$CLONE" add readme
git_cfg -C "$CLONE" commit -m feat >/dev/null
if [ "$(status_field .reason)" != "notag" ] || [ "$(status_field .pending)" != "false" ]; then
    err "feature branch should be notag / not pending: $("$SYNC" status)"
else
    ok "feature branch is not pending"
fi

# ISO install: shallow single-tag copy (iso-build.sh bundle). After one
# update the new tag must exist locally, or the next release is never offered.
SHALLOW="$TMP/shallow"
git_cfg clone --depth 1 --single-branch --branch v0.1.0 "file://$REMOTE" "$SHALLOW" >/dev/null 2>&1
export MODERN_DESKTOP_REPO="$SHALLOW"
"$SYNC" apply >/dev/null
if [ "$(status_field .reason)" = "current" ] && [ "$(status_field .from)" = "v0.2.0" ]; then
    ok "shallow ISO copy keeps the release tag after apply"
else
    err "shallow copy lost its tag after apply: $("$SYNC" status)"
fi
git_cfg -C "$CLONE" checkout -q v0.2.0 >/dev/null 2>&1
printf 'three\n' >>"$CLONE/readme"
git_cfg -C "$CLONE" commit -qam three >/dev/null
git_cfg -C "$CLONE" tag -a v0.3.0 -m v0.3.0
git_cfg -C "$CLONE" push origin v0.3.0 >/dev/null 2>&1
if [ "$(status_field .pending)" = "true" ] && [ "$(status_field .to)" = "v0.3.0" ]; then
    ok "the next release is offered after the first update"
else
    err "second release not offered: $("$SYNC" status)"
fi
"$SYNC" apply >/dev/null
[ "$(status_field .from)" = "v0.3.0" ] || err "second apply did not land on v0.3.0"
export MODERN_DESKTOP_REPO="$CLONE"

EVIL="$TMP/evil.git"
git_cfg init --bare "$EVIL" >/dev/null
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
cat >"$GIT_CONFIG_GLOBAL" <<EOF
[url "$EVIL"]
    insteadOf = $REMOTE
EOF
# git_safe clears GIT_CONFIG_GLOBAL. Status must still see v0.3.0, not evil.
git_cfg -C "$CLONE" checkout --detach v0.1.0 >/dev/null 2>&1
if [ "$(status_field .to)" != "v0.3.0" ]; then
    err "url.*.insteadOf leaked into ls-remote: $("$SYNC" status)"
else
    ok "url.*.insteadOf is ignored"
fi
unset GIT_CONFIG_GLOBAL

# The checkout is already on the new tag when install.sh runs. A failed
# install must stay offered, even offline, until a rerun finishes it.
git_cfg -C "$CLONE" checkout -q --detach v0.3.0
mkdir -p "$CLONE/install"
cat >"$CLONE/install/install.sh" <<EOF
#!/bin/sh
[ ! -e "$TMP/fail-install" ] || exit 7
: >"$TMP/installed"
EOF
chmod +x "$CLONE/install/install.sh"
git_cfg -C "$CLONE" add install/install.sh
git_cfg -C "$CLONE" commit -qm installer >/dev/null
git_cfg -C "$CLONE" tag -a v0.4.0 -m v0.4.0
git_cfg -C "$CLONE" push origin v0.4.0 >/dev/null 2>&1
git_cfg -C "$CLONE" checkout -q --detach v0.3.0
: >"$TMP/fail-install"
if MODERN_TEST_RUN_INSTALL=1 "$SYNC" apply >/dev/null 2>"$TMP/apply-fail.err"; then
    err "apply must fail when install.sh fails"
elif ! grep -q 'installing v0.4.0 failed' "$TMP/apply-fail.err"; then
    err "a failed install.sh needs a clear message: $(cat "$TMP/apply-fail.err")"
elif [ "$(status_field .reason)" = incomplete ] && [ "$(status_field .pending)" = true ] \
    && [ "$(status_field .to)" = v0.4.0 ] \
    && [ "$(MODERN_DESKTOP_REMOTE="$TMP/missing.git" "$SYNC" status | jq -r .reason)" = incomplete ]; then
    ok "a release whose install failed stays offered, also offline"
else
    err "failed install not offered again: $("$SYNC" status)"
fi
rm -f "$TMP/fail-install"
if MODERN_TEST_RUN_INSTALL=1 "$SYNC" apply >/dev/null 2>&1 && [ -e "$TMP/installed" ] \
    && [ "$(status_field .reason)" = current ] && [ ! -e "$XDG_STATE_HOME/modern/release-incomplete" ]; then
    ok "the next apply finishes the release and clears the marker"
else
    err "rerun did not finish the release: $("$SYNC" status)"
fi
git_cfg -C "$CLONE" checkout -q --detach v0.1.0

# iso-build refuse: must not mkdir under MODERN_PROTECT_HOME
ISO="$ROOT/scripts/iso-build.sh"
fake_home="$TMP/protect-home"
mkdir -p "$fake_home"
if MODERN_PROTECT_HOME="$fake_home" "$ISO" --out "$fake_home/scratch" >/dev/null 2>&1; then
    err "iso-build accepted a protected-home output path"
else
    ok "iso-build refuses MODERN_PROTECT_HOME output"
fi
if [ -e "$fake_home/scratch" ]; then
    err "iso-build created a protected-home path"
fi
if grep -F 'refusing mkarchiso while MODERN_PROTECT_HOME' "$ISO" >/dev/null; then
    err "iso-build still refuses mkarchiso on a live PC"
else
    ok "iso-build allows mkarchiso (output still cannot be under protect home)"
fi
if grep -F 'iso_aur_cleanup' "$ROOT/scripts/lib/iso-aur-repo.sh" >/dev/null \
    && grep -F "userdel" "$ROOT/scripts/lib/iso-aur-repo.sh" >/dev/null \
    && grep -F 'mount --bind' "$ROOT/scripts/lib/iso-aur-repo.sh" >/dev/null \
    && grep -F 'iso_aur_ensure_rustup' "$ROOT/scripts/lib/iso-aur-repo.sh" >/dev/null; then
    ok "AUR ISO builder bind-mounts out of a 0700 home and removes its user"
else
    err "iso-aur-repo.sh must bind-mount AUR build, rustup default, and delete modernisoaur on EXIT"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-desktop-sync: all passed\n'
