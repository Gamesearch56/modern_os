#!/usr/bin/env bash
# Hermetic calamares-late.sh clone tests. No root, no GitHub.
# shellcheck disable=SC2015
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATE="$ROOT/iso/airootfs/usr/lib/modern/calamares-late.sh"
FAIL=0
err() { printf 'test-calamares-late: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-calamares-late: ok %s\n' "$*"; }

[ -x "$LATE" ] || { err "missing $LATE"; exit 1; }

if grep -F 'DisableSandbox' "$LATE" >/dev/null \
    && grep -F -- '--disable-sandbox' "$LATE" >/dev/null \
    && grep -F 'pacman --disable-sandbox -Sy --noconfirm archlinux-keyring' "$LATE" >/dev/null \
    && grep -F 'pacman-key --init' "$LATE" >/dev/null \
    && grep -F 'pacman-key --populate archlinux' "$LATE" >/dev/null \
    && grep -F '[multilib]' "$LATE" >/dev/null \
    && grep -F 'sudo pacman --disable-sandbox -S --needed --noconfirm' "$LATE" >/dev/null \
    && grep -F 'matugen-bin' "$LATE" >/dev/null \
    && grep -F 'bibata-cursor-theme-bin' "$LATE" >/dev/null \
    && grep -F 'overlay_pin_aur_names' "$LATE" >/dev/null \
    && grep -F 'bibata-cursor-theme([[:space:]]|#|$)' "$LATE" >/dev/null \
    && grep -F 'NoExtract = etc/resolv.conf etc/nsswitch.conf' "$LATE" >/dev/null \
    && grep -F 'chattr +i' "$LATE" >/dev/null \
    && grep -F 'ensure_pipewire_jack' "$LATE" >/dev/null \
    && grep -F 'pipewire-jack' "$LATE" >/dev/null \
    && grep -F 'IgnorePkg' "$LATE" >/dev/null \
    && grep -F 'overlay_pin_install_native' "$LATE" >/dev/null \
    && grep -F 'modern ISO pin overlay' "$LATE" >/dev/null \
    && grep -F 'MODERN_SKIP_AUR=1' "$LATE" >/dev/null \
    && grep -F 'aur_pkg_present' "$LATE" >/dev/null; then
    ok "desktop phase syncs pacman databases, enables multilib, patches pin pacman"
else
    err "desktop phase must init the target keyring, IgnorePkg jack2, overlay pin install_native, and pacman -Sy before install.sh"
fi

PROVISION="$ROOT/install/system/provision-iso.sh"
GREETD_LIB="$ROOT/install/lib/greetd.sh"
if grep -F 'zram-generator.conf' "$PROVISION" >/dev/null \
    && grep -F '99-modern-zram.conf' "$PROVISION" >/dev/null \
    && grep -F '60-modern-rotational-bfq.rules' "$PROVISION" >/dev/null \
    && grep -F 'min(ram / 2, 4096)' "$ROOT/install/system/zram/zram-generator.conf" >/dev/null \
    && grep -F 'vm.swappiness = 180' "$ROOT/install/system/sysctl.d/99-modern-zram.conf" >/dev/null \
    && grep -F 'ATTR{queue/rotational}=="1"' "$ROOT/install/system/udev/60-modern-rotational-bfq.rules" >/dev/null \
    && ! grep -F 'sysctl --system' "$PROVISION" >/dev/null; then
    ok "ISO provision stages zram and bfq for spinning disks, not the live installer"
else
    err "provision-iso.sh must install zram + zram sysctl + rotational bfq, and must not sysctl the installer"
fi
if grep -E '^[[:space:]]*systemctl enable [^ ]+ [^ ]+' "$GREETD_LIB" >/dev/null \
    || grep -E '^[[:space:]]*systemctl enable [^ ]+ [^ ]+' "$PROVISION" >/dev/null; then
    err "greetd enable_unit must enable one unit per call — one missing unit aborts the rest"
else
    ok "greetd enables one unit per call"
fi

units_ok=1
for unit in NetworkManager.service greetd.service; do
    grep -F "enable_unit $unit required" "$GREETD_LIB" >/dev/null || units_ok=0
done
for unit in bluetooth.service systemd-timesyncd.service; do
    grep -F "enable_unit $unit optional" "$GREETD_LIB" >/dev/null || units_ok=0
done
if [ "$units_ok" -eq 1 ]; then
    ok "greetd hard-fails only on NetworkManager and greetd"
else
    err "greetd_apply must mark each enabled unit required or optional"
fi
if grep -F 'systemctl --root=/ is-enabled' "$GREETD_LIB" >/dev/null \
    && grep -F 'systemctl --root=/ enable' "$GREETD_LIB" >/dev/null \
    && ! grep -E '^[[:space:]]*if systemctl is-enabled ' "$GREETD_LIB" >/dev/null; then
    ok "unit enable checks this system, not the live session"
