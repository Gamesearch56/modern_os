#!/usr/bin/env bash
# Live kiosk: liveuser + cage + Calamares. No mkarchiso.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-iso-live-kiosk: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-iso-live-kiosk: ok %s\n' "$*"; }

LUA="$ROOT/iso/airootfs/etc/modern/live-hyprland.lua"
WRAP="$ROOT/iso/airootfs/usr/lib/modern/live-calamares.sh"
SESSION="$ROOT/iso/airootfs/usr/lib/modern/live-session.sh"
GREETD="$ROOT/iso/airootfs/etc/greetd/config.toml"
SUDOERS="$ROOT/iso/airootfs/etc/sudoers.d/99-liveuser"
PROFILE="$ROOT/iso/releng/profiledef.sh"

if grep -E 'hl\.bind\("SUPER,' "$LUA" >/dev/null; then
    err "live-hyprland.lua still uses comma-style hl.bind (Hyprland wants SUPER + KEY)"
else
    ok "no comma-style SUPER binds"
fi

if grep -F 'hl.bind("SUPER + RETURN"' "$LUA" >/dev/null \
    && grep -F 'hl.bind("SUPER + SPACE"' "$LUA" >/dev/null; then
    ok "Lua SUPER + KEY relaunch binds"
else
    err "missing SUPER + RETURN / SUPER + SPACE binds"
fi

if grep -F 'exec cage -s -- /usr/lib/modern/live-calamares.sh' "$SESSION" >/dev/null \
    && ! grep -F 'start-hyprland' "$SESSION" >/dev/null; then
    ok "session is cage kiosk (Calamares is the only client)"
else
    err "live-session.sh must exec cage -s -- live-calamares.sh"
fi

PKGS="$ROOT/iso/releng/packages.x86_64"
if grep -Fx cage "$PKGS" >/dev/null; then
    ok "live ISO ships cage"
else
    err "packages.x86_64 must list cage"
fi

if grep -Fx kcrash "$PKGS" >/dev/null; then
    ok "live ISO ships kcrash (libKF6Crash.so.6)"
else
    err "packages.x86_64 must list kcrash — Calamares links it, AUR PKGBUILD does not"
fi

QEMU="$ROOT/scripts/iso-qemu.sh"
if grep -F 'vm-serial.log' "$QEMU" >/dev/null \
    && grep -F -- '-serial' "$QEMU" >/dev/null \
    && grep -F 'vm-disk.qcow2' "$QEMU" >/dev/null \
    && ! grep -F 'INSTALL_DISK' "$QEMU" >/dev/null; then
    ok "iso-qemu.sh captures serial and always attaches the 64G disk"
else
    err "iso-qemu.sh must write serial and always attach vm-disk.qcow2"
fi

if grep -E '^user = "liveuser"$' "$GREETD" >/dev/null; then
    ok "greetd autologins liveuser"
else
    err "live greetd config must autologin liveuser"
fi

if grep -F 'Xwayland -noreset' "$WRAP" >/dev/null \
    && grep -F 'xhost +SI:localuser:root' "$WRAP" >/dev/null \
    && grep -F 'sudo -n' "$WRAP" >/dev/null \
    && grep -F 'QT_QPA_PLATFORM=xcb' "$WRAP" >/dev/null \
    && grep -F 'exec Xwayland' "$WRAP" >/dev/null; then
    ok "wrapper runs Calamares as root on Xwayland (cage client)"
else
    err "live-calamares.sh must exec Xwayland and sudo Calamares on xcb"
fi

if grep -Fx xorg-xwayland "$PKGS" >/dev/null \
    && grep -Fx xorg-xhost "$PKGS" >/dev/null; then
    ok "live ISO ships Xwayland and xhost"
else
    err "packages.x86_64 must list xorg-xwayland and xorg-xhost"
fi

if grep -F 'WAYLAND_DISPLAY' "$SUDOERS" >/dev/null \
    && grep -F 'NOPASSWD: ALL' "$SUDOERS" >/dev/null; then
    ok "sudoers keeps Wayland env and NOPASSWD"
else
    err "99-liveuser must NOPASSWD and env_keep WAYLAND_DISPLAY"
fi

if grep -F '/usr/lib/modern/live-calamares.sh' "$PROFILE" >/dev/null; then
    ok "profiledef ships the wrapper mode 755"
else
    err "profiledef.sh missing live-calamares.sh permissions"
fi

