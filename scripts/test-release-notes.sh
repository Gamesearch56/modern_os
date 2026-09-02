#!/usr/bin/env bash
# Keep a Changelog output from a throwaway git repo. No GitHub network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTES="$ROOT/scripts/release-notes.sh"
FAIL=0

err() { printf 'test-release-notes: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-release-notes: ok %s\n' "$*"; }

command -v git >/dev/null 2>&1 || { echo "git required" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-rnotes-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

case "$TMP" in
    /home/bastianweigand/*) echo "test-release-notes: refusing live home" >&2; exit 1 ;;
esac

git_cfg() {
    git -c core.hooksPath=/dev/null \
        -c user.name='Test' \
        -c user.email='test@example.com' \
        "$@"
}

REPO="$TMP/repo"
mkdir -p "$REPO"
git_cfg -C "$REPO" init -q
git_cfg -C "$REPO" checkout -q -b main
printf 'a\n' >"$REPO/f"
git_cfg -C "$REPO" add f
git_cfg -C "$REPO" commit -q -m "Add the first thing"
git_cfg -C "$REPO" tag -a v0.1.0 -m "v0.1.0"
printf 'b\n' >>"$REPO/f"
git_cfg -C "$REPO" add f
git_cfg -C "$REPO" commit -q -m "Fix the spaced calamares name"
printf 'c\n' >>"$REPO/f"
git_cfg -C "$REPO" add f
git_cfg -C "$REPO" commit -q -m "Write the ISO onto runner disk instead of tmpfs"
git_cfg -C "$REPO" remote add origin git@github.com:Gamesearch56/modern_dotfile.git
git_cfg -C "$REPO" tag -a v0.1.1 -m "v0.1.1"

out="$("$NOTES" --repo "$REPO" v0.1.1)"

expect() {
    local pat="$1" good="$2" bad="$3"
    if printf '%s\n' "$out" | grep -q "$pat"; then
        ok "$good"
    else
        err "$bad"
    fi
}

expect '## \[0.1.1\] - ' "version heading" "missing Keep a Changelog heading"
expect '### Fixed' "Fixed section" "missing Fixed"
expect 'Fix the spaced calamares name' "fix subject" "missing fix subject"
expect 'Write the ISO onto runner disk instead of tmpfs' "instead-of is Fixed" "instead-of not classified Fixed"
if printf '%s\n' "$out" | grep -q 'Add the first thing'; then
    err "v0.1.0 commit leaked into v0.1.1"
else
    ok "range excludes previous tag"
fi
expect 'compare/v0.1.0...v0.1.1' "compare link" "missing compare link"
expect 'ISO workflow' "ISO footer" "missing ISO footer"

[ "$FAIL" -eq 0 ]
