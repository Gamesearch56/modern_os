#!/usr/bin/env bash
# Build a shorter issue from a problem report (docs/GIT.md "From a
# report to a branch"). Steps, Environment and Device are kept. Logs,
# screenshots and the bundle are left out. The draft opens in $EDITOR
# before anything is created, because the steps are the reporter's own
# words.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULTS="$ROOT/stow/modern/.config/modern/config.default.json"

usage() {
    cat <<'EOF'
Usage: report-to-issue.sh <report-number> [--create] [--from FILE]

Prints the shorter draft. --create opens it in $EDITOR, files the issue
here with the bug and Work Required labels plus the report's area labels,
and comments the source issue with the new link. --from reads a saved
report body instead of asking GitHub (for testing).
EOF
}

die() { printf 'report-to-issue: ERROR: %s\n' "$*" >&2; exit 1; }

NUM="" CREATE=0 FROM=""
while [ $# -gt 0 ]; do
    case "$1" in
        --create) CREATE=1 ;;
        --from) FROM="${2:-}"; shift ;;
        -h|--help) usage; exit 0 ;;
        [0-9]*) NUM="$1" ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done
[[ "$NUM" =~ ^[0-9]+$ ]] || { usage >&2; exit 1; }

if [ -n "$FROM" ]; then
    title="Problem report"
    body="$(cat "$FROM")"
    areas=""
else
    command -v gh >/dev/null || die "needs gh"
    reports="$(jq -r '.bugReport.repo // empty' "$DEFAULTS")"
    [ -n "$reports" ] || die "no bugReport.repo in config.default.json"
    json="$(gh issue view "$NUM" --repo "$reports" --json title,body,labels)" \
        || die "cannot read report #$NUM"
    title="$(jq -r .title <<<"$json")"
    body="$(jq -r .body <<<"$json")"
    areas="$(jq -r '[.labels[].name | select(startswith("area:"))] | join(",")' <<<"$json")"
fi
# "[v0.7.7] Title" -> "Title"; the version is in Environment.
title="$(sed -E 's/^\[[^]]*\] *//' <<<"$title")"

draft="$(mktemp --suffix=.md)"
trap 'rm -f "$draft"' EXIT
{
    awk '
        /^## / { keep = ($0 == "## Steps" || $0 == "## Environment" || $0 == "## Device") }
        keep
    ' <<<"$body"
    printf '\n_Filed from an in-app problem report. Logs and screenshots are not included._\n'
} >"$draft"

if [ "$CREATE" -eq 0 ]; then
    printf '# %s\n\n' "$title"
    cat "$draft"
    exit 0
fi

"${EDITOR:-nano}" "$draft"
labels="bug,Work Required${areas:+,$areas}"
url="$(gh issue create --title "$title" --body-file "$draft" --label "$labels")"
printf '%s\n' "$url"
gh issue comment "$NUM" --repo "$reports" --body "Tracked publicly in $url" >/dev/null