else
    err "enable_unit must use systemctl --root=/ so the live NetworkManager does not skip the install"
fi

if python3 - "$ROOT/install/system/greetd/config.toml" "$ROOT/install/system/greetd/kiosk.sh" "$ROOT/install/system/greetd/hyprland.lua" <<'PY'; then
import re, shlex, sys
from pathlib import Path
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'^command\s*=\s*"([^"]*)"', text, re.M)
assert m, "no default_session command"
argv = shlex.split(m.group(1))
assert argv and argv[0].endswith("kiosk.sh"), f"unexpected session command {argv}"
kiosk = Path(sys.argv[2]).read_text(encoding="utf-8")
assert "GREETD_SOCK" in kiosk, "kiosk.sh must keep GREETD_SOCK"
assert "start-hyprland --no-nixgl -- --config /etc/greetd/hyprland.lua" in kiosk, (
    "kiosk.sh must exec start-hyprland with Hyprland flags after --"
)
lua = Path(sys.argv[3]).read_text(encoding="utf-8")
assert "GREETD_SOCK" in lua, "hyprland.lua must forward GREETD_SOCK to qs"
assert "awww-daemon" not in lua, "greeter Hyprland must not start awww"
PY
    ok "greetd kiosk keeps GREETD_SOCK and hands Hyprland flags past --"
else
    err "greetd kiosk.sh must re-export GREETD_SOCK and exec start-hyprland --no-nixgl -- --config"
fi

# greetd's sysusers.d leaves the home field unset, so greeter already exists
# with / and the useradd in greetd_apply is skipped.
if grep -E 'usermod.*(--move-home|[[:space:]]-m[[:space:]])' "$GREETD_LIB" >/dev/null \
    || grep -E 'usermod.*(--move-home|[[:space:]]-m[[:space:]])' "$PROVISION" >/dev/null; then
    err "greetd_apply must never move the greeter home — the old one is /"
elif grep -E 'usermod --home .+ greeter' "$GREETD_LIB" >/dev/null \
    && grep -F 'cannot start' "$GREETD_LIB" >/dev/null \
    && grep -F 'greetd_apply' "$PROVISION" >/dev/null; then
    ok "greetd_apply relocates a greeter that greetd's sysusers left at /"
else
    err "greetd_apply must move the greeter off / and fail loudly if it cannot"
fi

# The Keyboard step must reach Hyprland (config.json) and greetd's
# keyboard.json snapshot, not just /etc/vconsole.conf and the X11 snippet.
kbdir="$(mktemp -d)"
kbcfg="$kbdir/.config/modern"
mkdir -p "$kbcfg"
cat >"$kbdir/00-keyboard.conf" <<'EOF'
# Read and parsed by systemd-localed.
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "de"
        Option "XkbVariant" "nodeadkeys"
EndSection
EOF
printf '{"input":{"kbLayout":"us","kbVariant":"","repeatRate":25}}\n' \
    >"$kbcfg/config.json"
printf 'hl.monitor({ output = "" })\n' >"$kbdir/hyprland.lua"
{
    printf 'set -euo pipefail\n'
    printf 'log() { printf "provision-iso: %%s\\n" "$*"; }\n'
    # shellcheck disable=SC2016  # written literally into the generated script
    printf 'USERNAME="$(id -un)"\n'
    printf 'USER_HOME=%s\n' "$kbdir"
    printf 'MODERN_XORG_KB=%s/00-keyboard.conf\n' "$kbdir"
    printf 'MODERN_GREETD_LUA=%s/hyprland.lua\n' "$kbdir"
    printf 'MODERN_SESSION_DIR=%s\n' "$kbdir"
    printf 'SESSION_DIR=%s\n' "$kbdir"
    sed -n '/^XORG_KB=/,/^apply_keyboard_layout$/p' "$PROVISION"
} >"$kbdir/run.sh"
if bash "$kbdir/run.sh" >"$kbdir/out" 2>&1; then
    got_layout="$(jq -r '.input.kbLayout' "$kbcfg/config.json")"
    got_variant="$(jq -r '.input.kbVariant' "$kbcfg/config.json")"
    got_rate="$(jq -r '.input.repeatRate' "$kbcfg/config.json")"
    got_snap="$(jq -r '.layout + "/" + .variant' "$kbdir/keyboard.json" 2>/dev/null || true)"
    if [ "$got_layout" = de ] && [ "$got_variant" = nodeadkeys ] && [ "$got_rate" = 25 ] \
        && [ "$got_snap" = "de/nodeadkeys" ]; then
        ok "Keyboard step layout reaches config.json and greetd"
    else
        err "layout not propagated: config=$got_layout/$got_variant rate=$got_rate snap=$got_snap $(cat "$kbdir/out")"
    fi
else
    err "apply_keyboard_layout failed: $(cat "$kbdir/out")"
fi

