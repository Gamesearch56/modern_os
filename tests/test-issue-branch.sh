#!/usr/bin/env bash
# issue-branch.sh names and bases, offline (--title, --dry-run, a fake gh).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="$ROOT/scripts/issue-branch.sh"
FAIL=0
err() { printf 'test-issue-branch: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-issue-branch: ok %s\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
g() { git -C "$REPO" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false -c tag.gpgsign=false "$@"; }
git init -q -b main "$REPO"
g commit -q --allow-empty -m init
g tag -a v0.1.0 -m "ModernOS v0.1.0"
g commit -q --allow-empty -m next
g tag -a v0.1.1 -m "ModernOS v0.1.1"
g update-ref refs/remotes/origin/main HEAD
g update-ref refs/remotes/origin/dev HEAD

expect() {
    local want="$1" label="$2" got
    shift 2
    got="$(cd "$REPO" && "$BRANCH" "$@" --dry-run 2>/dev/null)" || got="(failed)"
    if [ "$got" = "$want" ]; then ok "$label"; else err "$label: got '$got', want '$want'"; fi
}

expect "fix/12-headset-loses-its-profile-after-resume origin/dev" "default fix from dev" \
    12 --title "Headset loses its profile after resume!"
expect "feat/7-calculator-in-the-launcher origin/dev" "--type feat" \
    7 --type feat --title "Calculator in the launcher"
expect "hotfix/30-lock-screen-crash v0.1.1" "hotfix from the newest tag" \
    30 --hotfix --title "Lock screen crash"
expect "fix/5-a-very-long-title-that-goes-on-and-on origin/dev" "slug capped at 40" \
    5 --title "A very long title that goes on and on and on forever"

mkdir -p "$TMP/bin"
cat >"$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '{"title":"Wallpaper picker: add folders","labels":[{"name":"enhancement"}],"state":"OPEN"}\n'
EOF
chmod +x "$TMP/bin/gh"
PATH="$TMP/bin:$PATH" expect "feat/9-wallpaper-picker-add-folders origin/dev" "type from the enhancement label" 9

if (cd "$REPO" && "$BRANCH" 3 --type nope --title x --dry-run) 2>/dev/null; then
    err "unknown type accepted"
else
    ok "unknown type refused"
fi

exit "$FAIL"
