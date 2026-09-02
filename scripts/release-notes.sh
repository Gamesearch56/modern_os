#!/usr/bin/env bash
# Keep a Changelog notes for a vX.Y.Z tag (keepachangelog.com).
# Used by .github/workflows/release.yml. Never mkarchiso.
set -euo pipefail

REPO="."
TAG=""

usage() {
    cat <<'EOF'
Usage: release-notes.sh [--repo DIR] [vX.Y.Z]

Prints Keep a Changelog markdown for the tag (HEAD's exact tag if omitted).
EOF
}

die() { printf 'release-notes: ERROR: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --repo)
            REPO="${2:-}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        v[0-9]*.[0-9]*.[0-9]*)
            TAG="$1"
            ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

git_c() { git -C "$REPO" "$@"; }

[ -n "$TAG" ] || TAG="$(git_c describe --tags --exact-match HEAD 2>/dev/null || true)"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "need vX.Y.Z (got ${TAG:-empty})"
git_c rev-parse -q --verify "$TAG^{commit}" >/dev/null || die "unknown tag $TAG"

prev=""
while IFS= read -r t; do
    [ "$t" = "$TAG" ] && continue
    prev="$t"
    break
done < <(git_c tag -l 'v*.*.*' --sort=-v:refname)

if [ -n "$prev" ]; then
    range="${prev}..${TAG}"
else
    range="$TAG"
fi

classify() {
    local s lower
    s="$1"
    lower="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        add\ *|ship\ *|new\ *) printf 'Added' ;;
        remove\ *|drop\ *|delete\ *) printf 'Removed' ;;
        deprecat*) printf 'Deprecated' ;;
        security\ *|cve\ *) printf 'Security' ;;
        fix\ *|clear\ *|stop\ *|restore\ *|refuse\ *) printf 'Fixed' ;;
        *fail*|*instead*of*) printf 'Fixed' ;;
        *) printf 'Changed' ;;
    esac
}

added=()
changed=()
deprecated=()
removed=()
fixed=()
security=()

while IFS= read -r subject || [ -n "$subject" ]; do
    [ -n "$subject" ] || continue
    case "$subject" in
        Merge\ *) continue ;;
    esac
    catg="$(classify "$subject")"
    case "$catg" in
        Added) added+=("$subject") ;;
        Removed) removed+=("$subject") ;;
        Deprecated) deprecated+=("$subject") ;;
        Security) security+=("$subject") ;;
        Fixed) fixed+=("$subject") ;;
        *) changed+=("$subject") ;;
    esac
done < <(git_c log --no-merges --pretty=format:%s "$range")

emit_section() {
    local title="$1"
    shift
    [ $# -gt 0 ] || return 0
    printf '### %s\n' "$title"
    local line
    for line in "$@"; do
        printf -- '- %s\n' "$line"
    done
    printf '\n'
}

ver="${TAG#v}"
day="$(git_c log -1 --format=%cs "$TAG")"
printf '## [%s] - %s\n\n' "$ver" "$day"
emit_section Added "${added[@]+"${added[@]}"}"
emit_section Changed "${changed[@]+"${changed[@]}"}"
emit_section Deprecated "${deprecated[@]+"${deprecated[@]}"}"
emit_section Removed "${removed[@]+"${removed[@]}"}"
emit_section Fixed "${fixed[@]+"${fixed[@]}"}"
emit_section Security "${security[@]+"${security[@]}"}"

origin="$(git_c remote get-url origin 2>/dev/null || true)"
web=""
case "$origin" in
    git@github.com:*.git) web="https://github.com/${origin#git@github.com:}" ; web="${web%.git}" ;;
    https://github.com/*.git) web="${origin%.git}" ;;
    https://github.com/*) web="${origin%/}" ;;
esac
if [ -n "$web" ] && [ -n "$prev" ]; then
    printf '[Full changelog](%s/compare/%s...%s)\n\n' "$web" "$prev" "$TAG"
fi

printf 'The `%s` appears on this page when the ISO workflow finishes. It is not built on the development PC.\n' '.iso'