rm -f "$kbdir/00-keyboard.conf"
if bash "$kbdir/run.sh" >"$kbdir/out2" 2>&1 \
    && grep -F 'keeping the config.json default layout' "$kbdir/out2" >/dev/null; then
    ok "missing X11 keyboard snippet leaves config.json alone"
else
    err "a missing X11 snippet must not abort provision: $(cat "$kbdir/out2")"
fi
rm -rf "$kbdir"

# The Locale step must reach Commons/I18n.qml (language.ui in config.json),
# not just /etc/locale.conf.
langdir="$(mktemp -d)"
langcfg="$langdir/.config/modern"
mkdir -p "$langcfg/translations"
printf '{"session":{"unlock":"Unlock"}}\n' >"$langcfg/translations/en.json"
printf '{"session":{"unlock":"Entsperren"}}\n' >"$langcfg/translations/de.json"
printf 'LANG=de_DE.UTF-8\n' >"$langdir/locale.conf"
printf '{"language":{"ui":"en","fallback":"en","dateFormat":"DD.MM.YYYY"}}\n' \
    >"$langcfg/config.json"
{
    printf 'set -euo pipefail\n'
    printf 'log() { printf "provision-iso: %%s\\n" "$*"; }\n'
    # shellcheck disable=SC2016  # written literally into the generated script
    printf 'USERNAME="$(id -un)"\n'
    printf 'USER_HOME=%s\n' "$langdir"
    printf 'MODERN_LOCALE_CONF=%s/locale.conf\n' "$langdir"
    sed -n '/^LOCALE_CONF=/,/^apply_system_language$/p' "$PROVISION"
} >"$langdir/run.sh"
if bash "$langdir/run.sh" >"$langdir/out" 2>&1; then
    got_ui="$(jq -r '.language.ui' "$langcfg/config.json")"
    got_fallback="$(jq -r '.language.fallback' "$langcfg/config.json")"
    got_date="$(jq -r '.language.dateFormat' "$langcfg/config.json")"
    if [ "$got_ui" = de ] && [ "$got_fallback" = en ] && [ "$got_date" = DD.MM.YYYY ]; then
        ok "Locale step language reaches config.json"
    else
        err "language not propagated: ui=$got_ui fallback=$got_fallback date=$got_date $(cat "$langdir/out")"
    fi
else
    err "apply_system_language failed: $(cat "$langdir/out")"
fi

# Anything the installer can produce that has no translations/<code>.json
# must land on English, not on a file I18n cannot open.
printf 'LANG=fr_FR.UTF-8\n' >"$langdir/locale.conf"
if bash "$langdir/run.sh" >"$langdir/out2" 2>&1 \
    && [ "$(jq -r '.language.ui' "$langcfg/config.json")" = en ]; then
    ok "unsupported LANG falls back to English"
else
    err "an unshipped language must fall back to en: $(cat "$langdir/out2")"
fi

printf '{"language":{"ui":"de"}}\n' >"$langcfg/config.json"
rm -f "$langdir/locale.conf"
if bash "$langdir/run.sh" >"$langdir/out3" 2>&1 \
    && grep -F 'keeping the config.json default language' "$langdir/out3" >/dev/null \
    && [ "$(jq -r '.language.ui' "$langcfg/config.json")" = de ]; then
    ok "missing locale.conf leaves config.json alone"
else
    err "a missing locale.conf must not abort provision: $(cat "$langdir/out3")"
fi
rm -rf "$langdir"

# xdg-user-dirs-update follows LANG. The live ISO is often English, so
# as_user must pass the target's locale.conf, not inherit the installer.
udir="$(mktemp -d)"
printf 'LANG=de_DE.UTF-8\n' >"$udir/locale.conf"
{
    printf 'set -euo pipefail\n'
    printf 'MODERN_LOCALE_CONF=%s/locale.conf\n' "$udir"
    sed -n '/^user_locale_lang()/,/^}$/p' "$LATE"
    printf 'user_locale_lang\n'
} >"$udir/lang.sh"
if [ "$(bash "$udir/lang.sh")" = "de_DE.UTF-8" ]; then
    ok "user_locale_lang reads LANG from locale.conf"
else
    err "user_locale_lang: $(bash "$udir/lang.sh" 2>&1 || true)"
fi
{
    printf 'set -euo pipefail\n'
    printf 'MODERN_LATE_TEST=1\n'
    printf 'USERNAME=test\n'
    printf 'USER_HOME=%s\n' "$udir"
    printf 'MODERN_LOCALE_CONF=%s/locale.conf\n' "$udir"
    sed -n '/^user_locale_lang()/,/^}$/p' "$LATE"
    sed -n '/^as_user()/,/^}$/p' "$LATE"
    printf 'as_user printenv LANG\n'
} >"$udir/as.sh"
if [ "$(bash "$udir/as.sh")" = "de_DE.UTF-8" ]; then
    ok "as_user exports the target LANG"
else
    err "as_user LANG: $(bash "$udir/as.sh" 2>&1 || true)"
fi
rm -rf "$udir"

