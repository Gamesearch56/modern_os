#!/usr/bin/env bash
# A PR title becomes the squash commit and its release-notes line, so it
# has to be a Conventional Commit release-notes.sh can sort
# (docs/GIT.md "PR title and description"). Release PRs are
# "Release vX.Y.Z"; GitHub's own revert PRs pass as they are.
set -euo pipefail

TYPES="feat|fix|remove|deprecate|security|perf|refactor|style|docs|build|ci|test|chore|revert"
MAX=72

title="${1:-}"
fail() {
    printf 'check-pr-title: %s\n' "$*" >&2
    printf 'check-pr-title: expected "type(scope): what changes", type one of: %s\n' "${TYPES//|/, }" >&2
    exit 1
}

[ -n "$title" ] || fail "empty title"
if [[ "$title" =~ ^Release\ v[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$title" =~ ^Revert\ \".+\"$ ]]; then
    exit 0
fi
re="^($TYPES)(\([a-z0-9._/-]+\))?!?: [^ ].*$"
[[ "$title" =~ $re ]] || fail "\"$title\" is not a Conventional Commit"
[ "${#title}" -le "$MAX" ] || fail "${#title} characters, keep it to $MAX"
case "$title" in
    *.) fail "no full stop at the end" ;;
esac
exit 0
