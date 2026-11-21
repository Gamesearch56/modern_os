#!/usr/bin/env bash
# The three shipped roles resolve from install/manifests/default-apps.json.
# files-open.sh --print reports the argv and does not start a program.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../install/lib/default-apps.sh
source "$ROOT/install/lib/default-apps.sh"

FAIL=0
err() { printf 'test-default-apps: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-default-apps: ok %s\n' "$*"; }

MANIFEST="$ROOT/install/manifests/default-apps.json"
DEFAULT_JSON="$ROOT/stow/modern/.config/modern/config.default.json"
CONFIG_QML="$ROOT/stow/shell/.config/quickshell/modern/Commons/Config.qml"
DESKTOP_TXT="$ROOT/install/manifests/10-desktop.txt"
RULES="$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua"

python3 - "$MANIFEST" "$DEFAULT_JSON" "$CONFIG_QML" "$DESKTOP_TXT" "$RULES" "$ROOT" <<'PY' || FAIL=1
import json, re, sys
from pathlib import Path

manifest_path, default_path, qml_path, desktop_txt, rules_path, root = sys.argv[1:]
manifest = json.load(open(manifest_path, encoding="utf-8"))
default = json.load(open(default_path, encoding="utf-8"))
qml = Path(qml_path).read_text(encoding="utf-8")
profile = Path(desktop_txt).read_text(encoding="utf-8")
rules = Path(rules_path).read_text(encoding="utf-8")
apps = default.get("apps", {}).get("defaults", {})
fail = False

def bad(msg):
    global fail
    print(f"test-default-apps: FAIL {msg}", file=sys.stderr)
    fail = True

need = ("textEditor", "imageViewer", "videoPlayer")
for role in need:
    spec = manifest.get(role)
    if not isinstance(spec, dict):
        bad(f"{role} missing from default-apps.json")
        continue
    desktop = str(spec.get("desktop") or "")
    packages = spec.get("packages") or []
    if not desktop.endswith(".desktop"):
        bad(f"{role}.desktop must be a desktop id")
    shipped = (Path(root) / "stow/xdg/.local/share/applications" / desktop).is_file()
    if not packages and not shipped:
        bad(f"{role}.packages is empty and {desktop} is not shipped in stow/xdg")
    if apps.get(role) != desktop:
        bad(
            f"config.default.json apps.defaults.{role} is {apps.get(role)!r}; "
            f"default-apps.json says {desktop!r}"
        )
    needle = f'property string {role}: "{desktop}"'
    if needle not in qml:
        bad(f"Config.qml is missing {needle}")
    for pkg in packages:
        if re.search(rf"(?m)^{re.escape(pkg)}(\s|#|$)", profile):
            bad(f"{pkg} is still inlined in 10-desktop.txt")
    stow = spec.get("stow")
    if isinstance(stow, str) and stow:
        if not (Path(root) / "stow" / stow).is_dir():
            bad(f"stow package {stow} for {role} is missing")
    rule = spec.get("windowRule")
    if isinstance(rule, str) and rule:
        if f'name = "{rule}"' not in rules:
            bad(f"window rule {rule} is not in windowrules.lua")
if fail:
    sys.exit(1)
print("test-default-apps: ok manifest matches config.default.json and Config.qml")
PY

for banned in \
    "$ROOT/scripts/files-open.sh" \
    "$ROOT/scripts/mime-defaults.sh" \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/Apps.qml" \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/DefaultApps.qml" \
    "$ROOT/install/install.sh" \
    "$ROOT/install/manifests/10-desktop.txt"
do
    if grep -E '(^|[^A-Za-z0-9_])(gedit|imv|mpv)([^A-Za-z0-9_]|$)' "$banned" >/dev/null; then
        err "$(basename "$banned") still names a shipped external app"
    else
        ok "$(basename "$banned") has no shipped external app name"
    fi
done

if grep -Fq 'default_app_packages' "$ROOT/install/install.sh" \
    && grep -Fq 'default_app_stow' "$ROOT/install/install.sh" \
    && grep -Fq 'default_app_packages' "$ROOT/scripts/pkg-manifest-names.sh"; then
    ok "installer and package list read default-apps.json"
else
    err "install.sh and pkg-manifest-names.sh must expand default-apps.json"
fi

image_desktop="$(default_app_desktop imageViewer)"
image_stem="${image_desktop%.desktop}"
mapfile -t image_exec < <(default_app_exec_for_desktop "$image_stem")
if [ "$image_stem" = "modern.imageviewer" ] && [ "${#image_exec[@]}" -eq 0 ]; then
    ok "image viewer is $image_stem, launched like any desktop entry"
