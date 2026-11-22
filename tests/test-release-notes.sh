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

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-release-notes: refusing protected home" >&2; exit 1 ;;
    esac
fi

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
if printf '%s\n' "$out" | grep -q 'ISO workflow'; then
    err "notes still promise a CI-built ISO"
else
    ok "no ISO footer"
fi

commit() {
    printf '%s\n' "$1" >>"$REPO/f"
    git_cfg -C "$REPO" add f
    git_cfg -C "$REPO" commit -q -m "$1" ${2:+-m "$2"}
}
commit "feat(audio): headset profile switch in the panel (#12)"
commit "fix: lock screen keeps the keyboard layout (#14)"
commit "remove: the old wallpaper picker (#15)"
commit "feat(config)!: settings live in config.json only (#16)"
commit "refactor(bar): one model for all widgets" "BREAKING CHANGE: bar.left ids changed"
commit "feat(launcher): calculator provider (#17)" "Removed: the old calc prefix
  Fixed: indented example lines are not entries"
commit "docs: explain the release flow"
commit "ci: split lint from tests"
out="$("$NOTES" --repo "$REPO" --pr v0.2.0)"
expect '^- \*\*audio:\*\* Headset profile switch in the panel (#12)$' "feat with scope is Added, scope bold" "feat(audio) not rendered"
expect '^### Removed$' "remove: has a Removed section" "missing Removed"
expect '^- The old wallpaper picker (#15)$' "type prefix is stripped" "remove subject kept its prefix"
expect '^### Breaking changes$' "breaking changes section" "missing Breaking changes"
expect 'Settings live in config.json only' "type! is breaking" "feat! not listed"
expect 'One model for all widgets' "BREAKING CHANGE footer is breaking" "footer breaking not listed"
expect '^- The old calc prefix$' "Changelog lines in the body add entries" "body entry missing"
if printf '%s\n' "$out" | grep -q 'indented example'; then
    err "an indented example line became an entry"
else
    ok "only column-0 Changelog lines count"
fi
expect '<summary>Maintenance' "ci/build/test collapse into Maintenance" "missing Maintenance details"
expect '## Release checklist' "--pr adds the release checklist" "missing checklist"
if [ "$(printf '%s\n' "$out" | grep -c 'Settings live in config.json only')" = 1 ]; then
    ok "a breaking change is listed once"
else
    err "breaking change listed twice"
fi
if printf '%s\n' "$out" | awk '/^### Breaking/{b=NR} /^### Added/{a=NR} END{exit !(b && a && b < a)}'; then
    ok "breaking changes come first"
else
    err "Breaking changes are not first"
fi

git_cfg -C "$REPO" tag -a v0.2.0 -m "ModernOS v0.2.0" -m "Headsets switch profiles from the panel."
out="$("$NOTES" --repo "$REPO" v0.2.0)"
expect '^### Highlights$' "tag message body becomes Highlights" "missing Highlights"
expect 'Headsets switch profiles from the panel.' "highlight text" "highlight text missing"
expect '^### Upgrading$' "upgrade note" "missing Upgrading"
expect 'compare/v0.1.1...v0.2.0' "compare link from the previous tag" "wrong compare range"

[ "$FAIL" -eq 0 ]