if grep -A 40 '^as_user()' "$LATE" | grep -q 'LANG='; then
    ok "as_user passes LANG to install.sh"
else
    err "as_user must export LANG so xdg-user-dirs-update is localized"
fi

# The greeter picks its strings up from chrome.json (session-chrome-sync.sh
# from language.ui), so provision has to set the language before wallpaper-sync.
lang_line="$(grep -n '^apply_system_language$' "$PROVISION" | head -1 | cut -d: -f1)"
sync_line="$(grep -n 'wallpaper-sync.sh' "$PROVISION" | head -1 | cut -d: -f1)"
seed_line="$(grep -n 'xdg-capture-seed.sh' "$PROVISION" | head -1 | cut -d: -f1)"
# shellcheck disable=SC2016  # fixed string; $USERNAME is the call site, not this script
greet_line="$(grep -nF 'greetd_apply "$USERNAME"' "$PROVISION" | head -1 | cut -d: -f1)"
if [ -n "$lang_line" ] && [ -n "$sync_line" ] && [ "$lang_line" -lt "$sync_line" ]; then
    ok "the language is set before the greeter's chrome.json is baked"
else
    err "apply_system_language must run before wallpaper-sync.sh (greeter strings)"
fi
if [ -n "$lang_line" ] && [ -n "$greet_line" ] && [ "$lang_line" -lt "$greet_line" ]; then
    ok "greetd copies the login screen after the installed language"
else
    err "greetd_apply must run after apply_system_language so chrome.json is not baked in English"
fi
if [ -n "$lang_line" ] && [ -n "$seed_line" ] && [ -n "$sync_line" ] \
    && [ "$lang_line" -lt "$seed_line" ] && [ "$seed_line" -lt "$sync_line" ]; then
    ok "capture folders are seeded after the installed language"
else
    err "xdg-capture-seed.sh must run after apply_system_language and before wallpaper-sync"
fi

CHROME="$ROOT/scripts/session-chrome-sync.sh"
syncdir="$(mktemp -d)"
mkdir -p "$syncdir/modern/translations" "$syncdir/shared"
printf '{"session":{"unlock":"Unlock","password":"Password","user":"User"}}\n' \
    >"$syncdir/modern/translations/en.json"
printf '{"session":{"unlock":"Entsperren","password":"Passwort","user":"Benutzer"}}\n' \
    >"$syncdir/modern/translations/de.json"
sync_cfg() {
    printf '{"typography":{"ui":"Inter"},"design":{"cornerRounding":1,"transparency":0.85},"language":{"ui":"%s"}}\n' \
        "$1" >"$syncdir/modern/config.json"
}
sync_cfg de
if env XDG_CONFIG_HOME="$syncdir" MODERN_SESSION_DIR="$syncdir/shared" bash "$CHROME" >"$syncdir/out" 2>&1 \
    && [ "$(jq -r '.strings.unlock' "$syncdir/shared/chrome.json")" = Entsperren ] \
    && [ "$(jq -r '.strings.user' "$syncdir/shared/chrome.json")" = Benutzer ]; then
    ok "greeter chrome.json follows the installed language"
else
    err "chrome.json did not pick up the German session strings: $(cat "$syncdir/out")"
fi
sync_cfg fr
if env XDG_CONFIG_HOME="$syncdir" MODERN_SESSION_DIR="$syncdir/shared" bash "$CHROME" >"$syncdir/out2" 2>&1 \
    && [ "$(jq -r '.strings.unlock' "$syncdir/shared/chrome.json")" = Unlock ]; then
    ok "greeter falls back to English for an unshipped language"
else
    err "chrome.json must fall back to en.json: $(cat "$syncdir/out2")"
fi
rm -rf "$syncdir"

# bluez-utils is bluetoothctl only; bluetooth.service and org.bluez are bluez.
if grep -E '^[[:space:]]*bluez([[:space:]]|#|$)' "$ROOT/install/manifests/10-desktop.txt" >/dev/null \
    && grep -F 'ensure_provision_units' "$LATE" >/dev/null \
    && grep -F 'bluez bluez-utils networkmanager greetd' "$LATE" >/dev/null; then
    ok "bluez is in the desktop manifest and installed before provision"
else
    err "bluetooth.service needs bluez in 10-desktop.txt and in ensure_provision_units"
fi

if grep -F 'install.sh --profile m0 --yes failed' "$LATE" >/dev/null \
    && grep -F 'install/install.log' "$LATE" >/dev/null \
    && grep -E 'tail -n 40' "$LATE" >/dev/null; then
    ok "desktop phase puts install.sh stdout and install.log in the error dialog"
else
    err "desktop phase must dump install.sh output on failure (Calamares hides stderr)"
fi

if grep -F 'install -d -m 0750 /etc /etc/sudoers.d' "$LATE" >/dev/null; then
    err "desktop phase must not chmod /etc to 0750 (gitconfig EACCES)"
