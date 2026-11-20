#!/usr/bin/env bash
# Snapshots the current account's installed packages, AUR packages, flatpaks
# and enabled systemd units. Read-only — never modifies the system.
#
# Used two ways:
#   1. Once, to seed install/baseline/ as the old-vs-new reference for
#      manifest curation (see docs/DECISIONS.md).
#   2. Any time later, to audit drift between this machine and
#      install/manifests/ — pass --diff to compare against the manifests
#      instead of overwriting the baseline.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../install/lib/default-apps.sh
source "$REPO_ROOT/install/lib/default-apps.sh"
OUT_DIR="$REPO_ROOT/install/baseline"
MODE="${1:-snapshot}"

mkdir -p "$OUT_DIR"

collect() {
    echo "Collecting native explicit packages..."
    pacman -Qqen > "$OUT_DIR/pkglist_native.txt" 2>/dev/null || pacman -Qqe > "$OUT_DIR/pkglist_native.txt"

    echo "Collecting AUR/foreign explicit packages..."
    pacman -Qqem > "$OUT_DIR/pkglist_aur.txt" 2>/dev/null || true

    echo "Collecting flatpaks..."
    if command -v flatpak >/dev/null 2>&1; then
        flatpak list --app --columns=application > "$OUT_DIR/flatpaks.txt" 2>/dev/null || true
    else
        : > "$OUT_DIR/flatpaks.txt"
    fi

    echo "Collecting enabled systemd units (system + user)..."
    systemctl list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' > "$OUT_DIR/systemd_units_system.txt" || true
    systemctl --user list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' > "$OUT_DIR/systemd_units_user.txt" || true

    {
        echo "snapshot_taken=$(date -Iseconds)"
        echo "user=$(whoami)"
        echo "hostname=$(uname -n)"
        echo "native_count=$(wc -l < "$OUT_DIR/pkglist_native.txt")"
        echo "aur_count=$(wc -l < "$OUT_DIR/pkglist_aur.txt")"
        echo "flatpak_count=$(wc -l < "$OUT_DIR/flatpaks.txt")"
    } > "$OUT_DIR/manifest.txt"

    echo "Snapshot written to $OUT_DIR/"
}

diff_against_manifests() {
    manifests_dir="$REPO_ROOT/install/manifests"
    all_manifest_pkgs=$(
        {
            cat "$manifests_dir"/*.txt 2>/dev/null | grep -vE '^\s*(#|$)' | awk '{print $1}' || true
            default_app_packages
        } | sort -u
    )
    current_pkgs=$(pacman -Qqe | sort -u)

    echo "== In install/manifests/ but not currently installed =="
    comm -23 <(echo "$all_manifest_pkgs") <(echo "$current_pkgs")
    echo
    echo "== Currently installed but not in any manifest =="
    comm -13 <(echo "$all_manifest_pkgs") <(echo "$current_pkgs")
}

case "$MODE" in
    snapshot) collect ;;
    --diff) diff_against_manifests ;;
    *) echo "usage: $0 [snapshot|--diff]" >&2; exit 2 ;;
esac
