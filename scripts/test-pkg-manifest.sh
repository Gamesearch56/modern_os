#!/usr/bin/env bash
# Default desktop apps must be manifest "system" names for Store/Update.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-pkg-manifest: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-pkg-manifest: ok %s\n' "$*"; }

names="$("$ROOT/scripts/pkg-manifest-names.sh")"
echo "$names" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null \
    || err "pkg-manifest-names.sh must print a JSON array"

for pkg in kitty vivaldi neovim mpv nautilus imv cliphist matugen matugen-bin; do
    if echo "$names" | python3 -c "import json,sys; raise SystemExit(0 if \"$pkg\" in json.load(sys.stdin) else 1)"; then
        ok "$pkg is a shipped system package"
    else
        err "$pkg missing from install/manifests (Store/Update system list)"
    fi
done

STORE="$ROOT/stow/shell/.config/quickshell/modern/Services/StoreClassify.qml"
if grep -F 'return root.inShipped(name) || root.isProtected(name);' "$STORE" >/dev/null \
    && ! grep -F 'inCatalog(name, categories)' "$STORE" >/dev/null; then
    ok "Store treats every shipped name as system"
else
    err "StoreClassify.isSystem must be shipped or protected, not catalog/desktop"
fi

UPD="$ROOT/stow/shell/.config/quickshell/modern/Services/UpdateClassify.qml"
if grep -F 'if (shipped && shipped[n])' "$UPD" >/dev/null \
    && grep -F 'defs.videoPlayer' "$UPD" >/dev/null \
    && grep -F 'neovim' "$UPD" >/dev/null; then
    ok "Update treats shipped names and default apps as system"
else
    err "UpdateClassify.isSystem must use the shipped map and default app stems"
fi

if grep -F 'classify.parseCheck(text, shipped.shipped)' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/Update.qml" >/dev/null; then
    ok "Update feeds the manifest list into parseCheck"
else
    err "Update.qml must pass StoreClassify.shipped into parseCheck"
fi

[ "$FAIL" -eq 0 ]
