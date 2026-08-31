#!/usr/bin/env bash
# One-shot Nautilus view prefs (icon grid + size caption). Colors come
# from gtk.css / Papirus-Dark via theme-apply.sh, not here. Space preview
# is GNOME Sushi via sushi-previewer.sh (muted media overlay).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
previewer="${SCRIPT_DIR}/sushi-previewer.sh"
previewer_dir="${XDG_DATA_HOME:-$HOME/.local/share}/dbus-1/services"
mkdir -p "$previewer_dir"
rm -f "${previewer_dir}/org.gnome.NautilusPreviewer2.service"
if [ -x "$previewer" ] && [ -x /usr/lib/org.gnome.NautilusPreviewer ]; then
    printf '%s\n' "[D-BUS Service]" "Name=org.gnome.NautilusPreviewer" \
        "Exec=${previewer}" \
        >"${previewer_dir}/org.gnome.NautilusPreviewer.service"
else
    rm -f "${previewer_dir}/org.gnome.NautilusPreviewer.service"
fi

command -v gsettings >/dev/null 2>&1 || exit 0
gsettings list-schemas 2>/dev/null | grep -qx org.gnome.nautilus.preferences || exit 0

gsettings set org.gnome.nautilus.preferences default-folder-viewer 'icon-view' >/dev/null 2>&1 || true
gsettings set org.gnome.nautilus.icon-view captions "['size', 'none', 'none']" >/dev/null 2>&1 || true
