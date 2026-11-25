#!/usr/bin/env bash
# Release notes for a vX.Y.Z tag, or the body of the release PR before
# the tag exists. Used by .github/workflows/release.yml. Never mkarchiso.
#
# Sections follow Keep a Changelog; each commit lands in one by its
# Conventional Commit type (docs/GIT.md "Commit and PR titles"). Older
# subjects without a type fall back to their leading verb. A squash
# commit body may add more entries as "Removed: ..." lines (the PR
# template's Changelog block).
set -euo pipefail

REPO="."
TAG=""
PR=0

usage() {
    cat <<'EOF'
Usage: release-notes.sh [--repo DIR] [--pr] [vX.Y.Z]

Prints the release notes for the tag (HEAD's exact tag if omitted). The
annotated tag's message, after its first line, becomes the Highlights.

--pr prints the body of the "Release vX.Y.Z" pull request instead: the
same sections for everything on HEAD since the newest tag, and the
release checklist. The tag does not need to exist yet.
EOF
}

die() { printf 'release-notes: ERROR: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --repo) REPO="${2:-}"; shift ;;
        --pr) PR=1 ;;
        -h|--help) usage; exit 0 ;;
        v[0-9]*.[0-9]*.[0-9]*) TAG="$1" ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

git_c() { git -C "$REPO" "$@"; }

[ -n "$TAG" ] || TAG="$(git_c describe --tags --exact-match HEAD 2>/dev/null || true)"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "need vX.Y.Z (got ${TAG:-empty})"
if [ "$PR" -eq 1 ]; then
    end=HEAD
else
    git_c rev-parse -q --verify "$TAG^{commit}" >/dev/null || die "unknown tag $TAG"
    end="$TAG"
fi

prev=""
while IFS= read -r t; do
    [ "$t" = "$TAG" ] && continue
    git_c merge-base --is-ancestor "$t" "$end" 2>/dev/null || continue
    prev="$t"
    break
done < <(git_c tag -l 'v*.*.*' --sort=-v:refname)
range="${prev:+$prev..}$end"

SECTIONS=(Breaking Added Changed Deprecated Removed Fixed Security Documentation Maintenance)
declare -A TITLE=(
    [Breaking]="Breaking changes" [Added]="Added" [Changed]="Changed"
    [Deprecated]="Deprecated" [Removed]="Removed" [Fixed]="Fixed"
    [Security]="Security" [Documentation]="Documentation" [Maintenance]="Maintenance"
)
declare -A ITEMS=()

legacy_section() {
    local lower
    lower="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
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

type_section() {
    case "$1" in
        feat) printf 'Added' ;;
        fix) printf 'Fixed' ;;
        remove) printf 'Removed' ;;
        deprecate) printf 'Deprecated' ;;
        security) printf 'Security' ;;
        docs) printf 'Documentation' ;;
        build|ci|test|chore|refactor|style) printf 'Maintenance' ;;
        *) printf 'Changed' ;;
    esac
}

add_item() { ITEMS[$1]+="$2"$'\n'; }

# type(scope)!: subject — the scope becomes a bold prefix, the type the section.
CC='^([a-z]+)(\(([a-z0-9._/-]+)\))?(!)?: (.+)$'
TRAILER='^(Breaking|Added|Changed|Deprecated|Removed|Fixed|Security): *([^ ].*)$'
while IFS=$'\x1f' read -r -d $'\x1e' subject body; do
    subject="${subject#$'\n'}"
    [ -n "$subject" ] || continue
    case "$subject" in Merge\ *) continue ;; esac
    if [[ "$subject" =~ $CC ]]; then
        type="${BASH_REMATCH[1]}" scope="${BASH_REMATCH[3]}" bang="${BASH_REMATCH[4]}" text="${BASH_REMATCH[5]}"
        text="${text^}"
        [ -n "$scope" ] && text="**$scope:** $text"
        if [ -n "$bang" ] || [[ "$body" == *"BREAKING CHANGE:"* ]]; then
            add_item Breaking "$text"
        else
            add_item "$(type_section "$type")" "$text"
        fi
    else
        add_item "$(legacy_section "$subject")" "$subject"
    fi
    # Extra entries from the PR's "Changelog" block, one "Section: text" per line.
    while IFS= read -r line; do
        line="${line%$'\r'}"
        if [[ "$line" =~ $TRAILER ]]; then
            add_item "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]^}"
        fi
    done <<<"$body"
done < <(git_c log --no-merges --format='%s%x1f%b%x1e' "$range")

emit_section() {
    local key="$1" line
    [ -n "${ITEMS[$key]:-}" ] || return 0
    printf '### %s\n' "${TITLE[$key]}"
    while IFS= read -r line; do
        [ -n "$line" ] && printf -- '- %s\n' "$line"
    done <<<"${ITEMS[$key]}"
    printf '\n'
}

emit_changes() {
    local key
    for key in "${SECTIONS[@]}"; do
        if [ "$key" = Maintenance ] && [ -n "${ITEMS[$key]:-}" ]; then
            printf '<details>\n<summary>Maintenance (refactoring, build, CI, tests)</summary>\n\n'
            emit_section "$key"
            printf '</details>\n\n'
        else
            emit_section "$key"
        fi
    done
}

origin="$(git_c remote get-url origin 2>/dev/null || true)"
web=""
case "$origin" in
    git@github.com:*) web="https://github.com/${origin#git@github.com:}" ;;
    https://github.com/*) web="${origin%/}" ;;
esac
web="${web%.git}"
compare=""
[ -n "$web" ] && [ -n "$prev" ] && compare="$web/compare/$prev...$TAG"

if [ "$PR" -eq 1 ]; then
    printf '## What is in %s\n\n' "$TAG"
    printf 'Everything merged into \x60dev\x60 since %s. These sections become the release notes.\n\n' \
        "${prev:-the first commit}"
    emit_changes
    cat <<EOF
## Release checklist

- [ ] CI is green on this PR
- [ ] \`scripts/ci-check.sh\` passes on \`dev\`
- [ ] The ISO built from \`dev\` installs in QEMU (\`scripts/iso-qemu.sh\`)
- [ ] Breaking changes, if any, explain what users have to do
- [ ] Highlights for the tag message are written
EOF
    exit 0
fi

ver="${TAG#v}"
day="$(git_c log -1 --format=%cs "$TAG")"
printf '## [%s] - %s\n\n' "$ver" "$day"
highlights="$(git_c tag -l --format='%(contents:body)' "$TAG" | sed -e '/^-----BEGIN PGP SIGNATURE-----/,$d')"
if [ -n "${highlights//[[:space:]]/}" ]; then
    printf '### Highlights\n\n%s\n\n' "$highlights"
fi
emit_changes
cat <<'EOF'
### Upgrading

Installed systems: **Settings → Update** offers this release.

EOF
if [ -n "$compare" ]; then
    printf '[Full changelog](%s)\n\n' "$compare"
fi
