#!/usr/bin/env bash
# Manifest names: Update treats all as system; Store only the --core layers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../install/lib/default-apps.sh
source "$ROOT/install/lib/default-apps.sh"
FAIL=0
err() { printf 'test-pkg-manifest: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-pkg-manifest: ok %s\n' "$*"; }

names="$("$ROOT/scripts/pkg-manifest-names.sh")"
echo "$names" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null \
    || err "pkg-manifest-names.sh must print a JSON array"

for pkg in kitty vivaldi neovim cliphist matugen matugen-bin; do
    if echo "$names" | python3 -c "import json,sys; raise SystemExit(0 if \"$pkg\" in json.load(sys.stdin) else 1)"; then
        ok "$pkg is a shipped system package"
    else
        err "$pkg missing from install/manifests (Store/Update system list)"
    fi
done

core="$("$ROOT/scripts/pkg-manifest-names.sh" --core)"
in_core() { echo "$core" | jq -e --arg n "$1" 'index($n) != null' >/dev/null; }
for pkg in hyprland quickshell kitty vivaldi matugen mkinitcpio pipewire; do
    if in_core "$pkg"; then ok "$pkg is a core (undeletable) package"
    else err "$pkg missing from the --core layers"; fi
done
while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    if echo "$names" | python3 -c "import json,sys; raise SystemExit(0 if \"$pkg\" in json.load(sys.stdin) else 1)"; then
        ok "$pkg is a shipped package via default-apps.json"
    else
        err "$pkg missing from install/manifests (Store/Update system list)"
    fi
    if in_core "$pkg"; then ok "$pkg is a core package via default-apps.json"
    else err "$pkg missing from the --core layers"; fi
done < <(default_app_packages)
for pkg in nautilus sushi; do
    if echo "$names" | python3 -c "import json,sys; raise SystemExit(0 if \"$pkg\" in json.load(sys.stdin) else 1)"; then
        err "$pkg must not be installed with the desktop"
    else
        ok "$pkg is not part of the install"
    fi
done
for pkg in steam gamemode gamescope spotify-launcher btop lutris docker; do
    if in_core "$pkg"; then err "$pkg must stay removable in Store (not --core)"
    else ok "$pkg is removable in Store"; fi
done
apps="$ROOT/install/manifests/30-apps.txt"
for pkg in gamemode gamescope umu-launcher; do
    if grep -qE "^${pkg}([[:space:]]|#|$)" "$apps"; then
        ok "$pkg is a default app in 30-apps"
    else
        err "$pkg must be in 30-apps.txt (default install, not a system package)"
    fi
done
for pkg in steam spotify-launcher; do
    if grep -qE "^${pkg}([[:space:]]|#|$)" "$apps"; then
        err "$pkg must be an installer download, not a default app"
    else
        ok "$pkg is not a default app"
    fi
done
if grep -qE '^discord([[:space:]]|#|$)' "$ROOT/install/manifests/70-workstation.txt" \
    || grep -qE '^proton-vpn-gtk-app([[:space:]]|#|$)' "$ROOT/install/manifests/50-gaming.txt" \
    || grep -qE '^proton-pass-bin([[:space:]]|#|$)' "$ROOT/install/manifests/30-apps.aur.txt" \
    || grep -qxF proton-pass-bin "$ROOT/iso/releng/packages.x86_64" \
    || grep -qxF proton-pass-bin "$ROOT/iso/releng/packages.aur.x86_64" \
    || grep -qxF nvidia-utils "$ROOT/iso/releng/packages.x86_64"; then
    err "proprietary programs must not be baked into the image or an automatic manifest"
else
    ok "proprietary programs are installer downloads"
fi
if grep -q 'nvidia|nvidia-legacy' "$ROOT/install/install.sh"; then
    ok "install.sh skips the proprietary NVIDIA packages"
else
    err "install.sh must skip the proprietary NVIDIA driver unless the installer page asks"
fi
if grep -F 'core: true' "$ROOT/stow/shell/.config/quickshell/modern/Services/Store.qml" >/dev/null \
    && grep -F "protected_pkg \"\$name\"" "$ROOT/scripts/pkg-mutate.sh" >/dev/null \
    && grep -F 'pkg-manifest-names.sh" --core' "$ROOT/scripts/pkg-mutate.sh" >/dev/null; then
    ok "Store UI and pkg-mutate.sh both guard the core list"
else
    err "Store.qml must set core: true and pkg-mutate.sh must refuse --core names"
fi

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
