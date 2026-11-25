#!/usr/bin/env bash
# Download the bundle linked from a problem-report issue and unpack it.
# Uses this computer's GitHub login, the same way sending does.
#
# Usage, from the desktop repository: scripts/report-fetch.sh <issue>
# Unpacks into the Downloads folder as modernos-report-<issue> and prints that path.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
API="${BUG_REPORT_API:-https://api.github.com}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
DEFAULTS="$ROOT/stow/modern/.config/modern/config.default.json"

die() { printf 'report-fetch: %s\n' "$*" >&2; exit 2; }

issue="${1:-}"
[[ "$issue" =~ ^[0-9]+$ ]] || die "usage: scripts/report-fetch.sh <issue>"

repo=""
[ -f "$CFG" ] && repo="$(jq -r '.bugReport.repo // empty' "$CFG" 2>/dev/null || true)"
[ -n "$repo" ] || repo="$(jq -r '.bugReport.repo // empty' "$DEFAULTS" 2>/dev/null || true)"
[ -n "$repo" ] || die "no reports repository configured"

token() {
    gh auth token 2>/dev/null || true
}

tok="$(token)"
[ -n "$tok" ] || die "no token"

body="$(curl -fsS \
    -H "Authorization: Bearer $tok" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$API/repos/$repo/issues/$issue" | jq -r '.body // empty')"
[[ "$body" =~ https://[^[:space:]\)\"]+report\.tar\.xz ]] || die "issue $issue has no bundle"
url="${BASH_REMATCH[0]}"

# Real links are https://github.com/<owner>/<repo>/blob/<ref>/<path>.
# A stand-in server omits the owner, so the configured repo is kept.
path=""
if [[ "$url" =~ ^https://[^/]+/([^/]+)/([^/]+)/blob/[^/]+/(.+)$ ]] && [ "${BASH_REMATCH[1]}" != "blob" ]; then
    repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    path="${BASH_REMATCH[3]}"
else
    path="${url#*blob/*/}"
fi
[ -n "$path" ] || die "could not read the bundle link"

archive="$(mktemp)"
trap 'rm -f "$archive"' EXIT
curl -fsS \
    -H "Authorization: Bearer $tok" \
    -H "Accept: application/vnd.github.raw" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$API/repos/$repo/contents/$path" \
    -o "$archive"

if [ -n "${BUG_REPORT_FETCH_DIR:-}" ]; then
    downloads="$BUG_REPORT_FETCH_DIR"
else
    downloads="$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"
    [ -n "$downloads" ] && [ "$downloads" != "$HOME" ] || downloads="$HOME/Downloads"
fi
mkdir -p "$downloads"
dest="$downloads/modernos-report-$issue"
rm -rf "$dest"
mkdir -p "$dest"
tar -xJf "$archive" -C "$dest"
printf '%s\n' "$dest"