elif grep -F 'chmod a+rx /etc' "$LATE" >/dev/null \
    && grep -F 'install -d -m 0750 /etc/sudoers.d' "$LATE" >/dev/null; then
    ok "desktop phase leaves /etc world-executable"
else
    err "desktop phase must chmod a+rx /etc and only 0750 sudoers.d"
fi

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

run_late() {
    local -a extra=()
    if [ -n "${MODERN_LATE_CLONE_URL:-}" ]; then
        extra+=(MODERN_LATE_CLONE_URL="$MODERN_LATE_CLONE_URL")
    fi
    if [ -n "${MODERN_LATE_BUNDLE:-}" ]; then
        extra+=(MODERN_LATE_BUNDLE="$MODERN_LATE_BUNDLE")
    fi
    if [ -n "${MODERN_LATE_RESOLV:-}" ]; then
        extra+=(MODERN_LATE_RESOLV="$MODERN_LATE_RESOLV")
    fi
    if [ -n "${MODERN_LATE_NSSWITCH:-}" ]; then
        extra+=(MODERN_LATE_NSSWITCH="$MODERN_LATE_NSSWITCH")
    fi
    if [ -n "${MODERN_LATE_STRIP_ROOT:-}" ]; then
        extra+=(MODERN_LATE_STRIP_ROOT="$MODERN_LATE_STRIP_ROOT")
    fi
    if [ -n "${MODERN_LATE_EFI_DIR:-}" ]; then
        extra+=(MODERN_LATE_EFI_DIR="$MODERN_LATE_EFI_DIR")
    fi
    if [ -n "${MODERN_DEPLOY_KEY_SRC:-}" ]; then
        extra+=(MODERN_DEPLOY_KEY_SRC="$MODERN_DEPLOY_KEY_SRC")
    fi
    env -u MODERN_PROTECT_HOME \
        MODERN_LATE_TEST=1 \
        MODERN_LATE_LOG="$WORKDIR/late.log" \
        MODERN_LATE_PIN_FILE="$WORKDIR/iso-pin" \
        MODERN_LATE_USER_HOME="$WORKDIR/home" \
        MODERN_CALAMARES_USER=tester \
        "${extra[@]}" \
        bash "$LATE" "$@"
}

: >"$WORKDIR/iso-pin"
if out="$(run_late clone 2>&1)"; then
    err "empty pin must fail"
else
    printf '%s\n' "$out" | grep -q 'ISO pin is not a release tag' \
        && grep -q 'ISO pin is not a release tag' "$WORKDIR/late.log" \
        && ok "invalid pin dies on stdout and in the log" \
        || err "invalid pin message missing from stdout or log: $out"
fi

printf 'v0.0.99\n' >"$WORKDIR/iso-pin"
missing="$WORKDIR/missing.git"
git init -q --bare "$missing"
if out="$(MODERN_LATE_CLONE_URL="$missing" run_late clone 2>&1)"; then
    err "missing tag clone must fail"
else
    printf '%s\n' "$out" | grep -q 'git clone of v0.0.99 failed' \
        && ok "missing-tag clone reports git failure on stdout" \
        || err "clone failure not on stdout: $out"
fi

origin="$WORKDIR/origin.git"
git init -q --bare "$origin"
src="$WORKDIR/src"
git init -q "$src"
git -C "$src" config user.email test@example.com
git -C "$src" config user.name tester
git -C "$src" config commit.gpgsign false
mkdir -p "$src/install"
printf 'repo\n' >"$src/README"
git -C "$src" add README install
git -C "$src" commit -q -m "seed"
git -C "$src" tag v0.9.9
git -C "$src" push -q "$origin" v0.9.9

printf 'v0.9.9\n' >"$WORKDIR/iso-pin"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_CLONE_URL="$origin" run_late clone 2>&1)"; then
    [ -f "$WORKDIR/home/modern_dotfile/README" ] \
        && printf '%s\n' "$out" | grep -q 'cloned v0.9.9' \
        && ok "clone of local file:// tag lands the tree" \
        || err "clone succeeded but tree missing: $out"
else
    err "local tag clone failed: $out"
fi

bundle="$WORKDIR/bundle"
mkdir -p "$bundle/install"
printf 'from-bundle\n' >"$bundle/README"
printf 'v0.1.0\n' >"$WORKDIR/iso-pin"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$bundle" MODERN_LATE_CLONE_URL="$missing" run_late clone 2>&1)"; then
    [ -f "$WORKDIR/home/modern_dotfile/README" ] \
        && grep -q from-bundle "$WORKDIR/home/modern_dotfile/README" \
        && printf '%s\n' "$out" | grep -q 'using ISO bundle' \
        && ok "ISO bundle copy does not need git" \
        || err "bundle copy succeeded but tree missing: $out"
else
    err "ISO bundle copy failed: $out"
fi

