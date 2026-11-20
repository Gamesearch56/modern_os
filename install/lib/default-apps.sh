#!/usr/bin/env bash
# Shipped text editor, image viewer, and video player.
# install/manifests/default-apps.json is the list. Source this file;
# do not enable set -e here (callers already have it).
# Settings writes config.json only. An empty apps.defaults role uses
# the desktop id in this manifest. Launch overrides (the image viewer's
# exec) are data here, not a desktop-id branch in an opener.

default_apps_manifest() {
    local root="" repo_file=""
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/install/manifests/default-apps.json" ]; then
        root="$REPO_ROOT"
    else
        root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
    if [ ! -f "$root/install/manifests/default-apps.json" ]; then
        repo_file="${XDG_CONFIG_HOME:-${HOME:-}/.config}/modern/repo"
        if [ -f "$repo_file" ]; then
            IFS= read -r root <"$repo_file" || true
            root="${root//$'\r'/}"
        fi
    fi
    if [ -z "$root" ] || [ ! -f "$root/install/manifests/default-apps.json" ]; then
        return 1
    fi
    printf '%s\n' "$root/install/manifests/default-apps.json"
}

# op is roles|packages|stow|desktop|exec. desktop and exec take the role
# or desktop id in $2.
_default_apps_py() {
    local manifest=""
    manifest="$(default_apps_manifest)" || return 1
    python3 - "$manifest" "$1" "${2:-}" <<'PY'
import json
import sys

path, op = sys.argv[1], sys.argv[2]
extra = sys.argv[3] if len(sys.argv) > 3 else ""
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
if not isinstance(data, dict):
    sys.exit(1)

def stem(value):
    value = str(value or "")
    if value.endswith(".desktop"):
        value = value[: -len(".desktop")]
    return value

def as_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value if str(item)]
    text = str(value).strip()
    return [text] if text else []

def item(name):
    raw = data.get(name)
    return raw if isinstance(raw, dict) else {}

def ids_of(raw):
    found = as_list(raw.get("match"))
    desktop = str(raw.get("desktop") or "")
    if desktop:
        found.append(desktop)
    return {stem(one) for one in found if stem(one)}

if op == "roles":
    for name in data:
        print(name)
elif op == "packages":
    for name in data:
        for pkg in as_list(item(name).get("packages")):
            print(pkg)
elif op == "stow":
    for name in data:
        for pkg in as_list(item(name).get("stow")):
            print(pkg)
elif op == "desktop":
    desktop = str(item(extra).get("desktop") or "")
    if desktop:
        print(desktop)
elif op == "exec":
    want = stem(extra)
    if want:
        for name in data:
            raw = item(name)
            if want not in ids_of(raw):
                continue
            for arg in as_list(raw.get("exec")):
                print(arg)
            break
elif op == "window-rule":
    rule = str(item(extra).get("windowRule") or "")
    if rule:
        print(rule)
else:
    sys.exit(2)
PY
}

default_app_roles() {
    _default_apps_py roles
}

default_app_packages() {
    _default_apps_py packages
}

default_app_stow() {
    _default_apps_py stow
}

default_app_desktop() {
    _default_apps_py desktop "${1:-}"
}

# Argv (one shell word per line) for a desktop id that still uses the
# shipped app's launch override. Empty when that role has no exec.
default_app_exec_for_desktop() {
    _default_apps_py exec "${1:-}"
}

default_app_window_rule() {
    _default_apps_py window-rule "${1:-}"
}