if grep -F 'live-calamares.sh' "$ROOT/scripts/iso-build.sh" >/dev/null; then
    ok "iso-build.sh installs the wrapper"
else
    err "iso-build.sh must install live-calamares.sh"
fi

WELCOME="$ROOT/iso/airootfs/etc/calamares/modules/welcome.conf"
XDG="$ROOT/iso/airootfs/usr/lib/modern/live-xdg-open.sh"
PKGS="$ROOT/iso/releng/packages.x86_64"

if grep -E '^showDonateUrl:[[:space:]]+false$' "$WELCOME" >/dev/null \
    && grep -E '^showSupportUrl:[[:space:]]+true$' "$WELCOME" >/dev/null \
    && grep -E '^showKnownIssuesUrl:[[:space:]]+true$' "$WELCOME" >/dev/null; then
    ok "welcome.conf hides Donate and shows Support/Issues"
else
    err "welcome.conf must hide Donate and enable Support/Issues"
fi

if grep -F 'kde.org/community/donations' "$WELCOME" >/dev/null \
    || grep -F 'kde.org/community/donations' "$ROOT/iso/airootfs/etc/calamares/branding/modern/branding.desc" >/dev/null; then
    err "KDE donate URL must not ship in welcome branding"
else
    ok "no KDE donate URL"
fi

if grep -E '^[[:space:]]+- storage$' "$WELCOME" >/dev/null; then
    err "welcome.conf must not check storage (empty disks report 0 GiB)"
else
    ok "welcome.conf skips the empty-disk storage check"
fi

BRAND="$ROOT/iso/airootfs/etc/calamares/branding/modern/branding.desc"
SLIDE="$ROOT/iso/airootfs/etc/calamares/branding/modern/show.qml"
if grep -F 'productWelcome:      "logo.png"' "$BRAND" >/dev/null \
    && grep -F 'welcomeExpandingLogo: false' "$BRAND" >/dev/null \
    && ! grep -F 'default.jpg' "$BRAND" >/dev/null \
    && ! grep -F 'default.jpg' "$SLIDE" >/dev/null; then
    ok "branding does not use the default wallpaper"
else
    err "branding must use logo.png, not default.jpg"
fi

if grep -F 'write_logo' "$ROOT/scripts/iso-build.sh" >/dev/null \
    && grep -F 'branding/modern/wallpaper.jpg' "$ROOT/scripts/iso-build.sh" >/dev/null \
    && grep -F 'url("wallpaper.jpg")' "$ROOT/scripts/iso-build.sh" >/dev/null \
    && grep -F 'wallpaper.jpg' "$SLIDE" >/dev/null \
    && ! grep -F 'branding/modern/default.jpg' "$ROOT/scripts/iso-build.sh" >/dev/null; then
    ok "iso-build.sh writes an M logo and uses wallpaper only as background"
else
    err "iso-build.sh must paint wallpaper.jpg as background, not as the logo"
fi

if grep -Fx firefox "$PKGS" >/dev/null && grep -Fx xdg-utils "$PKGS" >/dev/null; then
    ok "live ISO has firefox and xdg-utils"
else
    err "packages.x86_64 must list firefox and xdg-utils"
fi

if grep -F '/usr/bin/xdg-open' "$XDG" >/dev/null \
    && ! grep -F 'runuser' "$XDG" >/dev/null; then
    ok "xdg-open wrapper stays on the session compositor"
else
    err "live-xdg-open.sh must exec /usr/bin/xdg-open without runuser"
fi

if grep -F '/usr/lib/modern/live-xdg-open.sh' "$PROFILE" >/dev/null \
    && grep -F 'live-xdg-open.sh' "$ROOT/scripts/iso-build.sh" >/dev/null; then
    ok "profiledef and iso-build ship the xdg-open wrapper"
else
    err "profiledef/iso-build missing live-xdg-open.sh"
fi

BUILD="$ROOT/scripts/iso-build.sh"
if grep -F 'QLabel, QCheckBox, QRadioButton, QFrame, QGroupBox' "$BUILD" >/dev/null \
    && grep -F 'background-color: transparent;' "$BUILD" >/dev/null \
    && grep -F 'QStackedWidget QLabel' "$BUILD" >/dev/null \
    && grep -F 'border-radius: 8px;' "$BUILD" >/dev/null \
    && ! grep -F 'QFrame, QListView, QTreeView' "$BUILD" >/dev/null; then
    ok "Calamares QSS keeps labels unfilled and spaces form fields"
