#!/usr/bin/env bash
# Every package in install/manifests still exists: native layers in the
# sync repos (core, extra, multilib), *.aur.txt in the AUR. Renamed or
# dropped packages otherwise surface only when someone installs.
# Run by .github/workflows/weekly.yml in an Arch container; works on any
# Arch machine with multilib enabled. Exit 1 lists what is missing.
#
# Test seams: MANIFEST_DIR, MANIFEST_REPO_LIST (file of repo package and
# group names instead of pacman) and MANIFEST_AUR_JSON (an AUR RPC reply
# instead of the network).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="${MANIFEST_DIR:-$ROOT/install/manifests}"
AUR_RPC="https://aur.archlinux.org/rpc/v5/info"

log() { printf 'check-manifests: %s\n' "$*"; }
die() { printf 'check-manifests: ERROR: %s\n' "$*" >&2; exit 2; }

names() {
    sed -E 's/#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//; s/\r$//' "$@" \
        | grep -E '^[a-zA-Z0-9][a-zA-Z0-9.+_@-]*$' | sort -u || true
}

native=() aur=()
for f in "$DIR"/*.txt; do
    case "$(basename "$f")" in
        *.aur.txt) aur+=("$f") ;;
        60-flatpak.txt) ;;
        *) native+=("$f") ;;
    esac
done
[ ${#native[@]} -gt 0 ] || die "no manifests in $DIR"

known="$(mktemp)"
trap 'rm -f "$known"' EXIT
if [ -n "${MANIFEST_REPO_LIST:-}" ]; then
    sort -u "$MANIFEST_REPO_LIST" >"$known"
else
    command -v pacman >/dev/null || die "needs pacman (or MANIFEST_REPO_LIST)"
    { pacman -Slq; pacman -Sg; } | sort -u >"$known"
fi

missing=()
while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    grep -qxF "$pkg" "$known" && continue
    # A provided name (e.g. a virtual package) resolves even without its own entry.
    if [ -z "${MANIFEST_REPO_LIST:-}" ] && pacman -Sp --print-format %n "$pkg" >/dev/null 2>&1; then
        continue
    fi
    missing+=("repo: $pkg")
done < <(names "${native[@]}")
log "checked $(names "${native[@]}" | grep -c . || true) repo packages"

if [ ${#aur[@]} -gt 0 ]; then
    mapfile -t want < <(names "${aur[@]}")
    if [ -n "${MANIFEST_AUR_JSON:-}" ]; then
        reply="$(cat "$MANIFEST_AUR_JSON")"
    else
        query="$(printf '&arg[]=%s' "${want[@]}")"
        reply="$(curl -fsS --retry 3 --max-time 60 "$AUR_RPC?${query#&}")" \
            || die "AUR RPC did not answer"
    fi
    found="$(printf '%s' "$reply" | jq -r '.results[].Name')"
    for pkg in "${want[@]}"; do
        grep -qxF "$pkg" <<<"$found" || missing+=("aur: $pkg")
    done
    while IFS= read -r pkg; do
        [ -n "$pkg" ] && log "warning: aur: $pkg is flagged out of date"
    done < <(printf '%s' "$reply" | jq -r '.results[] | select(.OutOfDate != null) | .Name')
    log "checked ${#want[@]} AUR packages"
fi

if [ ${#missing[@]} -gt 0 ]; then
    printf 'check-manifests: missing %s\n' "${missing[@]}"
    exit 1
fi
log "ok"
