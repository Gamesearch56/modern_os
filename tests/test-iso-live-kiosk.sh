#!/usr/bin/env bash
# Live kiosk: liveuser + cage + Calamares. No mkarchiso.
# Grep needles include literal $vars from the scripts under test.
# shellcheck disable=SC2016
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

XKB_SH="$ROOT/iso/airootfs/usr/lib/modern/live-xkb.sh"
XKB_C="$ROOT/iso/releng/live-xkb-cage.c"
if grep -F '/usr/lib/modern/live-xkb-cage.so' "$SESSION" >/dev/null \
    && grep -F 'unset LD_PRELOAD' "$WRAP" >/dev/null \
    && grep -F 'xkb_state_key_get_syms' "$XKB_C" >/dev/null \
    && grep -F '/run/modern/xkb-layout' "$XKB_SH" >/dev/null \
    && grep -F 'MODERN_XKB_PUSH_X=1' "$SESSION" >/dev/null \
    && grep -F 'wlr_keyboard_set_keymap' "$XKB_C" >/dev/null \
    && grep -F 'wlr_seat_set_keyboard' "$XKB_C" >/dev/null \
    && grep -F 'wlr_scene_output_commit' "$XKB_C" >/dev/null \
    && grep -F 'wl_display_run' "$XKB_C" >/dev/null; then
    ok "installer keyboard is applied by cage, not only setxkbmap"
else
    err "cage must reload /run/modern/xkb-layout when the layout changes"
fi
if python3 -c '
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
unset = text.find("unset LD_PRELOAD")
start = text.find("\n(\n")
end = text.find("\n) &\n", start)
xwayland = text.find("exec Xwayland")
sys.exit(0 if 0 <= start < unset < end < xwayland else 1)
' "$WRAP"; then
    ok "Xwayland keeps the keyboard helper and Calamares drops it"
else
    err "Xwayland must keep LD_PRELOAD; only the X clients may drop it"
fi
if command -v gcc >/dev/null 2>&1 && pkg-config --exists xkbcommon && pkg-config --exists wayland-server; then
    so=$(mktemp)
    # shellcheck disable=SC2046
    if gcc -shared -fPIC -O2 -Wall -Wextra -Wl,-z,defs -pthread -o "$so" "$XKB_C" $(pkg-config --cflags --libs xkbcommon wayland-server); then
        if nm -D "$so" | grep -q 'wlr_keyboard_set_keymap' \
            && nm -D "$so" | grep -q 'wlr_seat_set_keyboard' \
            && nm -D "$so" | grep -q 'wlr_scene_output_commit' \
            && nm -D "$so" | grep -q 'wlr_seat_keyboard_notify_key' \
            && nm -D "$so" | grep -q 'wl_display_run' \
            && nm -D "$so" | grep -q 'xkb_state_key_get_syms'; then
            ok "keyboard helper exports the cage hooks"
        else
            err "keyboard helper is missing cage hooks"
        fi
        layout=$(mktemp)
        fake=$(mktemp)
        call=$(mktemp)
        seat=$(mktemp)
        stub=$(mktemp /tmp/modern-xkb-seat-XXXXXX.c)
        printf 'de\n\n' >"$layout"
        printf '%s\n' '#include <dlfcn.h>' \
            'int main(int argc, char **argv) {' \
            '  void *h = dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL);' \
            '  int (*fn)(void) = h ? dlsym(h, "modern_seat_test") : 0;' \
            '  if (!fn) return 9;' \
            '  return fn();' \
            '}' >"$stub"
        # shellcheck disable=SC2046
        if gcc -shared -fPIC -O2 -o "$fake" "$ROOT/tests/live-xkb-seat.c" \
            $(pkg-config --cflags --libs xkbcommon) \
            && gcc -shared -fPIC -O2 -o "$call" "$ROOT/tests/live-xkb-seat-call.c" \
            $(pkg-config --cflags --libs xkbcommon) \
            && gcc -O2 -o "$seat" "$stub" -ldl \
            && MODERN_XKB_LAYOUT="$layout" LD_PRELOAD="$so:$fake" "$seat" "$call"; then
            ok "the first key publishes the layout that was chosen first"
        else
            err "the first key still publishes the previous layout (seat exit $?)"
        fi
        rm -f "$layout" "$fake" "$call" "$seat" "$stub"
        trans=$(mktemp)
        # shellcheck disable=SC2046
        if gcc -O2 -o "$trans" "$ROOT/tests/live-xkb-translate.c" \
            $(pkg-config --cflags --libs xkbcommon) \
            && printf 'de\n\n' >"$layout" \
            && MODERN_XKB_LAYOUT="$layout" LD_PRELOAD="$so" "$trans"; then
            ok "Xwayland keysyms follow the layout file on the first key"
        else
            err "Xwayland still translates the first key with the previous layout (exit $?)"
        fi
        rm -f "$trans" "$layout"
    else
        err "keyboard helper failed to compile"
    fi
    rm -f "$so"
elif command -v gcc >/dev/null 2>&1 && pkg-config --exists xkbcommon; then
    err "keyboard helper needs wayland-server to wake cage when the layout file changes"
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
    && grep -F 'OVMF_CODE' "$QEMU" >/dev/null \
    && grep -F 'ovmf-vars.fd' "$QEMU" >/dev/null \
    && grep -F -- '--headless' "$QEMU" >/dev/null \
    && grep -F 'display none' "$QEMU" >/dev/null \
    && grep -F 'bootindex=1' "$QEMU" >/dev/null \
    && grep -F 'scsi-cd' "$QEMU" >/dev/null \
    && grep -F -- '--reset-disk' "$QEMU" >/dev/null \
    && grep -F -- '--keep-nvram' "$QEMU" >/dev/null \
    && grep -F -- '--unattended' "$QEMU" >/dev/null \
    && grep -F 'opt/org.modernos/unattended' "$QEMU" >/dev/null \
    && grep -F -- '--no-iso) NO_ISO=1; KEEP_NVRAM=1' "$QEMU" >/dev/null \
    && grep -F 'iso_newest_release' "$QEMU" >/dev/null \
    && grep -F -- '--wifi-sim) WIFI_SIM=1' "$QEMU" >/dev/null \
    && grep -F 'opt/org.modernos/wifi-sim' "$QEMU" >/dev/null \
    && ! grep -F 'INSTALL_DISK' "$QEMU" >/dev/null; then
    ok "iso-qemu.sh captures serial, attaches vm-disk.qcow2, boots OVMF, ISO bootindex first"
else
    err "iso-qemu.sh must write serial, attach vm-disk.qcow2, boot OVMF, and prefer the ISO"
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
    && grep -F 'exec Xwayland' "$WRAP" >/dev/null \
    && grep -F 'modern-ci: calamares' "$WRAP" >/dev/null \
    && grep -F 'modern-ci: unattended' "$WRAP" >/dev/null \
    && grep -F '/etc/calamares/unattended' "$WRAP" >/dev/null \
    && grep -F 'calamares exited' "$WRAP" >/dev/null \
    && grep -F 'restarting installer' "$WRAP" >/dev/null \
    && grep -F '/run/modern-install-finished' "$WRAP" >/dev/null \
    && grep -F '/dev/ttyS0' "$WRAP" >/dev/null \
    && grep -F 'openbox --config-file /etc/modern/openbox-rc.xml' "$WRAP" >/dev/null \
    && [ -f "$ROOT/iso/airootfs/etc/modern/openbox-rc.xml" ]; then
    ok "wrapper runs Calamares as root on Xwayland (cage client)"