# The image may ship the deploy key mode 0644 (mkarchiso drops modes).
# The clone phase must leave it 0600 in the new home and delete the source.
key_src="$WORKDIR/deploy-src"
printf 'deploy-key-bytes\n' >"$key_src"
chmod 0644 "$key_src"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_DEPLOY_KEY_SRC="$key_src" MODERN_LATE_BUNDLE="$bundle" \
    MODERN_LATE_CLONE_URL="$missing" run_late clone 2>&1)"; then
    dest_key="$WORKDIR/home/.config/modern/deploy_key"
    if [ ! -e "$key_src" ] && [ "$(cat "$dest_key" 2>/dev/null)" = "deploy-key-bytes" ] \
        && [ "$(stat -c '%a' "$dest_key")" = 600 ] \
        && [ "$(stat -c '%a' "$WORKDIR/home/.config/modern")" = 700 ]; then
        ok "deploy key moves into the new home as mode 600 and leaves the image"
    else
        err "deploy key not installed privately: src=$(ls -l "$key_src" 2>&1) dest=$(ls -l "$dest_key" 2>&1)"
    fi
else
    err "clone with a deploy key failed: $out"
fi
kept="$WORKDIR/kept-secret"
printf 'keep-me\n' >"$kept"
ln -s "$kept" "$WORKDIR/deploy-link"
rm -rf "${WORKDIR:?}/home"
if MODERN_DEPLOY_KEY_SRC="$WORKDIR/deploy-link" MODERN_LATE_BUNDLE="$bundle" \
    MODERN_LATE_CLONE_URL="$missing" run_late clone >/dev/null 2>&1 \
    && [ ! -e "$WORKDIR/deploy-link" ] && [ "$(cat "$kept")" = keep-me ] \
    && [ ! -e "$WORKDIR/home/.config/modern/deploy_key" ]; then
    ok "deploy key symlink is dropped and its target is left alone"
else
    err "deploy key symlink was followed or its target was removed"
fi

# mkarchiso strips modes off the bundle, so the clone phase has to put the
# exec bit back or provision-iso.sh and theme-apply.sh never run.
stripped="$WORKDIR/stripped"
rm -rf "$stripped"
git clone -q "$src" "$stripped" 2>/dev/null
mkdir -p "$stripped/install/system" "$stripped/scripts"
printf '#!/usr/bin/env bash\n' >"$stripped/install/system/provision-iso.sh"
printf '#!/usr/bin/env bash\n' >"$stripped/scripts/theme-apply.sh"
git -C "$stripped" add install scripts
git -C "$stripped" update-index --chmod=+x install/system/provision-iso.sh scripts/theme-apply.sh
chmod -R a-x+X "$stripped/install" "$stripped/scripts"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$stripped" MODERN_LATE_CLONE_URL="$missing" run_late clone 2>&1)"; then
    if [ -x "$WORKDIR/home/modern_dotfile/install/system/provision-iso.sh" ] \
        && [ -x "$WORKDIR/home/modern_dotfile/scripts/theme-apply.sh" ]; then
        ok "clone phase restores exec bits mkarchiso stripped"
    else
        err "exec bits not restored on the mode-stripped bundle: $out"
    fi
else
    err "mode-stripped bundle clone failed: $out"
fi

dangling="$WORKDIR/etc/resolv.conf"
mkdir -p "$WORKDIR/etc"
ln -s "$WORKDIR/etc/missing-resolv" "$dangling"
printf 'v0.1.0\n' >"$WORKDIR/iso-pin"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$bundle" MODERN_LATE_RESOLV="$dangling" run_late clone 2>&1)"; then
    grep -q 'nameserver 1.1.1.1' "$dangling" \
        && [ ! -L "$dangling" ] \
        && ok "dangling resolv.conf symlink is replaced before write" \
        || err "resolv.conf still broken after clone: $(ls -l "$dangling" 2>&1) $out"
else
    err "clone with dangling resolv.conf failed: $out"
fi

stub="$WORKDIR/etc/stub-resolv.conf"
printf 'nameserver 127.0.0.53\noptions edns0 trust-ad\n' >"$stub"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$bundle" MODERN_LATE_RESOLV="$stub" run_late clone 2>&1)"; then
    grep -q 'nameserver 1.1.1.1' "$stub" \
        && ! grep -q '127.0.0.53' "$stub" \
        && ok "systemd stub nameserver is replaced with public DNS" \
        || err "stub resolv.conf not rewritten: $(cat "$stub") $out"
else
    err "clone with stub resolv.conf failed: $out"
fi

upstream="$WORKDIR/etc/upstream-resolv.conf"
printf 'nameserver 8.8.8.8\n' >"$upstream"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$bundle" MODERN_LATE_RESOLV="$upstream" run_late clone 2>&1)"; then
    grep -qx 'nameserver 8.8.8.8' "$upstream" \
        && ok "upstream nameserver is left in place" \
        || err "upstream resolv.conf was rewritten: $(cat "$upstream") $out"
else
    err "clone with upstream resolv.conf failed: $out"
fi

