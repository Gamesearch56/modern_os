#!/usr/bin/env bash
# The image is accompanied by a three-year source offer and a package list.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OFFER="$ROOT/scripts/source-offer.sh"
FAIL=0
err() { printf 'test-source-offer: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-source-offer: ok %s\n' "$1"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-offer-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
printf 'bash 5.2.037-1\nvim 9.1.0-1\n' >"$TMP/pkgs"
"$OFFER" --packages "$TMP/pkgs" --tag v0.8.16 --date 2026-11-24 --out "$TMP/out"
text="$(cat "$TMP/out/v0.8.16-SOURCE-OFFER.txt")"
list="$(cat "$TMP/out/v0.8.16-PACKAGES.txt")"
if printf '%s\n' "$text" | grep -Fq 'three years' \
    && printf '%s\n' "$text" | grep -Fq 'v0.8.16' \
    && printf '%s\n' "$text" | grep -Fq 'archive.archlinux.org' \
    && printf '%s\n' "$text" | grep -Fq 'github.com/Gamesearch56/modern_os' \
    && printf '%s\n' "$list" | grep -Fxq 'bash 5.2.037-1'; then
    ok "the offer names the release, the archive and a way to ask"
else
    err "offer text or package list is incomplete"
fi

python3 - <<PY
import sys
sys.path.insert(0, "$ROOT/iso/airootfs/usr/lib/modern")
from install_optional import packages_for
got = packages_for(["steam", "nvidia-proprietary"])
assert got == ["nvidia-open-dkms", "nvidia-utils", "steam", "lib32-nvidia-utils"], got
assert packages_for([]) == []
assert "vivaldi" not in packages_for(["steam", "spotify-launcher", "discord", "proton-vpn-gtk-app", "nvidia-proprietary"])
print("test-source-offer: ok ticked programs become download names")
PY

conf="$ROOT/iso/airootfs/etc/calamares/settings.conf"
if grep -Fq 'modernapps' "$conf" && awk '
    /modernapps$/ { seen = 1 }
    /summary$/ { if (seen) ok = 1 }
    END { exit ok ? 0 : 1 }
' "$conf" && awk '
    /latedesktop/ { seen = 1 }
    /modernappsjob/ { if (seen) ok = 1 }
    END { exit ok ? 0 : 1 }
' "$conf"; then
    ok "the program list is before confirmation and the download is after install"
else
    err "settings.conf step order"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-source-offer: ok\n'