else
    err "live-calamares.sh must exec Xwayland, sudo Calamares on xcb, serial-mark CI, and start openbox"
fi

I18N="$ROOT/iso/airootfs/usr/lib/modern/live-i18n.sh"
I18N_UNIT="$ROOT/iso/airootfs/usr/lib/systemd/system/modern-live-i18n.service"
I18N_WANTS="$ROOT/iso/airootfs/etc/systemd/system/greetd.service.wants/modern-live-i18n.service"
if [ -f "$ROOT/iso/airootfs/usr/lib/modern/live-splash.qml" ] \
    || grep -F 'live-splash.qml' "$WRAP" >/dev/null \
    || grep -F 'xsetroot' "$WRAP" >/dev/null; then
    err "live-calamares.sh must not show a splash before Calamares"
else
    ok "live session has no splash spinner"
fi

if [ -f "$I18N" ] \
    && [ -f "$I18N_UNIT" ] \
    && [ -L "$I18N_WANTS" ] \
    && grep -F 'locale-gen' "$I18N" >/dev/null \
    && grep -F 'live-xkb-filter.py' "$I18N" >/dev/null \
    && grep -F 'After=modern-live-setup.service' "$I18N_UNIT" >/dev/null \
    && ! grep -E '^Before=greetd' "$I18N_UNIT" >/dev/null \
    && ! grep -E '^[[:space:]]*locale-gen' "$ROOT/iso/airootfs/usr/lib/modern/live-setup.sh" >/dev/null; then
    ok "locale-gen runs beside greetd, not before it"
else
    err "modern-live-i18n.service must run locale-gen without blocking greetd"
fi

if grep -F 'systemd-detect-virt' "$SESSION" >/dev/null \
    && grep -F 'WLR_RENDERER=pixman' "$SESSION" >/dev/null; then
    ok "pixman is only the VM fallback"
else
    err "live-session.sh must use pixman only when systemd-detect-virt"
fi

if grep -Fx xorg-xwayland "$PKGS" >/dev/null \
    && grep -Fx xorg-xhost "$PKGS" >/dev/null \
    && grep -Fx xorg-setxkbmap "$PKGS" >/dev/null \
    && grep -Fx openbox "$PKGS" >/dev/null; then
    ok "live ISO ships Xwayland, xhost, setxkbmap, and openbox"
else
    err "packages.x86_64 must list xorg-xwayland, xorg-xhost, xorg-setxkbmap, and openbox"
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

BRAND="$ROOT/iso/airootfs/etc/calamares/branding/modern/branding.desc"
if grep -E '^showDonateUrl:[[:space:]]+true$' "$WELCOME" >/dev/null \
    && grep -E '^showSupportUrl:[[:space:]]+true$' "$WELCOME" >/dev/null \
    && grep -E '^showKnownIssuesUrl:[[:space:]]+true$' "$WELCOME" >/dev/null \
    && grep -F 'donateUrl:           https://ko-fi.com/gamesearch56' "$BRAND" >/dev/null; then
    ok "welcome.conf shows Donate, Support, and Issues, and Donate opens Ko-fi"
else
    err "welcome.conf must show Donate, Support, and Issues, with Donate pointing at Ko-fi"
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

LOGO="$ROOT/iso/airootfs/etc/calamares/branding/modern/logo.png"
SIDEBAR_QML="$ROOT/iso/airootfs/etc/calamares/branding/modern/calamares-sidebar.qml"
if [ -f "$LOGO" ] \
    && [ "$(head -c 4 "$LOGO")" = $'\x89PNG' ] \
    && grep -F 'branding/modern/logo.png' "$ROOT/scripts/iso-build.sh" >/dev/null \
    && ! grep -F 'write_logo' "$ROOT/scripts/iso-build.sh" >/dev/null \
    && grep -F 'branding/modern/wallpaper.jpg' "$ROOT/scripts/iso-build.sh" >/dev/null \
    && grep -F 'wallpaper.jpg' "$SLIDE" >/dev/null \
    && ! grep -F 'branding/modern/default.jpg' "$ROOT/scripts/iso-build.sh" >/dev/null; then
    ok "iso-build.sh ships logo.png and uses wallpaper only as background"
else
    err "iso-build.sh must copy logo.png and paint wallpaper.jpg as background"
fi

if grep -E '^sidebar:[[:space:]]+qml$' "$BRAND" >/dev/null \
    && grep -E '^navigation:[[:space:]]+widget$' "$BRAND" >/dev/null \
    && [ -f "$SIDEBAR_QML" ] \
    && grep -F 'model: ViewManager' "$SIDEBAR_QML" >/dev/null \
    && grep -F 'pillRadius' "$SIDEBAR_QML" >/dev/null \
    && grep -F 'debug.about' "$SIDEBAR_QML" >/dev/null \
    && grep -F 'anchors.margins: sideBar.pad' "$SIDEBAR_QML" >/dev/null \
    && ! grep -F 'hover.containsMouse' "$SIDEBAR_QML" >/dev/null; then
    ok "Calamares sidebar is QML pills with padded About"
else
    err "branding must use sidebar: qml with calamares-sidebar.qml pills"
fi

if grep -Fx firefox "$PKGS" >/dev/null && grep -Fx xdg-utils "$PKGS" >/dev/null; then
    ok "live ISO has firefox and xdg-utils"
else
    err "packages.x86_64 must list firefox and xdg-utils"
fi

if grep -F '/usr/bin/xdg-open' "$XDG" >/dev/null \
    && grep -F 'runuser -u liveuser' "$XDG" >/dev/null \
    && grep -F -- '-u WAYLAND_DISPLAY' "$XDG" >/dev/null; then
    ok "xdg-open wrapper drops root to liveuser on X11"
else
    err "live-xdg-open.sh must runuser liveuser without WAYLAND_DISPLAY"
fi

if grep -F '/usr/lib/modern/live-xdg-open.sh' "$PROFILE" >/dev/null \
    && grep -F 'live-xdg-open.sh' "$ROOT/scripts/iso-build.sh" >/dev/null; then
    ok "profiledef and iso-build ship the xdg-open wrapper"
else
    err "profiledef/iso-build missing live-xdg-open.sh"
fi

BUILD="$ROOT/scripts/iso-build.sh"
QSS="$ROOT/scripts/lib/iso-calamares-qss.py"
AUR_REPO="$ROOT/scripts/lib/iso-aur-repo.sh"
NET="$ROOT/iso/releng/calamares-modernnet"