mixed="$WORKDIR/etc/mixed-resolv.conf"
printf 'nameserver 127.0.0.53\nnameserver 8.8.8.8\n' >"$mixed"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$bundle" MODERN_LATE_RESOLV="$mixed" run_late clone 2>&1)"; then
    grep -qx 'nameserver 8.8.8.8' "$mixed" \
        && ! grep -q '127.0.0.53' "$mixed" \
        && ok "loopback nameserver is stripped when an upstream exists" \
        || err "mixed resolv.conf not stripped: $(cat "$mixed") $out"
else
    err "clone with mixed resolv.conf failed: $out"
fi

nss="$WORKDIR/etc/nsswitch.conf"
printf 'passwd: files\nhosts: mymachines resolve [!UNAVAIL=return] files dns\n' >"$nss"
rm -rf "${WORKDIR:?}/home"
if out="$(MODERN_LATE_BUNDLE="$bundle" MODERN_LATE_NSSWITCH="$nss" run_late clone 2>&1)"; then
    grep -qx 'hosts: files dns' "$nss" \
        && grep -q '^passwd: files' "$nss" \
        && ok "nsswitch hosts is files dns (not systemd-resolved)" \
        || err "nsswitch not rewritten: $(cat "$nss") $out"
else
    err "clone with nsswitch rewrite failed: $out"
fi

aur="$WORKDIR/20-theming.aur.txt"
printf '%s\n' \
    'matugen' \
    'bibata-cursor-theme     # gtk-cursor-theme-name' \
    'matugen-bin' \
    'bibata-cursor-theme-bin' >"$aur"
sed -i -E \
    -e 's/^[[:space:]]*matugen([[:space:]]|#|$)/matugen-bin\1/' \
    -e 's/^[[:space:]]*bibata-cursor-theme([[:space:]]|#|$)/bibata-cursor-theme-bin\1/' \
    "$aur"
if grep -qx 'matugen-bin' "$aur" \
    && grep -qE '^bibata-cursor-theme-bin[[:space:]]+#' "$aur" \
    && ! grep -qE '^matugen$' "$aur" \
    && ! grep -qE '^bibata-cursor-theme[[:space:]]' "$aur"; then
    ok "pin AUR rewrite maps commented bibata-cursor-theme to -bin"
else
    err "pin AUR rewrite missed comment-bearing bibata line: $(cat "$aur")"
fi

# The archiso hook in the target's initramfs mounts $archisodevice, which a
# disk boot never sets, so the drop-in surviving means a rescue shell.
if grep -F 'the target would boot to a rescue shell' "$LATE" >/dev/null; then
    ok "strip phase hard-fails if the archiso mkinitcpio drop-in survives"
else
    err "strip phase must die when etc/mkinitcpio.conf.d/archiso.conf is still there"
fi

# unpackfs copies the whole live overlay, so a new live-only file is a new
# live-only file on every installed disk until it is listed for removal.
uncovered=()
# etc/calamares goes wholesale, so its module configs need no entry of
# their own — but only if the script really does remove the directory.
grep -E 'rm -rf .+/etc/calamares' "$LATE" >/dev/null \
    || err "strip phase must remove etc/calamares"
