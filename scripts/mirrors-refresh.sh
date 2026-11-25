#!/usr/bin/env bash
# Rewrite /etc/pacman.d/mirrorlist for one country. HTTPS only: pacman
# downloads with libcurl, which has no rsync://, and an unfiltered
# reflector list breaks Store. --auto skips a list younger than twelve
# days so the twice-a-month timer does not rate mirrors twice.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="${MODERN_MIRROR_STAMP:-/var/lib/modern/mirrors-stamp}"
MAX_AGE=$((12 * 24 * 60 * 60))

due() {
    local now seen
    [ -f "$STAMP" ] || return 0
    now="${MODERN_MIRROR_NOW:-$(date +%s)}"
    seen="$(tr -cd '0-9' <"$STAMP" || true)"
    [ -n "$seen" ] || return 0
    [ $((now - seen)) -ge "$MAX_AGE" ]
}

write_stamp() {
    mkdir -p "$(dirname "$STAMP")"
    printf '%s\n' "${MODERN_MIRROR_NOW:-$(date +%s)}" >"$STAMP"
}

valid_country() {
    local name="$1" rest
    [ "${#name}" -ge 1 ] && [ "${#name}" -le 49 ] || return 1
    case "$name" in
        --*|*'--'*) return 1 ;;
    esac
    # Names come from reflector's country table (letters, spaces, punctuation).
    rest="${name//[A-Za-z. ()-]/}"
    [ -z "$rest" ]
}

case "${1:-}" in
    --due)
        if due; then exit 0; else exit 1; fi
        ;;
    --auto)
        due || exit 0
        country="$("$HERE/mirror-country.sh")"
        ;;
    --country)
        country="${2:-}"
        ;;
    *)
        printf 'mirrors-refresh: use --auto, --due, or --country NAME\n' >&2
        exit 1
        ;;
esac

valid_country "$country" || {
    printf 'mirrors-refresh: refusing country %q\n' "$country" >&2
    exit 1
}

if [ -n "${MODERN_MIRROR_FAKE:-}" ]; then
    printf '%s\n' "$country" >"$MODERN_MIRROR_FAKE"
    write_stamp
    exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
    printf 'mirrors-refresh: need root\n' >&2
    exit 1
fi

command -v reflector >/dev/null 2>&1 || {
    printf 'mirrors-refresh: reflector is not installed\n' >&2
    exit 1
}

refresh() {
    reflector --country "$1" --protocol https --latest 20 --sort rate \
        --save /etc/pacman.d/mirrorlist
}

if ! refresh "$country"; then
    [ "$country" = Germany ] && exit 1
    refresh Germany
    country="Germany"
fi
write_stamp

# Arm the timer from the repo copy. The installed copy has no install
# tree beside it, so the timer does not try to install itself.
if [ -f "$HERE/../install/lib/mirrors.sh" ]; then
    REPO_ROOT="$(cd "$HERE/.." && pwd)"
    export REPO_ROOT
    # shellcheck source=../install/lib/mirrors.sh
    source "$REPO_ROOT/install/lib/mirrors.sh"
    MIRRORS_SKIP_REFRESH=1 mirrors_apply >/dev/null 2>&1 || true
fi