else
    err "image viewer must be modern.imageviewer with no exec override (got $image_stem ${image_exec[*]})"
fi

video_desktop="$(default_app_desktop videoPlayer)"
video_stem="${video_desktop%.desktop}"
mapfile -t video_exec < <(default_app_exec_for_desktop "$video_stem")
if [ "$video_stem" = "modern.mediaplayer" ] && [ "${#video_exec[@]}" -eq 0 ] \
    && [ "$(jq -r '.videoPlayer.packages | length' "$(default_apps_manifest)")" = 0 ]; then
    ok "video player is $video_stem, with no extra package"
else
    err "video player must be modern.mediaplayer with no package or exec override (got $video_stem ${video_exec[*]})"
fi

text_desktop="$(default_app_desktop textEditor)"
text_stem="${text_desktop%.desktop}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/cfg/modern" "$tmp/.local/share/applications"
printf '[Desktop Entry]\nType=Application\nName=stub\n' >"$tmp/.local/share/applications/$image_stem.desktop"
cat >"$tmp/bin/xdg-mime" <<'EOF'
#!/bin/sh
if [ "$1" = query ] && [ "$2" = filetype ]; then
    case "$3" in
        *.png) printf '%s\n' image/png ;;
        *.txt) printf '%s\n' text/plain ;;
        *.mp4) printf '%s\n' video/mp4 ;;
        *) printf '%s\n' application/octet-stream ;;
    esac
    exit 0
fi
exit 1
EOF
chmod +x "$tmp/bin/xdg-mime"
: >"$tmp/picture.png"
: >"$tmp/note.txt"
: >"$tmp/clip.mp4"

write_cfg() {
    cat >"$tmp/cfg/modern/config.json" <<EOF
{"apps":{"defaults":{"imageViewer":$1,"textEditor":$2,"videoPlayer":$3}}}
EOF
}

run_open() {
    HOME="$tmp" XDG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" \
        MODERN_OPEN_ASSUME_EXEC=1 \
        "$ROOT/scripts/files-open.sh" --print "$1"
}

write_cfg '""' '""' '""'
got="$(run_open "$tmp/picture.png")"
if printf '%s\n' "$got" | head -n1 | grep -Fq 'modern-launch' \
    && printf '%s\n' "$got" | grep -Fxq "$image_stem"; then
    ok "empty imageViewer execs modern-launch $image_stem"
else
    err "empty imageViewer did not resolve to the manifest desktop"
    printf '%s\n' "$got" >&2
fi

got="$(run_open "$tmp/note.txt")"
if printf '%s\n' "$got" | head -n1 | grep -Fq 'modern-launch' \
    && printf '%s\n' "$got" | grep -Fxq "$text_stem"; then
    ok "empty textEditor execs modern-launch $text_stem"
else
    err "empty textEditor did not resolve to the manifest desktop"
    printf '%s\n' "$got" >&2
fi

got="$(run_open "$tmp/clip.mp4")"
if printf '%s\n' "$got" | head -n1 | grep -Fq 'modern-launch' \
    && printf '%s\n' "$got" | grep -Fxq "$video_stem"; then
    ok "empty videoPlayer execs modern-launch $video_stem"
else
    err "empty videoPlayer did not resolve to the manifest desktop"
    printf '%s\n' "$got" >&2
fi

write_cfg '"loupe.desktop"' '""' '""'
got="$(run_open "$tmp/picture.png")"
if printf '%s\n' "$got" | grep -Fxq 'loupe' \
    && ! printf '%s\n' "$got" | grep -Fxq "$image_stem"; then
    ok "a chosen image viewer replaces the shipped one"
else
    err "chosen image viewer still opened the shipped one"
    printf '%s\n' "$got" >&2
fi

write_cfg '""' '""' '""'
: >"$tmp/mystery.blob"
if HOME="$tmp" XDG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" \
    MODERN_OPEN_ASSUME_EXEC=1 \
    "$ROOT/scripts/files-open.sh" --can "$tmp/picture.png"; then
    ok "--can accepts an image the shipped viewer handles"
else
    err "--can rejected an image the shipped viewer handles"
fi
if HOME="$tmp" XDG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" \
    "$ROOT/scripts/files-open.sh" --can "$tmp/mystery.blob"; then
    err "--can accepted a file with no handler"
else
    ok "--can rejects a file with no handler"
fi

[ "$FAIL" -eq 0 ]