else
    err "iso-build.sh QSS must not paint QLabel/QFrame backgrounds"
fi

SETUP="$ROOT/iso/airootfs/usr/lib/modern/live-setup.sh"
LOCALE_GEN="$ROOT/iso/airootfs/etc/locale.gen"
LOCALE_CONF="$ROOT/iso/airootfs/etc/calamares/modules/locale.conf"

if grep -F '/usr/share/i18n/SUPPORTED' "$SETUP" >/dev/null \
    && grep -F 'en_US.UTF-8 UTF-8' "$SETUP" >/dev/null \
    && grep -F 'de_DE.UTF-8 UTF-8' "$SETUP" >/dev/null; then
    ok "live-setup restricts glibc SUPPORTED to en and de"
else
    err "live-setup.sh must rewrite SUPPORTED to en_US and de_DE"
fi

uncommented="$(grep -E '^[a-z]' "$LOCALE_GEN" || true)"
expected="$(printf '%s\n' 'en_US.UTF-8 UTF-8' 'de_DE.UTF-8 UTF-8')"
if [ "$uncommented" = "$expected" ]; then
    ok "locale.gen is English and German only"
else
    err "etc/locale.gen must list only en_US.UTF-8 and de_DE.UTF-8"
fi

if grep -F 'localeGenPath:' "$LOCALE_CONF" >/dev/null \
    && grep -F 'style: "none"' "$LOCALE_CONF" >/dev/null; then
    ok "locale.conf uses locale.gen and skips GeoIP"
else
    err "locale.conf must set localeGenPath and disable geoip"
fi

USERS="$ROOT/iso/airootfs/etc/calamares/modules/users.conf"
if grep -E '^allowWeakPasswords:[[:space:]]+false$' "$USERS" >/dev/null \
    && grep -E '^displayAutologin:[[:space:]]+false$' "$USERS" >/dev/null; then
    ok "users page hides weak-password and autologin chrome"
else
    err "users.conf must hide allowWeakPasswords and displayAutologin"
fi

XKB="$ROOT/iso/airootfs/usr/lib/modern/live-xkb-filter.py"
KB_CONF="$ROOT/iso/airootfs/etc/calamares/modules/keyboard.conf"

if grep -F 'KEEP_LAYOUTS = {"us", "de"}' "$XKB" >/dev/null \
    && grep -F 'variantList' "$XKB" >/dev/null \
    && grep -F 'def filter_lst' "$XKB" >/dev/null; then
    ok "xkb filter keeps us/de defaults only (XML and base.lst)"
else
    err "live-xkb-filter.py must keep us and de in XML and base.lst"
fi

LANGHOOK="$ROOT/iso/releng/calamares-limit-languages.py"
AUR="$ROOT/scripts/lib/iso-aur-repo.sh"
if [ -f "$LANGHOOK" ] \
    && grep -F 'iso_calamares_limit_languages' "$AUR" >/dev/null \
    && grep -F 'QStringLiteral( "en" )' "$LANGHOOK" >/dev/null \
    && grep -F 'QStringLiteral( "de" )' "$LANGHOOK" >/dev/null; then
    ok "AUR Calamares build limits welcome languages to en and de"
else
    err "iso-aur-repo.sh must patch Calamares welcome languages to en/de"
fi

if grep -F 'live-xkb-filter.py' "$SETUP" >/dev/null \
    && grep -F 'live-xkb-filter.py' "$PROFILE" >/dev/null \
    && grep -F 'live-xkb-filter.py' "$ROOT/scripts/iso-build.sh" >/dev/null; then
    ok "live-setup, profiledef, and iso-build ship the xkb filter"
else
    err "live-xkb-filter.py must be installed and run from live-setup"
fi

if grep -F 'convertedKeymapPath: "/usr/share/kbd/keymaps/xkb"' "$KB_CONF" >/dev/null; then
    ok "keyboard.conf uses the Arch keymap path"
else
    err "keyboard.conf must set convertedKeymapPath for Arch"
fi

SETTINGS="$ROOT/iso/airootfs/etc/calamares/settings.conf"
LATE="$ROOT/iso/airootfs/usr/lib/modern/calamares-late.sh"
PKGS_CONF="$ROOT/iso/airootfs/etc/calamares/modules/packages.conf"