while IFS= read -r tracked; do
    rel="${tracked#iso/airootfs/}"
    case "$rel" in etc/calamares/*) continue ;; esac
    grep -qF "    $rel" "$LATE" || uncovered+=("$rel")
done < <(git -C "$ROOT" ls-files iso/airootfs | grep -i 'live')
if [ ${#uncovered[@]} -eq 0 ]; then
    ok "every live-only file in the overlay is on the strip list"
else
    err "strip list misses live overlay files: ${uncovered[*]}"
fi

STRIPROOT="$WORKDIR/target"
strip_gone=(
    etc/mkinitcpio.conf.d/archiso.conf
    etc/mkinitcpio.d/linux.preset
    etc/systemd/system/getty@tty1.service
    etc/systemd/system/getty@tty1.service.d/autologin.conf
    etc/systemd/system/etc-pacman.d-gnupg.mount
    etc/systemd/system/pacman-init.service
    etc/systemd/system/multi-user.target.wants/pacman-init.service
    etc/systemd/system/multi-user.target.wants/iwd.service
    etc/systemd/system/greetd.service.wants/modern-live-setup.service
    usr/lib/systemd/system/modern-live-setup.service
    usr/lib/modern/live-setup.sh
    usr/local/bin/xdg-open
    etc/sudoers.d/99-liveuser
    etc/polkit-1/rules.d/49-modern-liveuser.rules
    etc/calamares/settings.conf
    root/.zlogin
    etc/systemd/system/multi-user.target.wants/systemd-networkd.service
    etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service
    etc/systemd/network/20-ethernet.network
    etc/systemd/network/20-wlan.network
    etc/NetworkManager/conf.d/wifi-backend.conf
)
strip_kept=(
    etc/mkinitcpio.d/linux-zen.preset
    etc/mkinitcpio.conf
    etc/systemd/system/default.target
    etc/systemd/system/display-manager.service
    etc/systemd/system/graphical.target.wants/greetd.service
    etc/systemd/system/multi-user.target.wants/NetworkManager.service
    usr/lib/modern/calamares-late.sh
    usr/lib/modern/iso-pin
)
for p in "${strip_gone[@]}" "${strip_kept[@]}"; do
    mkdir -p "$STRIPROOT/$(dirname "$p")"
    : >"$STRIPROOT/$p"
done
if out="$(MODERN_LATE_STRIP_ROOT="$STRIPROOT" run_late strip 2>&1)"; then
    left=()
    gone=()
    for p in "${strip_gone[@]}"; do
        if [ -e "$STRIPROOT/$p" ]; then left+=("$p"); fi
    done
    for p in "${strip_kept[@]}"; do
        if [ ! -e "$STRIPROOT/$p" ]; then gone+=("$p"); fi
    done
    if [ ${#left[@]} -eq 0 ] && [ ${#gone[@]} -eq 0 ] \
        && grep -F "PRESETS=('default' 'fallback')" \
            "$STRIPROOT/etc/mkinitcpio.d/linux-zen.preset" >/dev/null; then
        ok "strip phase clears live-only files and keeps the installed ones"
    else
        err "strip left ${left[*]:-nothing} and wrongly removed ${gone[*]:-nothing}"
    fi
else
    err "strip phase failed: $out"
fi

# BIOS: grub-mkconfig only finds /boot/vmlinuz-*, which mkarchiso removed.
BIOSROOT="$WORKDIR/bios"
mkdir -p "$BIOSROOT/usr/lib/modules/6.99.0-zen1-1-zen" "$BIOSROOT/etc/mkinitcpio.d"
printf 'linux-zen\n' >"$BIOSROOT/usr/lib/modules/6.99.0-zen1-1-zen/pkgbase"
printf 'kernel\n' >"$BIOSROOT/usr/lib/modules/6.99.0-zen1-1-zen/vmlinuz"
printf "PRESETS=('default' 'fallback')\n" >"$BIOSROOT/etc/mkinitcpio.d/linux-zen.preset"
if MODERN_LATE_STRIP_ROOT="$BIOSROOT" MODERN_LATE_EFI_DIR="$WORKDIR/no-efi" run_late biosboot >/dev/null 2>&1 \
    && [ -f "$BIOSROOT/boot/vmlinuz-linux-zen" ] \
    && grep -qF 'ALL_kver="/boot/vmlinuz-linux-zen"' "$BIOSROOT/etc/mkinitcpio.d/linux-zen.preset"; then
    ok "biosboot puts linux-zen in /boot and pins ALL_kver on BIOS"
else
    err "biosboot must copy vmlinuz to /boot and add ALL_kver without UEFI"
fi
EFIROOT="$WORKDIR/efi"
mkdir -p "$EFIROOT/usr/lib/modules/6.99.0-zen1-1-zen" "$WORKDIR/efi-fw"
printf 'linux-zen\n' >"$EFIROOT/usr/lib/modules/6.99.0-zen1-1-zen/pkgbase"
printf 'kernel\n' >"$EFIROOT/usr/lib/modules/6.99.0-zen1-1-zen/vmlinuz"
if MODERN_LATE_STRIP_ROOT="$EFIROOT" MODERN_LATE_EFI_DIR="$WORKDIR/efi-fw" run_late biosboot >/dev/null 2>&1 \
    && [ ! -e "$EFIROOT/boot/vmlinuz-linux-zen" ]; then
    ok "biosboot leaves UEFI installs to systemd-boot"
else
    err "biosboot must not touch /boot on UEFI"
fi

# Live-only packages: every name is on the ISO, none is a desktop manifest.
live_pkgs="$(sed -n '/^LIVE_ONLY_PKGS=(/,/^)/p' "$LATE" | sed '1d;$d' | tr ' ' '\n' | sed '/^$/d')"
manifest_names="$("$ROOT/scripts/pkg-manifest-names.sh")"
bad=""
for p in $live_pkgs; do
    grep -qx "$p" "$ROOT/iso/releng/packages.x86_64" || bad="$bad $p(not-on-iso)"
    echo "$manifest_names" | jq -e --arg n "$p" 'index($n) != null' >/dev/null && bad="$bad $p(in-manifest)"
done
if [ -n "$live_pkgs" ] && [ -z "$bad" ]; then
    ok "live-only packages are ISO-only and not shipped by install.sh"
else
    err "LIVE_ONLY_PKGS mismatch:${bad:- empty list}"
fi
if grep -qF 'strip_live_packages' "$LATE" \
    && sed -n '/^phase_provision()/,/^}/p' "$LATE" | grep -qF 'strip_live_packages'; then
    ok "provision phase removes the live-only packages last"
else
    err "phase_provision must call strip_live_packages"
fi

[ "$FAIL" -eq 0 ]
