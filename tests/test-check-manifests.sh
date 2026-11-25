#!/usr/bin/env bash
# check-manifests.sh against fake repo and AUR answers: no pacman, no network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/scripts/check-manifests.sh"
FAIL=0
err() { printf 'test-check-manifests: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-check-manifests: ok %s\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/m"
printf '# base\nlinux   # kernel\nbase-devel\n\n' >"$TMP/m/00-base.txt"
printf 'yay-bin\n' >"$TMP/m/00-base.aur.txt"
printf 'org.example.App\n' >"$TMP/m/60-flatpak.txt"
printf 'linux\nbase-devel\n' >"$TMP/repo"
printf '{"results":[{"Name":"yay-bin","OutOfDate":null}]}' >"$TMP/aur.json"

run() { MANIFEST_DIR="$TMP/m" MANIFEST_REPO_LIST="$TMP/repo" MANIFEST_AUR_JSON="$TMP/aur.json" "$CHECK"; }

if out="$(run)"; then ok "all present passes"; else err "all present failed: $out"; fi
case "$out" in *org.example.App*) err "flatpak ids are not repo packages" ;; *) ok "flatpak layer skipped" ;; esac

printf 'gone-pkg\n' >>"$TMP/m/00-base.txt"
printf 'gone-aur\n' >>"$TMP/m/00-base.aur.txt"
printf '{"results":[{"Name":"yay-bin","OutOfDate":1700000000}]}' >"$TMP/aur.json"
if out="$(run)"; then
    err "missing packages passed"
else
    case "$out" in *"repo: gone-pkg"*) ok "missing repo package named" ;; *) err "repo miss not named: $out" ;; esac
    case "$out" in *"aur: gone-aur"*) ok "missing AUR package named" ;; *) err "AUR miss not named: $out" ;; esac
    case "$out" in *"yay-bin is flagged out of date"*) ok "out-of-date AUR warning" ;; *) err "no out-of-date warning" ;; esac
fi

exit "$FAIL"