if grep -F 'shellprocess@lateclone' "$SETTINGS" >/dev/null \
    && grep -F 'shellprocess@latedesktop' "$SETTINGS" >/dev/null \
    && grep -F 'shellprocess@lateprovision' "$SETTINGS" >/dev/null \
    && [ -f "$ROOT/iso/airootfs/etc/calamares/modules/shellprocess-lateclone.conf" ] \
    && [ -f "$ROOT/iso/airootfs/etc/calamares/modules/shellprocess-latedesktop.conf" ] \
    && [ -f "$ROOT/iso/airootfs/etc/calamares/modules/shellprocess-lateprovision.conf" ] \
    && [ ! -f "$ROOT/iso/airootfs/etc/calamares/modules/shellprocess.conf" ]; then
    ok "late install is three named shellprocess jobs"
else
    err "settings.conf must run shellprocess@lateclone/desktop/provision"
fi

if grep -F 'usage: calamares-late.sh clone|desktop|provision' "$LATE" >/dev/null \
    && grep -F 'timeout 180' "$LATE" >/dev/null \
    && grep -F 'GIT_HTTP_LOW_SPEED_LIMIT' "$LATE" >/dev/null; then
    ok "calamares-late.sh is phased with a git timeout"
else
    err "calamares-late.sh must take clone|desktop|provision and timeout git"
fi

if grep -E '^update_db:[[:space:]]+false$' "$PKGS_CONF" >/dev/null \
    && grep -Fx linux-zen "$PKGS" >/dev/null \
    && grep -Fx linux-zen-headers "$PKGS" >/dev/null; then
    ok "live ISO ships linux-zen; packages.conf does not pacman -Sy"
else
    err "packages.x86_64 must list linux-zen and packages.conf update_db: false"
fi

if grep -F 'import calamares.slideshow' "$SLIDE" >/dev/null \
    && grep -F 'function onActivate' "$SLIDE" >/dev/null \
    && grep -F 'wallpaper.jpg' "$SLIDE" >/dev/null; then
    ok "install slideshow is API 2 with wallpaper slides"
else
    err "show.qml must be a Presentation slideshow with wallpaper.jpg"
fi

if grep -F 'QProgressBar' "$BUILD" >/dev/null \
    && grep -F 'QTextBrowser' "$BUILD" >/dev/null \
    && grep -F 'QPushButton:default' "$BUILD" >/dev/null; then
    ok "Calamares QSS styles the exec bar and summary"
else
    err "iso-build.sh QSS must style QProgressBar and QTextBrowser"
fi

XKB_TMP="$(mktemp -d)"
cleanup_xkb() { rm -rf "$XKB_TMP"; }
trap cleanup_xkb EXIT
fixture="$XKB_TMP/base.xml"
cat >"$fixture" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<xkbConfigRegistry version="1.1">
  <layoutList>
    <layout>
      <configItem><name>fr</name></configItem>
      <variantList><variant><configItem><name>oss</name></configItem></variant></variantList>
    </layout>
    <layout>
      <configItem><name>us</name></configItem>
      <variantList><variant><configItem><name>dvorak</name></configItem></variant></variantList>
    </layout>
    <layout>
      <configItem><name>de</name></configItem>
      <variantList><variant><configItem><name>nodeadkeys</name></configItem></variant></variantList>
    </layout>
  </layoutList>
</xkbConfigRegistry>
XML
python3 - "$XKB" "$fixture" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("xkb", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
mod.filter_file(sys.argv[2])
PY
got="$(python3 - "$fixture" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
names = [n.text for n in root.findall(".//layout/configItem/name")]
variants = root.findall(".//variant")
print(" ".join(names), len(variants))
PY
)"
if [ "$got" = "us de 0" ]; then
    ok "xkb filter drops other layouts and all variants"
else
    err "xkb filter produced '$got' (want 'us de 0')"
fi

lst="$XKB_TMP/base.lst"
cat >"$lst" <<'LST'
! model
  pc105           Generic 105-key PC
! layout
  fr              French
  us              English (US)
  de              German
! variant
  dvorak          us: English (Dvorak)
  nodeadkeys      de: German (no dead keys)
! option
  grp:alt_shift_toggle Alt+Shift
LST
python3 - "$XKB" "$lst" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("xkb", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
mod.filter_lst(sys.argv[2])
PY
lst_got="$(python3 - "$lst" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
print("us" in text and "de" in text and "fr" not in text and "dvorak" not in text)
PY
)"
if [ "$lst_got" = "True" ]; then
    ok "base.lst filter keeps us/de layouts and drops variants"
else
    err "base.lst filter failed"
fi

[ "$FAIL" -eq 0 ]
