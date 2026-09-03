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
if [ "$(status_field .reason)" != "dirty" ] || [ "$(status_field .pending)" != "false" ]; then
    err "dirty tree should not be pending: $("$SYNC" status)"
else
    ok "dirty tree is not pending"
fi
if "$SYNC" apply >/dev/null 2>&1; then
    err "apply should refuse a dirty tree"
else
    ok "apply refuses dirty tree"
fi
git_cfg -C "$CLONE" checkout -- . >/dev/null

git_cfg -C "$CLONE" checkout -B feature/x >/dev/null 2>&1
printf 'feat\n' >>"$CLONE/readme"
git_cfg -C "$CLONE" add readme
git_cfg -C "$CLONE" commit -m feat >/dev/null
if [ "$(status_field .reason)" != "notag" ] || [ "$(status_field .pending)" != "false" ]; then
    err "feature branch should be notag / not pending: $("$SYNC" status)"
else
    ok "feature branch is not pending"
fi

EVIL="$TMP/evil.git"
git_cfg init --bare "$EVIL" >/dev/null
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
cat >"$GIT_CONFIG_GLOBAL" <<EOF
[url "$EVIL"]
    insteadOf = $REMOTE
EOF
# git_safe clears GIT_CONFIG_GLOBAL. Status must still see v0.2.0, not evil.
git_cfg -C "$CLONE" checkout --detach v0.1.0 >/dev/null 2>&1
if [ "$(status_field .to)" != "v0.2.0" ]; then
    err "url.*.insteadOf leaked into ls-remote: $("$SYNC" status)"
else
    ok "url.*.insteadOf is ignored"
fi
unset GIT_CONFIG_GLOBAL

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