# Every enabled installer button gets an MD3 hover and press layer, and
# the hand cursor (a stylesheet cannot set one, so the module does).
qss_out="$(mktemp)"
if printf '{"color":{}}' >"$qss_out.json" \
    && python3 "$QSS" "$qss_out.json" "$qss_out" \
    && grep -Fq 'QPushButton:enabled:hover {' "$qss_out" \
    && grep -Fq 'QPushButton:enabled:pressed {' "$qss_out" \
    && grep -Fq '#view-button-next:enabled:hover' "$qss_out" \
    && grep -Fq 'QToolButton:enabled:hover {' "$qss_out" \
    && grep -Fq '#finishedRestart:enabled:hover {' "$qss_out" \
    && ! grep -Eq 'QPushButton:hover|QToolButton:hover' "$qss_out" \
    && grep -Fq 'ModernPointer.cpp' "$NET/CMakeLists.txt" \
    && grep -Fq 'ModernPointer::install();' "$NET/ModernNetViewStep.cpp" \
    && grep -Fq 'Qt::PointingHandCursor' "$NET/ModernPointer.cpp"; then
    ok "installer buttons have hover and press layers and the hand cursor"
else
    err "iso-calamares-qss.py needs :enabled:hover/:pressed layers and modernnet must install ModernPointer"
fi
rm -f "$qss_out" "$qss_out.json"
if grep -F 'iso-calamares-qss.py' "$BUILD" >/dev/null \
    && grep -F 'QLabel, QCheckBox, QRadioButton, QFrame, QGroupBox' "$QSS" >/dev/null \
    && grep -F 'background-color: transparent;' "$QSS" >/dev/null \
    && grep -F 'QStackedWidget QLabel' "$QSS" >/dev/null \
    && grep -F 'border-radius: 8px;' "$QSS" >/dev/null \
    && grep -F '#summaryItemBody' "$QSS" >/dev/null \
    && grep -F '#partitionLabel' "$QSS" >/dev/null \
    && grep -F '#networkPage' "$QSS" >/dev/null \
    && grep -F '#networkOkPage' "$QSS" >/dev/null \
    && grep -F '#wifiList' "$QSS" >/dev/null \
    && grep -F '#networkRowConnect' "$QSS" >/dev/null \
    && grep -F '#finishedBadge' "$QSS" >/dev/null \
    && grep -F '#finishedRestart' "$QSS" >/dev/null \
    && grep -F '#finishedMainText' "$QSS" >/dev/null \
    && grep -F 'QAbstractScrollArea::viewport' "$QSS" >/dev/null \
    && grep -F 'states("QToolButton"' "$QSS" >/dev/null \
    && ! grep -F 'QFrame, QListView, QTreeView' "$QSS" >/dev/null; then
    ok "Calamares QSS keeps labels unfilled, paints viewports, spaces form fields"
else
    err "iso-build.sh QSS must not paint QLabel/QFrame backgrounds and must paint viewports"
fi

if grep -F 'combobox-popup: 0;' "$QSS" >/dev/null \
    && grep -F 'QComboBoxPrivateContainer' "$QSS" >/dev/null \
    && grep -F 'QComboBox QAbstractItemView::item' "$QSS" >/dev/null \
    && grep -A1 'QWidget {{' "$QSS" | grep -F 'color:' >/dev/null \
    && ! grep -A1 'QWidget {{' "$QSS" | grep -F 'background-color: transparent' >/dev/null \
    && grep -F 'QDialog, QWizard, QMessageBox' "$QSS" >/dev/null \
    && ! grep -F 'QLineEdit, QComboBox, QSpinBox' "$QSS" >/dev/null \
    && ! grep -F 'border-image: url("wallpaper.jpg")' "$QSS" >/dev/null \
    && ! grep -A14 'QComboBox {{' "$QSS" | grep -F 'border-radius' >/dev/null; then
    ok "Calamares QSS keeps combo popups and dialogs opaque without combo radius"
else
    err "iso-build.sh QSS must style combo popups without wallpaper on #mainApp or combo radius"
fi

# The overlay sizes itself from row height plus frame, so QSS padding on the
# view itself would push the last row out of the window.
if grep -F '#modernComboOverlay {{' "$QSS" >/dev/null \
    && grep -F '#modernComboOverlay::viewport {{' "$QSS" >/dev/null \
    && grep -F '#modernComboOverlay::item {{' "$QSS" >/dev/null \
    && grep -F '#modernComboOverlay::item:selected' "$QSS" >/dev/null \
    && grep -A8 '#modernComboOverlay {{' "$QSS" | grep -F 'padding: 0;' >/dev/null \
    && ! grep -A8 '#modernComboOverlay {{' "$QSS" | grep -E '#[0-9A-Fa-f]{6}' >/dev/null; then
    ok "Calamares QSS styles the in-window combo overlay from tokens without view padding"
else
    err "iso-build.sh QSS must style #modernComboOverlay from tokens with padding: 0"
fi

SETUP="$ROOT/iso/airootfs/usr/lib/modern/live-setup.sh"
LOCALE_GEN="$ROOT/iso/airootfs/etc/locale.gen"
LOCALE_CONF="$ROOT/iso/airootfs/etc/calamares/modules/locale.conf"

XKB_TMP="$(mktemp -d)"
cleanup_xkb() { rm -rf "$XKB_TMP"; }
trap cleanup_xkb EXIT
# Generated at ISO build time from the bundle's languages.json; a committed
# copy would drift from the languages the installed desktop really has.
MANIFEST="$XKB_TMP/installer-locales.json"
export MODERN_INSTALLER_LOCALES="$MANIFEST"
if [ ! -e "$ROOT/iso/releng/installer-locales.json" ] && [ ! -e "$LOCALE_GEN" ] \
    && python3 "$ROOT/scripts/installer-locales.py" --json "$MANIFEST" \
        --locale-gen "$XKB_TMP/locale.gen" >/dev/null \
    && grep -F 'installer-locales.json' "$SETUP" >/dev/null \
    && grep -F 'installer-locales.json' "$I18N" >/dev/null \
    && grep -F 'installer-locales.py" --strict' "$BUILD" >/dev/null \
    && grep -F -- '--root "$bundle" --fallback-root "$ROOT"' "$BUILD" >/dev/null \
    && grep -F -- '--locale-gen "$AIROOTFS_OUT/etc/locale.gen"' "$BUILD" >/dev/null \
    && python3 - "$MANIFEST" <<'PY'; then
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
rows = {x["calamares"]: x for x in data["locales"]}
assert rows["en"]["glibc"] == "en_US.UTF-8" and rows["en"]["xkb"] == "us", rows["en"]
assert rows["de"]["glibc"] == "de_DE.UTF-8" and rows["de"]["xkb"] == "de", rows["de"]
at = [c for c in rows["de"]["countries"] if c["country"] == "AT"]
assert at == [{"country": "AT", "glibc": "de_AT.UTF-8", "xkb": "at"}], at
layouts = [str(x) for x in data.get("layouts") or []]
assert layouts and layouts[0] == "us" and "fr" in layouts, layouts
PY
    ok "iso-build generates installer-locales.json and locale.gen from the bundle's catalog"
else
    err "installer-locales.json / locale.gen must be generated by iso-build, not committed"
fi

# live-setup: SUPPORTED offers every language + country to the Location
# step, the live locale.gen only the defaults (boot time).
setup_py="$XKB_TMP/live-setup.py"
sed -n "/^python3 - <<'PY'$/,/^PY$/p" "$SETUP" | sed '1d;$d' \
    | sed -e "s#/usr/lib/modern/installer-locales.json#$MANIFEST#" \
        -e "s#/usr/share/i18n/SUPPORTED#$XKB_TMP/SUPPORTED#" \
        -e "s#/etc/locale.gen#$XKB_TMP/live-locale.gen#" >"$setup_py"
