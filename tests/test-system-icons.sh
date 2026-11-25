#!/usr/bin/env bash
# system-icons.sh renders the colored app icons into the user's icon
# theme from install/icons/apps and never writes the templates, even
# when an older install still links the icons into the repo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$ROOT/install/icons/apps"
STOWED="$ROOT/stow/xdg/.local/share/icons/hicolor/scalable/apps"
DEFAULT_PLATE="#364479"
DEFAULT_INK="#dce1ff"
FAIL=0

err() { printf 'test-system-icons: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-system-icons: ok %s\n' "$*"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" XDG_DATA_HOME="$tmp/home/.local/share"
icons="$XDG_DATA_HOME/icons/hicolor/scalable/apps"
mkdir -p "$icons" "$XDG_CONFIG_HOME/modern"

mapfile -t names < <(cd "$TEMPLATES" && printf '%s\n' modern-*.svg)
if [ "${#names[@]}" -eq 11 ]; then
    ok "ten app icon templates"
else
    err "expected 11 templates in install/icons/apps, found ${#names[@]}"
fi
for n in "${names[@]}"; do
    [ ! -e "$STOWED/$n" ] || err "$n is still stowed, so a theme change would write the repo"
    [ -e "$STOWED/${n%.svg}-symbolic.svg" ] || err "${n%.svg}-symbolic.svg must stay stowed"
    if ! grep -q "fill=\"$DEFAULT_PLATE\"" "$TEMPLATES/$n" || ! grep -q "fill=\"$DEFAULT_INK\"" "$TEMPLATES/$n"; then
        err "$n does not carry the default wallpaper palette"
    fi
done
ok "templates carry the default palette and are not stowed"

before="$(cat "$TEMPLATES"/modern-*.svg | sha256sum)"

"$ROOT/scripts/system-icons.sh"
for n in "${names[@]}"; do
    if [ ! -f "$icons/$n" ] || [ -L "$icons/$n" ]; then
        err "no rendered $n"
    elif ! cmp -s "$TEMPLATES/$n" "$icons/$n"; then
        err "$n without tokens.json should be the default icon"
    fi
done
ok "without tokens the default icons are installed"

printf '{"color":{"primaryContainer":"#112233","onPrimaryContainer":"#ddeeff"}}\n' \
    > "$XDG_CONFIG_HOME/modern/tokens.json"
ln -sf "$TEMPLATES/${names[0]}" "$icons/${names[0]}"
"$ROOT/scripts/system-icons.sh"
for n in "${names[@]}"; do
    if [ -L "$icons/$n" ]; then
        err "$n is still a link into the repo"
    elif ! grep -q 'fill="#112233"' "$icons/$n" || ! grep -q 'fill="#ddeeff"' "$icons/$n"; then
        err "$n not recolored from tokens.json"
    fi
done
ok "a theme change recolors regular files and replaces old repo links"

if [ "$(cat "$TEMPLATES"/modern-*.svg | sha256sum)" = "$before" ]; then
    ok "templates in the repo are untouched"
else
    err "system-icons.sh wrote into install/icons/apps"
fi

rm -rf "$XDG_DATA_HOME/icons"
ln -s "$tmp/missing-dotfiles/icons" "$XDG_DATA_HOME/icons"
"$ROOT/scripts/system-icons.sh"
if [ -d "$icons" ] && [ ! -L "$XDG_DATA_HOME/icons" ] && [ -f "$icons/${names[0]}" ] \
    && [ -f "$icons/modern-settings-symbolic.svg" ] && [ ! -L "$icons/modern-settings-symbolic.svg" ]; then
    ok "a dangling icons symlink becomes a real theme"
else
    err "dangling icons symlink was not replaced with the app icons"
fi

rm -rf "$XDG_DATA_HOME/icons"
printf 'keep' >"$XDG_DATA_HOME/icons"
if "$ROOT/scripts/system-icons.sh"; then
    err "a real icons file was treated as a directory"
fi
if [ "$(cat "$XDG_DATA_HOME/icons")" = keep ]; then
    ok "a real icons file is left untouched"
else
    err "a real icons file was removed"
fi

exit "$FAIL"
