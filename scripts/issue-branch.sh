#!/usr/bin/env bash
# Start work on a GitHub issue: a topic branch named after it, cut from
# the right base (docs/GIT.md "Branches").
#
#   fix/<n>-<slug>, feat/<n>-<slug>, docs/<n>-<slug>, chore/<n>-<slug>
#       from origin/dev, PR back into dev
#   hotfix/<n>-<slug>
#       from the newest release tag on origin/main, PR into main
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: issue-branch.sh <issue> [--type fix|feat|docs|chore] [--hotfix]
                       [--title TEXT] [--dry-run]

The type follows the issue's labels (bug -> fix, enhancement -> feat,
documentation -> docs) unless --type is given. --title skips the GitHub
lookup. --dry-run prints the branch and its base without creating it.
EOF
}

die() { printf 'issue-branch: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'issue-branch: %s\n' "$*"; }

ISSUE="" TYPE="" HOTFIX=0 TITLE="" DRY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --type) TYPE="${2:-}"; shift ;;
        --hotfix) HOTFIX=1 ;;
        --title) TITLE="${2:-}"; shift ;;
        --dry-run) DRY=1 ;;
        -h|--help) usage; exit 0 ;;
        [0-9]*) ISSUE="$1" ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done
[[ "$ISSUE" =~ ^[0-9]+$ ]] || { usage >&2; exit 1; }

labels=""
if [ -z "$TITLE" ]; then
    command -v gh >/dev/null || die "needs gh, or --title"
    json="$(gh issue view "$ISSUE" --json title,labels,state)" || die "cannot read issue #$ISSUE"
    TITLE="$(jq -r .title <<<"$json")"
    labels="$(jq -r '.labels[].name' <<<"$json")"
    [ "$(jq -r .state <<<"$json")" = OPEN ] || log "warning: #$ISSUE is closed"
fi

if [ "$HOTFIX" -eq 1 ]; then
    TYPE=hotfix
elif [ -z "$TYPE" ]; then
    case $'\n'"$labels"$'\n' in
        *$'\nbug\n'*) TYPE=fix ;;
        *$'\nenhancement\n'*) TYPE=feat ;;
        *$'\ndocumentation\n'*) TYPE=docs ;;
        *) TYPE=fix ;;
    esac
fi
case "$TYPE" in
    fix|feat|docs|chore|hotfix) ;;
    *) die "unknown type '$TYPE' (fix, feat, docs, chore)" ;;
esac

slug="$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
if [ "${#slug}" -gt 40 ]; then
    slug="${slug:0:41}"
    slug="${slug%-*}"
fi
[ -n "$slug" ] || slug="issue"
branch="$TYPE/$ISSUE-$slug"

if [ "$DRY" -eq 0 ]; then
    [ -z "$(git status --porcelain --untracked-files=no)" ] || die "commit or stash your changes first"
    git fetch --quiet --tags origin
fi
if [ "$TYPE" = hotfix ]; then
    base="$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' origin/main 2>/dev/null)" \
        || die "no release tag on origin/main"
    target=main
else
    base=origin/dev
    target=dev
fi

if [ "$DRY" -eq 1 ]; then
    printf '%s %s\n' "$branch" "$base"
    exit 0
fi
git rev-parse -q --verify "refs/heads/$branch" >/dev/null && die "$branch exists; git switch $branch"
git switch --no-track -c "$branch" "$base"
log "on $branch (from $base). Open the PR into $target with \"Fixes #$ISSUE\"."