if python3 "$setup_py" \
    && grep -qx 'de_AT.UTF-8 UTF-8' "$XKB_TMP/SUPPORTED" \
    && grep -qx 'en_GB.UTF-8 UTF-8' "$XKB_TMP/SUPPORTED" \
    && [ "$(cat "$XKB_TMP/live-locale.gen")" = "$(printf '%s\n' 'en_US.UTF-8 UTF-8' 'de_DE.UTF-8 UTF-8')" ]; then
    ok "live SUPPORTED lists every language + country; live locale.gen only the defaults"
else
    err "live-setup must write all combinations to SUPPORTED and only defaults to locale.gen"
fi

uncommented="$(grep -E '^[a-z]' "$XKB_TMP/locale.gen" || true)"
if [ "$uncommented" = "$(printf '%s\n' 'en_US.UTF-8 UTF-8' 'de_DE.UTF-8 UTF-8')" ] \
    && grep -qx '#de_AT.UTF-8 UTF-8' "$XKB_TMP/locale.gen" \
    && grep -qx '#en_GB.UTF-8 UTF-8' "$XKB_TMP/locale.gen"; then
    ok "installed locale.gen enables the defaults and carries every combination commented for localecfg"
else
    err "generated locale.gen must enable only defaults and list the rest commented"
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

if grep -F 'load_keep_layouts' "$XKB" >/dev/null \
    && grep -F 'installer-locales.json' "$XKB" >/dev/null \
    && grep -F 'variantList' "$XKB" >/dev/null \
    && grep -F 'def filter_lst' "$XKB" >/dev/null; then
    ok "xkb filter reads installer-locales.json (XML and base.lst)"
else
    err "live-xkb-filter.py must read installer-locales.json and filter XML and base.lst"
fi

LANGHOOK="$ROOT/iso/releng/calamares-limit-languages.py"
AUR="$ROOT/scripts/lib/iso-aur-repo.sh"
if [ -f "$LANGHOOK" ] \
    && grep -F 'iso_calamares_limit_languages' "$AUR" >/dev/null \
    && grep -F 'installer-locales.json' "$LANGHOOK" >/dev/null \
    && grep -F 'installer-locales.json' "$AUR" >/dev/null \
    && grep -F 'qBound( 180, 180, 180 )' "$LANGHOOK" >/dev/null \
    && grep -F 'qApp->setStyleSheet( ss )' "$LANGHOOK" >/dev/null \
    && grep -F 'zoneAndRegionLayout = new QVBoxLayout' "$LANGHOOK" >/dev/null \
    && grep -F 'm_localeChangeButton->hide()' "$LANGHOOK" >/dev/null \
    && grep -F 'QComboBoxPrivateContainer' "$LANGHOOK" >/dev/null \
    && grep -F 'modernComboOverlay' "$LANGHOOK" >/dev/null \
    && grep -F 'dataChanged' "$LANGHOOK" >/dev/null \
    && grep -F 'CALAMARES_RETRANSLATE_FOR( w' "$LANGHOOK" >/dev/null \
    && grep -F 'engine()->retranslate()' "$LANGHOOK" >/dev/null \
    && grep -F 'quitVisible' "$LANGHOOK" >/dev/null \
    && grep -F 'tr( "Toggle log" )' "$LANGHOOK" >/dev/null \
    && grep -F 'physicalModelSelector->hide()' "$LANGHOOK" >/dev/null \
    && grep -F 'summaryContent' "$LANGHOOK" >/dev/null \
    && grep -F 'summaryPartition' "$LANGHOOK" >/dev/null \
    && grep -F 'CalamaresWindow.cpp' "$LANGHOOK" >/dev/null \
    && grep -F 'LocalePage.cpp' "$LANGHOOK" >/dev/null \
    && grep -F 'ViewManager.cpp' "$LANGHOOK" >/dev/null \
    && grep -F 'KeyboardPage.cpp' "$LANGHOOK" >/dev/null \
    && grep -F 'SummaryPage.cpp' "$LANGHOOK" >/dev/null \
    && grep -F 'Config.h' "$LANGHOOK" >/dev/null \
    && grep -F 'PartitionViewStep.cpp' "$LANGHOOK" >/dev/null \
    && grep -F 'PartitionLabelsView.cpp' "$LANGHOOK" >/dev/null \
    && grep -F 'QPalette::WindowText' "$LANGHOOK" >/dev/null \
    && grep -F 'UsersViewStep.cpp' "$LANGHOOK" >/dev/null \
    && grep -F 'KB_APPLY_NEW' "$LANGHOOK" >/dev/null \
    && grep -F 'KB_XKB_NEW' "$LANGHOOK" >/dev/null \
    && grep -F 'somethingChanged();' "$LANGHOOK" >/dev/null \
    && grep -F 'Config.cpp' "$LANGHOOK" >/dev/null \
    && grep -F '/etc/calamares/unattended' "$LANGHOOK" >/dev/null \
    && grep -F 'calamares_{code}.ts' "$LANGHOOK" >/dev/null \
    && grep -F 'apply_ts_strings' "$LANGHOOK" >/dev/null \
    && grep -F 'check_compiled_translations' "$LANGHOOK" >/dev/null \
    && grep -F 'ISO_INSTALLER_LOCALES' "$AUR" >/dev/null \
    && grep -F 'tr( "User" )' "$LANGHOOK" >/dev/null \
    && grep -F 'tr( "Summary", "@label" )' "$LANGHOOK" >/dev/null \
    && grep -F 'install_modernnet' "$LANGHOOK" >/dev/null \
    && grep -F 'calamares-modernnet' "$LANGHOOK" >/dev/null \
    && grep -F 'calamares-modernnet' "$AUR" >/dev/null \
    && grep -F 'iso/releng/calamares-modernnet' "$AUR" >/dev/null \
    && [ -f "$ROOT/iso/releng/calamares-modernnet/CMakeLists.txt" ] \
    && [ -f "$ROOT/iso/releng/calamares-modernnet/ModernNetRow.cpp" ] \
    && ! grep -F 'Übersicht' "$LANGHOOK" >/dev/null \
    && ! grep -F 'calamares_en.ts' "$LANGHOOK" >/dev/null; then
    ok "AUR Calamares build patches languages, sidebar, combos, i18n, cancel, keyboard"
else
    err "iso-aur-repo.sh must patch Calamares languages, sidebar, combos, i18n, cancel, keyboard"
fi

# The overlay is a child widget, so screen coordinates would land it at the
# window origin — which is the bug cage's Qt::Popup handling already caused.
if grep -F 'new QListView( host )' "$LANGHOOK" >/dev/null \
    && grep -F 'mapTo( host, QPoint( 0, 0 ) )' "$LANGHOOK" >/dev/null \
    && grep -F 'origin.y() - height' "$LANGHOOK" >/dev/null \
    && grep -F 'm_combo->width()' "$LANGHOOK" >/dev/null \
    && grep -F 'ComboOverlay( qApp )' "$LANGHOOK" >/dev/null \
    && ! grep -F 'mapToGlobal' "$LANGHOOK" >/dev/null \
    && ! grep -F 'w->move( pos )' "$LANGHOOK" >/dev/null; then
    ok "Combo lists are placed against their field inside the installer window"
