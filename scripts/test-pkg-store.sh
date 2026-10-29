#!/usr/bin/env bash
# Store browse/detail/extras stay on official names and an HTTPS allowlist.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-pkg-store: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-pkg-store: ok %s\n' "$*"; }

BROWSE="$ROOT/scripts/pkg-browse.sh"
DETAIL="$ROOT/scripts/pkg-detail.sh"
EXTRAS="$ROOT/scripts/pkg-extras.sh"
STORE="$ROOT/stow/shell/.config/quickshell/modern/Services/Store.qml"
CAT="$ROOT/stow/modern/.config/modern/store/catalog.json"

[ -x "$BROWSE" ] && [ -x "$DETAIL" ] && [ -x "$EXTRAS" ] || err "scripts must be executable"

if "$BROWSE" >/dev/null; then
    out="$("$BROWSE")"
    [ "$out" = "[]" ] || err "empty browse: $out"
    ok "browse without a query is []"
else
    err "browse empty query"
fi

if "$BROWSE" --evil 24 2>/dev/null | grep -Fqx '[]'; then
    ok "browse rejects a dashed query"
else
    err "browse dashed query"
fi

if [ "$("$DETAIL" 2>/dev/null || true)" = '{}' ]; then
    ok "detail without a name is {}"
else
    err "detail empty"
fi

if "$DETAIL" 'not a pkg' >/dev/null 2>&1; then
    err "detail accepted an invalid name"
else
    ok "detail rejects an invalid name"
fi

if grep -F "screenshots.debian.net" "$EXTRAS" >/dev/null \
    && grep -F -- "--proto '=https'" "$EXTRAS" >/dev/null \
    && grep -F 'valid_pkg_name' "$EXTRAS" >/dev/null \
    && grep -F 'screenshot_image_url' "$EXTRAS" >/dev/null \
    && grep -F '"/screenshot/"' "$EXTRAS" >/dev/null \
    && ! grep -E 'http://|aur.archlinux.org' "$EXTRAS" >/dev/null; then
    ok "extras fetch is HTTPS allowlisted at full screenshot size"
else
    err "extras must pin https://screenshots.debian.net screenshot_image_url"
fi

if grep -F 'function showPackage' "$STORE" >/dev/null \
    && grep -F 'canMutate' "$STORE" >/dev/null \
    && grep -F 'Passwd.canManage' "$STORE" >/dev/null \
    && grep -F 'loadMore' "$STORE" >/dev/null; then
    ok "Store exposes detail, admin gate, and loadMore"
else
    err "Store.qml missing showPackage/canMutate/loadMore"
fi

DISCOVER="$ROOT/stow/shell/.config/quickshell/modern/Modules/Store/Discover.qml"
if grep -F 'Featured' "$DISCOVER" >/dev/null \
    && grep -F 'CatChips' "$DISCOVER" >/dev/null \
    && [ -f "$ROOT/stow/shell/.config/quickshell/modern/Modules/Store/HeroLead.qml" ] \
    && [ -f "$ROOT/stow/shell/.config/quickshell/modern/Modules/Store/HeroSide.qml" ] \
    && [ -f "$ROOT/stow/shell/.config/quickshell/modern/Modules/Store/PkgTile.qml" ]; then
    ok "Discover home has featured hero, chips, and tiles"
else
    err "Discover.qml missing Featured/CatChips layout"
fi

if grep -F 'Store.showPackage("snapper")' "$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/backup/Status.qml" >/dev/null \
    && grep -F 'Store.showPackage("ufw")' "$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/firewall/Status.qml" >/dev/null; then
    ok "missing snapper/ufw open the package detail"
else
    err "Settings missing-package CTAs must call showPackage"
fi

if python3 -c 'import json,sys; d=json.load(open(sys.argv[1]));
assert all("browse" in c for c in d["categories"] if c.get("packages"))
' "$CAT"; then
    ok "categories that list packages have a browse needle"
else
    err "catalog browse needles"
fi

MUT="$ROOT/scripts/pkg-mutate.sh"
MUTATE_QML="$ROOT/stow/shell/.config/quickshell/modern/Services/StoreMutate.qml"
if grep -F 'install|remove|update' "$MUT" >/dev/null \
    && grep -F 'PACMAN" -Sy --noconfirm --needed --' "$MUT" >/dev/null \
    && grep -F 'proc.command = [Paths.script("pkg-mutate.sh"), action, name]' "$MUTATE_QML" >/dev/null \
    && ! grep -F 'action === "update" ? "install"' "$MUTATE_QML" >/dev/null; then
    ok "store update runs pacman -Sy --needed"
else
    err "pkg-mutate update must -Sy and StoreMutate must pass update through"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-pkg-store: all passed\n'