else
    err "calamares-limit-languages.py must place combo lists in window coordinates"
fi

if grep -F 'live-xkb-filter.py' "$I18N" >/dev/null \
    && grep -F 'live-xkb-filter.py' "$PROFILE" >/dev/null \
    && grep -F 'live-xkb-filter.py' "$ROOT/scripts/iso-build.sh" >/dev/null; then
    ok "live-i18n, profiledef, and iso-build ship the xkb filter"
else
    err "live-xkb-filter.py must be installed and run from live-i18n"
fi

if grep -F 'convertedKeymapPath: "/usr/share/kbd/keymaps/xkb"' "$KB_CONF" >/dev/null \
    && grep -E '^useLocale1:[[:space:]]+false$' "$KB_CONF" >/dev/null \
    && grep -E '^guessLayout:[[:space:]]+false$' "$KB_CONF" >/dev/null \
    && grep -F 'modernWelcomeLayout' "$LANGHOOK" >/dev/null \
    && grep -F 'modernWelcomeLanguage' "$LANGHOOK" >/dev/null \
    && grep -F 'detectCurrentKeyboardLayout' "$LANGHOOK" >/dev/null \
    && grep -F 'welcome_cpp_fn("modernWelcomeLanguage", "glibc", data)' "$LANGHOOK" >/dev/null \
    && grep -F 'welcome_cpp_fn("modernWelcomeLayout", "xkb", data)' "$LANGHOOK" >/dev/null; then
    ok "keyboard.conf uses the Arch keymap path; Welcome language picks locale and layout"
else
    err "keyboard.conf must disable locale guessing, and the Calamares patch must map Welcome language to glibc and xkb"
fi

# The Welcome language picks the layout (en → us, de → de), not list
# order (Arabic would sort first). The two catalogs and both translation
# files must agree.
if python3 - "$MANIFEST" \
    "$ROOT/stow/modern/.config/modern/keyboard-layouts.json" \
    "$ROOT/stow/modern/.config/modern/translations/en.json" \
    "$ROOT/stow/modern/.config/modern/translations/de.json" <<'PY'
import json, sys
iso = json.loads(open(sys.argv[1], encoding="utf-8").read())
desk = json.loads(open(sys.argv[2], encoding="utf-8").read())
en = json.loads(open(sys.argv[3], encoding="utf-8").read())
de = json.loads(open(sys.argv[4], encoding="utf-8").read())
iso_ids = [str(x) for x in iso.get("layouts") or []]
desk_ids = [str(x) for x in desk.get("layouts") or []]
assert iso_ids == desk_ids, (iso_ids, desk_ids)
assert iso_ids[0] == "us", iso_ids
en_kb = (en.get("settings") or {}).get("kbLayouts") or {}
de_kb = (de.get("settings") or {}).get("kbLayouts") or {}
missing_en = [x for x in iso_ids if x not in en_kb]
missing_de = [x for x in iso_ids if x not in de_kb]
assert not missing_en, missing_en
assert not missing_de, missing_de
PY
then
    ok "installer and Settings share one keyboard-layout catalog starting at us"
else
    err "installer-locales.json layouts must match keyboard-layouts.json, start with us, and have en/de labels"
fi

NM_WIFI="$ROOT/iso/airootfs/etc/NetworkManager/conf.d/wifi-backend.conf"
if grep -F 'NetworkManager.service' "$SETUP" >/dev/null \
    && grep -F 'mask --now iwd.service' "$SETUP" >/dev/null \
    && grep -F 'networkctl down' "$SETUP" >/dev/null \
    && grep -F '  - modernnet' "$ROOT/iso/airootfs/etc/calamares/settings.conf" >/dev/null \
    && [ -f "$ROOT/iso/airootfs/etc/calamares/modules/modernnet.conf" ] \
    && grep -F 'wifi.backend=wpa_supplicant' "$NM_WIFI" >/dev/null \
    && grep -F 'rfkill unblock wifi' "$SETUP" >/dev/null \
    && grep -F 'live-wifi-up.sh --scan' "$SETUP" >/dev/null \
    && grep -F 'ip link set "$name" up' "$ROOT/iso/airootfs/usr/lib/modern/live-wifi-up.sh" >/dev/null \
    && grep -F 'live-wifi-wl.sh' "$SETUP" >/dev/null \
    && grep -F 'copytoram/airootfs.sfs' "$SETUP" >/dev/null \
    && grep -F 'unpackfs.conf' "$SETUP" >/dev/null \
    && grep -F 'unmanaged-devices=type:ethernet' "$NM_WIFI" >/dev/null \
    && grep -qxF 'iwd' "$ROOT/iso/releng/packages.x86_64"; then
    ok "live Network step uses NetworkManager and sits after keyboard"
else
    err "live-setup must enable NetworkManager; settings.conf must list modernnet after keyboard"
fi

WIFI_SIM="$ROOT/iso/airootfs/usr/lib/modern/live-wifi-sim.sh"
if [ -x "$WIFI_SIM" ] \
    && grep -F 'mac80211_hwsim' "$WIFI_SIM" >/dev/null \
    && grep -F '802-11-wireless.mode ap' "$WIFI_SIM" >/dev/null \
    && grep -F 'ipv4.method shared' "$WIFI_SIM" >/dev/null \
    && grep -F 'opt/org.modernos/wifi-sim' "$SETUP" >/dev/null \
    && grep -F 'live-wifi-sim.sh' "$SETUP" >/dev/null \
    && grep -F -- '--wifi-sim) WIFI_SIM=1' "$QEMU" >/dev/null \
    && grep -F 'opt/org.modernos/wifi-sim' "$QEMU" >/dev/null \
    && grep -F 'WIFI_SIM' "$QEMU" >/dev/null \
    && grep -qxF 'dnsmasq' "$ROOT/iso/releng/packages.x86_64" \
    && grep -F 'live-wifi-sim.sh' "$PROFILE" >/dev/null \
    && grep -F 'live-wifi-sim.sh' "$ROOT/scripts/iso-build.sh" >/dev/null \
    && grep -F 'usr/lib/modern/live-wifi-sim.sh' \
        "$ROOT/iso/airootfs/usr/lib/modern/calamares-late.sh" >/dev/null; then
    ok "iso-qemu.sh --wifi-sim drives live-wifi-sim.sh and drops the virtio NIC"
else
    err "wifi-sim must be wired from iso-qemu.sh through live-setup and stripped after unpackfs"
fi

WL="$ROOT/iso/airootfs/usr/lib/modern/live-wifi-wl.sh"
CUSTOM="$ROOT/iso/airootfs/root/customize_airootfs.sh"
if [ -x "$WL" ] \
    && grep -F 'modprobe wl' "$WL" >/dev/null \
    && grep -F 'blacklist brcmfmac' "$WL" >/dev/null \
    && grep -F 'wifi-wl.sh' "$WL" >/dev/null \
    && grep -F 'live-wifi-wl.sh' "$PROFILE" >/dev/null \
    && grep -F 'live-wifi-wl.sh' "$ROOT/scripts/iso-build.sh" >/dev/null \
    && grep -F 'install/lib/wifi-wl.sh' "$ROOT/scripts/iso-build.sh" >/dev/null \
    && grep -F 'usr/lib/modern/live-wifi-wl.sh' \
        "$ROOT/iso/airootfs/usr/lib/modern/calamares-late.sh" >/dev/null \
    && grep -F 'broadcom-wl-dkms' "$CUSTOM" >/dev/null \
    && grep -F 'linux-zen-headers' "$CUSTOM" >/dev/null \
    && grep -F 'mount --rbind' "$CUSTOM" >/dev/null \
    && grep -F 'pacman-key --init' "$CUSTOM" >/dev/null \
    && grep -F 'pacman-key --populate archlinux' "$CUSTOM" >/dev/null \
    && grep -F 'depmod -a' "$CUSTOM" >/dev/null \
    && grep -F 'mount --bind' "$ROOT/scripts/iso-build.sh" >/dev/null \
    && grep -F 'release_chroot_mounts' "$ROOT/scripts/iso-build.sh" >/dev/null \
    && ! grep -Fx linux-zen-headers "$ROOT/iso/releng/packages.x86_64" >/dev/null; then
    ok "live ISO builds wl.ko, loads it only for the proprietary PCI ids, and does not keep the headers"
else
    err "wl must be built in customize_airootfs.sh, loaded from live-wifi-wl.sh, and stripped with the headers"
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

if grep -F 'usage: calamares-late.sh strip|biosboot|clone|desktop|provision' "$LATE" >/dev/null \
    && grep -F 'timeout 180' "$LATE" >/dev/null \
    && grep -F 'GIT_HTTP_LOW_SPEED_LIMIT' "$LATE" >/dev/null \
    && grep -F '/var/log/modern-calamares-late.log' "$LATE" >/dev/null \
    && grep -F '/var/log/modern-installer' "$LATE" >/dev/null \
    && grep -F 'save_installer_log' "$LATE" >/dev/null \
    && grep -F '_emit' "$LATE" >/dev/null \
    && grep -F 'using ISO bundle' "$LATE" >/dev/null \
    && grep -F '/usr/share/modern/dotfile' "$LATE" >/dev/null \
    && grep -F 'usr/share/modern/dotfile' "$BUILD" >/dev/null \
    && grep -F 'rm -f "$resolv"' "$LATE" >/dev/null \
    && grep -F 'collect_upstream_ns' "$LATE" >/dev/null \
    && grep -F '127.*' "$LATE" >/dev/null \
    && grep -F 'hosts: files dns' "$LATE" >/dev/null \
    && grep -F 'probe_dns' "$LATE" >/dev/null \
    && grep -F 'DisableSandbox' "$LATE" >/dev/null \
    && grep -F 'pacman --disable-sandbox -Sy --noconfirm archlinux-keyring' "$LATE" >/dev/null \
    && grep -F 'pacman-key --init' "$LATE" >/dev/null \
    && grep -F 'pacman-key --populate archlinux' "$LATE" >/dev/null \
    && grep -F 'restore_boot_dns' "$LATE" >/dev/null \
    && grep -F 'mask_iwd' "$LATE" >/dev/null \
    && grep -F 'stub-resolv.conf' "$LATE" >/dev/null \
    && grep -F 'dns=systemd-resolved' "$ROOT/iso/airootfs/etc/NetworkManager/conf.d/dns.conf" >/dev/null \
    && ! grep -F 'etc/NetworkManager/conf.d/dns.conf' "$LATE" >/dev/null \
    && grep -F 'Defaults !use_pty' "$LATE" >/dev/null \
    && grep -F 'runuser -u' "$LATE" >/dev/null \
    && grep -F 'chmod a+rx /etc' "$LATE" >/dev/null \
    && grep -F 'install -d -m 0750 /etc/sudoers.d' "$LATE" >/dev/null \
    && ! grep -F 'install -d -m 0750 /etc /etc/sudoers.d' "$LATE" >/dev/null; then
    ok "calamares-late.sh is phased with a git timeout, tee, and ISO bundle"
else
    err "calamares-late.sh must take clone|desktop|provision, timeout git, tee logs, and copy the ISO bundle"
fi

CLONE_CONF="$ROOT/iso/airootfs/etc/calamares/modules/shellprocess-lateclone.conf"
DESK_CONF="$ROOT/iso/airootfs/etc/calamares/modules/shellprocess-latedesktop.conf"
PROV_CONF="$ROOT/iso/airootfs/etc/calamares/modules/shellprocess-lateprovision.conf"
if grep -E '^verbose:[[:space:]]+false$' "$CLONE_CONF" >/dev/null \
    && grep -E '^verbose:[[:space:]]+false$' "$DESK_CONF" >/dev/null \
    && grep -E '^verbose:[[:space:]]+false$' "$PROV_CONF" >/dev/null; then
    ok "late shellprocess jobs keep command output for the error dialog"
else
    err "late shellprocess confs must set verbose: false so Calamares shows stdout"
fi

if grep -E '^update_db:[[:space:]]+false$' "$PKGS_CONF" >/dev/null \
    && grep -E '^operations:[[:space:]]*\[\]$' "$PKGS_CONF" >/dev/null \
    && ! grep -E '^packages:' "$PKGS_CONF" >/dev/null \
    && grep -Fx linux-zen "$PKGS" >/dev/null \
    && ! grep -Fx linux "$PKGS" >/dev/null \
    && ! grep -Fx linux-zen-headers "$PKGS" >/dev/null \
    && grep -F "PRESETS=('archiso')" "$ROOT/iso/airootfs/etc/mkinitcpio.d/linux-zen.preset" >/dev/null \
    && grep -Fx rsync "$PKGS" >/dev/null \
    && grep -Fx python "$PKGS" >/dev/null \
    && grep -Fx squashfs-tools "$PKGS" >/dev/null \
    && grep -Fx efibootmgr "$PKGS" >/dev/null \
    && grep -Fx qt6-translations "$PKGS" >/dev/null \
    && grep -Fx yay-bin "$PKGS" >/dev/null \
    && grep -Fx yay-bin "$ROOT/iso/releng/packages.aur.x86_64" >/dev/null \
    && ! grep -Fx yay "$PKGS" >/dev/null \
    && ! grep -Fx yay "$ROOT/iso/releng/packages.aur.x86_64" >/dev/null \
    && grep -Fx matugen-bin "$PKGS" >/dev/null \
    && grep -Fx matugen-bin "$ROOT/iso/releng/packages.aur.x86_64" >/dev/null \
    && grep -Fx bibata-cursor-theme-bin "$PKGS" >/dev/null \
    && grep -Fx bibata-cursor-theme-bin "$ROOT/iso/releng/packages.aur.x86_64" >/dev/null \
    && grep -Fx phylax-git "$PKGS" >/dev/null \
    && grep -Fx phylax-git "$ROOT/iso/releng/packages.aur.x86_64" >/dev/null \
    && grep -Fx pipewire-jack "$PKGS" >/dev/null \
    && grep -Fx pipewire-pulse "$PKGS" >/dev/null; then
    ok "live ISO ships linux-zen, rsync, python, yay-bin, m0 AUR, and PipeWire jack/pulse"
else
    err "packages.x86_64 must list linux-zen (not stock linux), rsync, python, yay-bin, m0 AUR, pipewire-jack, pipewire-pulse (no linux-zen-headers)"
fi

if grep -qxF 'python-gobject' "$PKGS"; then
    ok "live ISO ships python-gobject for the Wi-Fi join"
else
    err "packages.x86_64 must list python-gobject or every Wi-Fi password fails before it is checked"
fi

if grep -qxF 'nbd' "$PKGS" && grep -qxF 'mkinitcpio-nfs-utils' "$PKGS" \
    && [ ! -e "$ROOT/iso/airootfs/usr/lib/initcpio/ipconfig" ]; then
    ok "live initramfs hooks have nbd and nfs, and do not shadow ipconfig"
else
    err "packages.x86_64 must list nbd and mkinitcpio-nfs-utils, and airootfs must not ship ipconfig"
fi
if grep -F 'rm -rf "$AIROOTFS_OUT"' "$BUILD" >/dev/null; then
    ok "staging airootfs is replaced, so a removed file cannot linger"
else
    err "iso-build must remove the staging airootfs before copying it"
fi

# shellcheck source=../scripts/lib/iso-bundle.sh
source "$ROOT/scripts/lib/iso-bundle.sh"
overlay_tmp="$(mktemp -d)"
mkdir -p "$overlay_tmp/tree/stow/shell" "$overlay_tmp/tree/install" "$overlay_tmp/tree/scripts" \
    "$overlay_tmp/bundle/stow/shell" "$overlay_tmp/bundle/install" "$overlay_tmp/bundle/scripts"
printf 'old\n' >"$overlay_tmp/bundle/stow/shell/Old.qml"
printf 'pin\n' >"$overlay_tmp/bundle/install/keep.sh"
printf 'gone\n' >"$overlay_tmp/bundle/scripts/gone.sh"
git -C "$overlay_tmp/bundle" init -q
git -C "$overlay_tmp/bundle" add -A
printf 'artwork\n' >"$overlay_tmp/tree/stow/shell/Widget.qml"
printf 'local\n' >"$overlay_tmp/tree/install/keep.sh"
printf 'extra\n' >"$overlay_tmp/tree/scripts/extra.sh"
printf 'secret\n' >"$overlay_tmp/tree/scripts/secret.key"
printf 'secret.key\n' >"$overlay_tmp/tree/.gitignore"
git -C "$overlay_tmp/tree" init -q
git -C "$overlay_tmp/tree" add stow/shell/Widget.qml install/keep.sh .gitignore
overlay_worktree_bundle "$overlay_tmp/tree" "$overlay_tmp/bundle"
if [ "$(cat "$overlay_tmp/bundle/stow/shell/Widget.qml")" = artwork ] \
    && [ "$(cat "$overlay_tmp/bundle/install/keep.sh")" = local ] \
    && [ "$(cat "$overlay_tmp/bundle/scripts/extra.sh")" = extra ] \
    && [ ! -e "$overlay_tmp/bundle/stow/shell/Old.qml" ] \
    && [ ! -e "$overlay_tmp/bundle/scripts/gone.sh" ] \
    && [ ! -e "$overlay_tmp/bundle/scripts/secret.key" ] \
    && grep -F 'overlay_worktree_bundle' "$BUILD" >/dev/null \
    && grep -F 'ALLOW_STALE_BUNDLE' "$BUILD" >/dev/null; then
    ok "stale bundle installs this working tree's install, stow and scripts"
else
    err "stale bundle must copy this working tree over the pin and drop pin-only files"
fi
rm -rf "$overlay_tmp"

if grep -F 'install -m 0644 "$ROOT/iso/releng/packages.x86_64"' "$BUILD" >/dev/null \
    && ! grep -F 'cat "$ROOT/iso/releng/packages.x86_64" >>' "$BUILD" >/dev/null; then
    ok "iso-build.sh replaces the releng package list"
else
    err "iso-build.sh must replace PROFILE_WORK/packages.x86_64, not append releng"
fi

if grep -F 'MAKEFLAGS=' "$AUR_REPO" >/dev/null \
    && grep -F 'CMAKE_BUILD_PARALLEL_LEVEL' "$AUR_REPO" >/dev/null; then
    ok "iso-aur-repo.sh sets MAKEFLAGS for the builder"
else
    err "iso-aur-repo.sh must set MAKEFLAGS (and CMake job count) for modernisoaur"
fi

if grep -F 'iso_aur_run() {' "$AUR_REPO" >/dev/null \
    && grep -F 'cd /tmp' "$AUR_REPO" >/dev/null \
    && grep -F 'cd "$1" && shift && exec "$@"' "$AUR_REPO" >/dev/null \
    && grep -F 'iso_aur_run "$build" git clone --depth 1' "$AUR_REPO" >/dev/null \
    && ! grep -F -- '--chdir' "$AUR_REPO" >/dev/null \
    && ! grep -F 'sudo -u "$ISO_AUR_BUILDER" git clone' "$AUR_REPO" >/dev/null; then
    ok "AUR commands start in a directory the builder can read"
else
    err "iso-aur-repo.sh must cd before git clone and makepkg (builder cannot walk a 0700 home, sudo --chdir is refused)"
fi

BOOTLOADER="$ROOT/iso/airootfs/etc/calamares/modules/bootloader.conf"
INSTALL_CONF="$ROOT/iso/airootfs/etc/kernel/install.conf"
if grep -F 'efiBootLoader: "systemd-boot"' "$BOOTLOADER" >/dev/null \
    && grep -F 'kernelSearchPath: "/usr/lib/modules"' "$BOOTLOADER" >/dev/null \
    && grep -F 'kernelPattern:' "$BOOTLOADER" >/dev/null \
    && grep -F '"timeout 0"' "$BOOTLOADER" >/dev/null \
    && ! grep -E '^kernel:' "$BOOTLOADER" >/dev/null \
    && grep -F 'layout=bls' "$INSTALL_CONF" >/dev/null; then
    ok "bootloader job uses systemd-boot kernel-install search paths"
else
    err "bootloader.conf must use kernelSearchPath, a hidden menu (Space opens it), and ship /etc/kernel/install.conf"
fi

MOUNT="$ROOT/iso/airootfs/etc/calamares/modules/mount.conf"
if grep -F 'btrfsSwapSubvol: /@swap' "$MOUNT" >/dev/null \
    && grep -F 'device: proc' "$MOUNT" >/dev/null \
    && grep -F 'mountPoint: /proc' "$MOUNT" >/dev/null \
    && ! grep -E 'mountPoint:[[:space:]]*/swap' "$MOUNT" >/dev/null \
    && grep -F 'device: /run/modern/installer' "$MOUNT" >/dev/null \
    && grep -F 'mountPoint: /run/modern/installer' "$MOUNT" >/dev/null \
    && grep -F '/run/modern/installer' "$ROOT/iso/airootfs/usr/lib/modern/live-setup.sh" >/dev/null \
    && grep -F 'installer-session.txt' "$ROOT/scripts/lib/bug-report-collect.sh" >/dev/null; then
    ok "mount.conf lets Calamares own the swap subvolume"
else
    err "mount.conf must keep the swap subvolume for Calamares and bind the installer log into the target"
fi

if grep -F 'import calamares.slideshow' "$SLIDE" >/dev/null \
    && grep -F 'function onActivate' "$SLIDE" >/dev/null \
    && grep -F 'wallpaper.jpg' "$SLIDE" >/dev/null \
    && grep -F 'qsTr("The Super key")' "$SLIDE" >/dev/null \
    && grep -F 'qsTr("Install an app")' "$SLIDE" >/dev/null \
    && grep -F 'interval: 8000' "$SLIDE" >/dev/null \
    && grep -F 'Super+K' "$SLIDE" >/dev/null \
    && grep -F 'Super+W' "$SLIDE" >/dev/null \
    && [ ! -e "$ROOT/iso/airootfs/etc/calamares/branding/modern/lang/calamares-modern_de.ts" ] \
    && grep -F -- '--branding-ts "$brand_lang"' "$BUILD" >/dev/null \
    && grep -F 'brand_ts=("$brand_lang"/calamares-modern_*.ts)' "$BUILD" >/dev/null \
    && python3 "$ROOT/scripts/installer-locales.py" --branding-ts "$XKB_TMP/brand" >/dev/null \
    && grep -F 'Deine Sprache' "$XKB_TMP/brand/calamares-modern_de.ts" >/dev/null \
    && ! grep -F 'Copying the live system' "$SLIDE" >/dev/null; then
    ok "install slideshow is API 2 with qsTr wallpaper slides"
else
    err "show.qml must be a Presentation slideshow with qsTr and generated per-language .ts files"
fi

if grep -F 'QProgressBar' "$QSS" >/dev/null \
    && grep -F 'QProgressBar::chunk' "$QSS" >/dev/null \
    && grep -F 'primary_container' "$QSS" >/dev/null \
    && grep -F 'on_primary_container' "$QSS" >/dev/null \
    && grep -F 'QTextBrowser' "$QSS" >/dev/null \
    && grep -F 'QPushButton:default' "$QSS" >/dev/null \
    && grep -F 'QMessageBox' "$QSS" >/dev/null; then
    ok "Calamares QSS styles the exec bar and summary"
else
    err "iso-build.sh QSS must style QProgressBar chunk from primaryContainer"
fi

if grep -E '^prompt-install:[[:space:]]*false$' "$SETTINGS" >/dev/null; then
    ok "summary Install starts exec without a confirmation dialog"
else
    err "settings.conf prompt-install must be false (cage cannot show the confirm dialog)"
fi

fixture="$XKB_TMP/base.xml"
cat >"$fixture" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<xkbConfigRegistry version="1.1">
  <layoutList>
    <layout>
      <configItem><name>fo</name></configItem>
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
    err "xkb filter produced '$got' (want 'us de 0'; fo is not in the catalog)"
fi

lst="$XKB_TMP/base.lst"
cat >"$lst" <<'LST'
! model
  pc105           Generic 105-key PC
! layout
  fo              Faroese
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
print("us" in text and "de" in text and "fo" not in text and "dvorak" not in text)
PY
)"
if [ "$lst_got" = "True" ]; then
    ok "base.lst filter keeps catalog layouts and drops variants"
else
    err "base.lst filter failed"
fi

if grep -F 'no vX.Y.Z tag in this clone' "$BUILD" >/dev/null \
    && grep -F 'console=ttyS0,115200' "$BUILD" >/dev/null \
    && grep -F 'vmlinuz-linux-zen' "$BUILD" >/dev/null \
    && grep -F 'lrelease6' "$BUILD" >/dev/null \
    && grep -F '/usr/lib/qt6/bin/lrelease' "$BUILD" >/dev/null; then
    ok "iso-build requires a release pin, serial console, and lrelease"
else
    err "iso-build.sh must refuse a missing pin, add ttyS0, and compile branding .qm"
fi

INSTALL_QEMU="$ROOT/tests/test-iso-qemu-install.sh"
# A 1.8 GB ISO is past the free Actions storage, so it is built locally
# (iso-build.sh --mkarchiso) and never by CI.
if [ ! -e "$ROOT/.github/workflows/iso.yml" ] \
    && [ ! -e "$ROOT/scripts/ci-iso-container.sh" ] \
    && ! grep -Fq 'workflow run ISO' "$ROOT/.github/workflows/release.yml" \
    && [ -x "$INSTALL_QEMU" ] \
    && grep -F -- '--unattended' "$INSTALL_QEMU" >/dev/null \
    && grep -F 'late install finished' "$INSTALL_QEMU" >/dev/null; then
    ok "the ISO is built locally, not by a release workflow"
else
    err "CI must not build the ISO; release.yml must not dispatch an ISO workflow"
fi

MODULES="$ROOT/iso/airootfs/etc/calamares/modules"
if python3 - "$SETTINGS" "$MODULES" "$BOOTLOADER" <<'PY'; then
import pathlib, re, sys
settings, modules, bootloader = (pathlib.Path(p) for p in sys.argv[1:])
text = settings.read_text(encoding="utf-8")
names = re.findall(r"^\s+-\s+([a-z0-9@]+)\s*$", text, re.M)
assert names, "no sequence modules"
for name in names:
    base = name.split("@", 1)[0]
    if name.startswith("shellprocess@"):
        inst = name.split("@", 1)[1]
        path = modules / f"shellprocess-{inst}.conf"
    else:
        path = modules / f"{base}.conf"
    # Job-only modules (machineid, fstab, ...) ship Calamares defaults.
    if path.is_file() or base in {
        "machineid", "fstab", "localecfg", "networkcfg", "hwclock", "umount",
        "summary",
    }:
        continue
    raise SystemExit(f"missing {path} for {name}")
# bootloader calls kernel-install, which builds the initramfs. Both of these
# decide what goes into it: striplive removes archiso's mkinitcpio drop-in
# (whose HOOKS would otherwise win and leave the disk in a rescue shell) and
# initcpiocfg writes HOOKS for the partitioning the user chose. striplive
# reads the account users creates, so it cannot move above users either.
order = {name: i for i, name in enumerate(names)}
for earlier, later in (
    ("users", "shellprocess@striplive"),
    ("shellprocess@striplive", "initcpiocfg"),
    ("initcpiocfg", "bootloader"),
    # biosboot runs mkinitcpio with initcpiocfg's HOOKS and must leave
    # /boot/vmlinuz-* for the bootloader job's grub-mkconfig.
    ("initcpiocfg", "shellprocess@biosboot"),
    ("shellprocess@biosboot", "bootloader"),
    ("shellprocess@striplive", "shellprocess@lateclone"),
):
    assert earlier in order, f"{earlier} missing from the sequence"
    assert later in order, f"{later} missing from the sequence"
    assert order[earlier] < order[later], f"{earlier} must run before {later}"
# The finished page's Restart button replaces the hidden footer Done, and
# Config forces restartNowWanted false when the mode is "never".
fin = (modules / "finished.conf").read_text(encoding="utf-8")
assert re.search(r"^restartNowMode:\s*(?!never)\S+", fin, re.M), "finished.conf restartNowMode"
assert re.search(r"^restartNowCommand:", fin, re.M), "finished.conf restartNowCommand"
bl = bootloader.read_text(encoding="utf-8")
assert "kernelSearchPath:" in bl and "kernelPattern:" in bl
assert not re.search(r"^kernel:", bl, re.M)
assert not re.search(r"^img:", bl, re.M)
PY
    ok "Calamares sequence modules and bootloader schema"
else
    err "settings.conf sequence must match module configs; bootloader must use kernelSearchPath"
fi

[ "$FAIL" -eq 0 ]
