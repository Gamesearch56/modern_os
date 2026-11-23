#!/usr/bin/env bash
# Calamares late: clone the ISO pin, install.sh --profile m0 --yes, provision.
# One phase per invocation so the exec bar can advance. Runs as root
# inside the target. Refuses when MODERN_PROTECT_HOME is set and exists.
set -euo pipefail

ALLOWED_URL="${MODERN_LATE_CLONE_URL:-https://github.com/Gamesearch56/modern_os.git}"
TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'
LATE_LOG="${MODERN_LATE_LOG:-/var/log/modern-calamares-late.log}"
BUNDLE="${MODERN_LATE_BUNDLE:-}"
if [ -z "$BUNDLE" ] && [ -z "${MODERN_LATE_TEST:-}" ]; then
    BUNDLE="/usr/share/modern/dotfile"
fi

_emit() {
    # stdout only: Calamares verbose:false puts stdout in the error dialog
    # and also captures stderr, so writing both duplicated every line.
    printf '%s\n' "$1"
    if mkdir -p "$(dirname "$LATE_LOG")" 2>/dev/null; then
        printf '%s\n' "$1" >>"$LATE_LOG" 2>/dev/null || true
    fi
}

die() { _emit "calamares-late: ERROR: $*"; exit 1; }
log() { _emit "calamares-late: $*"; }

phase="${1:-}"
case "$phase" in
    strip|biosboot|clone|desktop|provision) ;;
    *) die "usage: calamares-late.sh strip|biosboot|clone|desktop|provision" ;;
esac

if [ -n "${MODERN_PROTECT_HOME:-}" ] && [ -d "${MODERN_PROTECT_HOME%/}" ]; then
    die "refusing to run while MODERN_PROTECT_HOME is set and exists"
fi
if [ -z "${MODERN_LATE_TEST:-}" ] && [ "$(id -u)" -ne 0 ]; then
    die "must run as root in the install target"
fi

if [ -n "${MODERN_LATE_TEST:-}" ]; then
    USERNAME="${MODERN_CALAMARES_USER:-${USER:-test}}"
    USER_HOME="${MODERN_LATE_USER_HOME:-${HOME:-/tmp/modern-late-home}}"
    [ -n "$USERNAME" ] || die "no human user in the target"
    [ -n "$USER_HOME" ] || die "no home for $USERNAME"
else
    USERNAME=""
    if [ -n "${MODERN_CALAMARES_USER:-}" ]; then
        USERNAME="$MODERN_CALAMARES_USER"
    else
        USERNAME="$(awk -F: '$3 >= 1000 && $3 < 65534 { print $1; exit }' /etc/passwd || true)"
    fi
    [ -n "$USERNAME" ] || die "no human user in the target"
    id "$USERNAME" >/dev/null 2>&1 || die "user $USERNAME does not exist"
    USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6 || true)"
    [ -n "$USER_HOME" ] || die "no home for $USERNAME"
fi
REPO="$USER_HOME/modern_os"

PIN_FILE="${MODERN_LATE_PIN_FILE:-/usr/lib/modern/iso-pin}"
PIN="${MODERN_ISO_TAG:-}"
if [ -z "$PIN" ] && [ -f "$PIN_FILE" ]; then
    PIN="$(tr -d '[:space:]' <"$PIN_FILE")"
fi
[[ "$PIN" =~ $TAG_RE ]] || die "ISO pin is not a release tag (got '${PIN:-empty}')"

# Print non-loopback nameserver lines from $1. 127.0.0.53 is systemd's
# stub; it does not listen in the Calamares chroot (shared loopback is
# the live ISO, but nss-resolve still intercepts first).
collect_upstream_ns() {
    local f="$1" key ip found=0
    [ -f "$f" ] && [ -s "$f" ] || return 1
    while read -r key ip _; do
        [ "$key" = nameserver ] || continue
        case "$ip" in
            ""|127.*|::1) continue ;;
            *)
                printf 'nameserver %s\n' "$ip"
                found=1
                ;;
        esac
    done <"$f"
    [ "$found" -eq 1 ]
}

ensure_dns() {
    if [ -n "${MODERN_LATE_TEST:-}" ] && [ -z "${MODERN_LATE_RESOLV:-}" ]; then
        return 0
    fi
    local resolv="${MODERN_LATE_RESOLV:-/etc/resolv.conf}"
    local dir tmp
    dir="$(dirname "$resolv")"
    mkdir -p "$dir" || die "cannot create $dir for resolv.conf"
    tmp="$(mktemp "$dir/resolv.conf.XXXXXX")" || die "mktemp resolv.conf failed"
    if collect_upstream_ns "$resolv" >"$tmp" && [ -s "$tmp" ]; then
        :
    elif [ -z "${MODERN_LATE_TEST:-}" ] \
        && collect_upstream_ns /run/systemd/resolve/resolv.conf >"$tmp" \
        && [ -s "$tmp" ]; then
        :
    else
        printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\n' >"$tmp"
    fi
    rm -f "$resolv"
    mv -f "$tmp" "$resolv" || die "cannot write $resolv"
}

# Arch's default nsswitch is `resolve [!UNAVAIL=return] … dns`. nss-resolve
# talking to a dead/empty resolved returns NOTFOUND, so glibc never reads
# resolv.conf. git then dies with Could not resolve host.
ensure_nss() {
    if [ -n "${MODERN_LATE_TEST:-}" ] && [ -z "${MODERN_LATE_NSSWITCH:-}" ]; then
        return 0
    fi
    local nss="${MODERN_LATE_NSSWITCH:-/etc/nsswitch.conf}"
    [ -f "$nss" ] || return 0
    if grep -qE '^hosts:[[:space:]]+files[[:space:]]+dns[[:space:]]*$' "$nss"; then
        return 0
    fi
    local tmp
    tmp="$(mktemp "$(dirname "$nss")/nsswitch.XXXXXX")" || die "mktemp nsswitch failed"
    sed -E 's/^hosts:[[:space:]].*/hosts: files dns/' "$nss" >"$tmp"
    if ! grep -qE '^hosts:' "$tmp"; then
        printf '\nhosts: files dns\n' >>"$tmp"
    fi
    mv -f "$tmp" "$nss" || die "cannot write $nss"
}

probe_dns() {
    if [ -n "${MODERN_LATE_TEST:-}" ]; then
        return 0
    fi
    local hosts resolv out
    hosts="$(grep -E '^hosts:' /etc/nsswitch.conf 2>/dev/null || true)"
    resolv="$(tr '\n' ' ' < /etc/resolv.conf 2>/dev/null || true)"
    out="$(getent ahosts aur.archlinux.org 2>/dev/null | head -n 1 || true)"
    log "dns hosts='${hosts}' resolv='${resolv}' getent='${out:-empty}'"
    [ -n "$out" ] || die "no DNS in chroot (aur.archlinux.org). nsswitch=${hosts} resolv=${resolv}"
}

# unpackfs copies packages but not /var/lib/pacman/sync/*.db. install.sh
# then pacman -S --needed and dies with "database file for 'extra' does
# not exist" / "target not found: base". Pacman 7's DownloadUser/landlock
# sandbox cannot run in the Calamares chroot (Permission denied on the
# sync/*.db.part download).
# The pinned release carries scripts/lib/pacman-conf.sh. An older pin
# appends, which lands in the last repo section, where pacman ignores it.
pacman_option() {
    if declare -F pacman_conf_set >/dev/null; then
        pacman_conf_set "$1" "$2"
    else
        printf '\n%s\n' "$2" >>"$1"
    fi
}

ensure_pacman_db() {
    if [ -n "${MODERN_LATE_TEST:-}" ]; then
        return 0
    fi
    command -v pacman >/dev/null 2>&1 || die "pacman missing in the target"
    local conf=/etc/pacman.conf
    [ -f "$conf" ] || die "missing $conf"
    if [ -f "$REPO/scripts/lib/pacman-conf.sh" ]; then
        # shellcheck source=/dev/null
        source "$REPO/scripts/lib/pacman-conf.sh"
    fi
    if ! grep -qE '^[[:space:]]*DisableSandbox([[:space:]]|$)' "$conf"; then
        pacman_option "$conf" "DisableSandbox"
    fi
    if grep -qE '^[[:space:]]*DownloadUser' "$conf"; then
        sed -i -E 's/^[[:space:]]*DownloadUser/#DownloadUser/' "$conf"
    fi
    # systemd's post_install replaces resolv.conf with a stub under
    # /run/systemd/resolve. Calamares mounts /run as empty tmpfs, so
    # yay then dies with Temporary failure in name resolution.
    if ! grep -qE '^[[:space:]]*NoExtract[[:space:]]*=.*etc/resolv.conf' "$conf"; then
        pacman_option "$conf" "NoExtract = etc/resolv.conf etc/nsswitch.conf"
    fi
    # --noconfirm answers No to "Remove jack2?". IgnorePkg so the
    # resolver cannot pick jack2/pulseaudio for virtual jack/pulse.
    if ! grep -qE '^[[:space:]]*IgnorePkg[[:space:]]*=' "$conf"; then
        pacman_option "$conf" "IgnorePkg = jack2 jack2-dbus lib32-jack2 pulseaudio pulseaudio-bluetooth pulseaudio-jack pipewire-media-session"
    elif ! grep -qE '^[[:space:]]*IgnorePkg[[:space:]]*=.*jack2' "$conf"; then
        sed -i -E 's/^(IgnorePkg[[:space:]]*=[[:space:]]*)/\1jack2 jack2-dbus lib32-jack2 /' "$conf"
    fi
    # steam (30-apps) and lib32-gamemode (50-gaming) need multilib.
    # Stock pacman.conf comments [multilib] out, so pacman -S dies
    # with target not found.
    if ! grep -qE '^[[:space:]]*\[multilib\]' "$conf"; then
        printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >>"$conf"
    fi
    local mirrors=/etc/pacman.d/mirrorlist
    if [ -f "$mirrors" ] && ! grep -qE '^[[:space:]]*Server[[:space:]]*=' "$mirrors"; then
        # pacman expands $repo/$arch; do not interpolate here.
        # shellcheck disable=SC2016
        printf 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch\n' >>"$mirrors"
    fi
    ensure_pacman_keyring
    log "pacman -Sy archlinux-keyring (target has no repo databases until this)"
    local out
    out="$(mktemp)" || die "mktemp pacman -Sy log failed"
    if ! pacman --disable-sandbox -Sy --noconfirm archlinux-keyring >"$out" 2>&1; then
        die "pacman -Sy archlinux-keyring failed: $(tr '\n' ' ' <"$out")"
    fi
    if ! pacman-key --populate archlinux >>"$out" 2>&1; then
        die "pacman-key --populate after keyring upgrade failed: $(tr '\n' ' ' <"$out")"
    fi
    rm -f "$out"
}

# unpackfs copies the squashfs, not the live overlay. archiso's
# pacman-init.service only fills /etc/pacman.d/gnupg on the live tmpfs,
# so the target has no usable keyring. pacman -S then dies with
# "keyring is not writable" / "required key missing from keyring".
# Same idea as pacstrap -K.
ensure_pacman_keyring() {
    if [ -n "${MODERN_LATE_TEST:-}" ]; then
        return 0
    fi
    command -v pacman-key >/dev/null 2>&1 || die "pacman-key missing in the target"
    local gpg=/etc/pacman.d/gnupg
    export GNUPGHOME="$gpg"
    rm -rf "$gpg"
    install -d -m 0700 "$gpg"
    log "pacman-key --init --populate (target keyring)"
    local out
    out="$(mktemp)" || die "mktemp pacman-key log failed"
    if ! pacman-key --init >"$out" 2>&1; then
        die "pacman-key --init failed: $(tr '\n' ' ' <"$out")"
    fi
    if ! pacman-key --populate archlinux >>"$out" 2>&1; then
        die "pacman-key --populate failed: $(tr '\n' ' ' <"$out")"
    fi
    rm -f "$out"
}

# ffmpeg depends on virtual `jack`. One pacman -S with pipewire-jack
# and ffmpeg lets the resolver pick jack2. --noconfirm then answers
# No to "Remove jack2?" and the transaction dies. Drop the conflicting
# providers and install the PipeWire stack first.
ensure_pipewire_jack() {
    if [ -n "${MODERN_LATE_TEST:-}" ]; then
        return 0
    fi
    pacman --disable-sandbox -Rdd --noconfirm \
        jack2 jack2-dbus lib32-jack2 \
        pulseaudio pulseaudio-bluetooth pulseaudio-jack \
        pipewire-media-session \
        >/dev/null 2>&1 || true
    log "pipewire providers before install.sh (jack2/pulseaudio conflict)"
    local out
    out="$(mktemp)" || die "mktemp pipewire-jack log failed"
    if ! pacman --disable-sandbox -S --needed --noconfirm \
        pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber \
        >"$out" 2>&1; then
        die "pipewire providers failed: $(tr '\n' ' ' <"$out")"
    fi
    rm -f "$out"
}

# provision-iso.sh enables these units, and a missing package is a missing
# unit. Pins up to v0.1.6 list only bluez-utils (bluetoothctl); it does not
# depend on bluez, so bluetoothd, bluetooth.service and the org.bluez that
# Services/Bluetooth binds were all absent.
ensure_provision_units() {
    if [ -n "${MODERN_LATE_TEST:-}" ]; then
        return 0
    fi
    log "packages behind the units provision-iso.sh enables"
    local out
    out="$(mktemp)" || die "mktemp provision units log failed"
    if ! pacman --disable-sandbox -S --needed --noconfirm \
        bluez bluez-utils networkmanager greetd plymouth >"$out" 2>&1; then
        die "units for provision-iso.sh failed to install: $(tr '\n' ' ' <"$out")"
    fi
    rm -f "$out"
}

# Pin install.sh one-shots every native package. Last install_native in
# pkg.sh wins, so this overlay splits PipeWire out even on old tags.
# Pin lists `matugen` / `bibata-cursor-theme` (with a trailing comment).
# The ISO ships the -bin packages; --needed keys on the exact name.
overlay_pin_aur_names() {
    local f="$REPO/install/manifests/20-theming.aur.txt"
    [ -f "$f" ] || return 0
    sed -i -E \
        -e 's/^[[:space:]]*matugen([[:space:]]|#|$)/matugen-bin\1/' \
        -e 's/^[[:space:]]*bibata-cursor-theme([[:space:]]|#|$)/bibata-cursor-theme-bin\1/' \
        "$f" || true
}

# mkarchiso copies the profile airootfs with `cp -af --no-preserve=mode`,
# so every file in the bundled clone lands 0644. profiledef's
# file_permissions only restores /usr/lib/modern. Without this,
# provision-iso.sh fails its own -x guard and install.sh's direct calls
# to scripts/theme-apply.sh silently log_warn instead of theming.
# The git index carries the real modes; a bundle without .git falls back
# to *.sh plus the extensionless entry points.
restore_exec_bits() {
    local entry path
    if [ -d "$REPO/.git" ] && command -v git >/dev/null 2>&1; then
        while IFS= read -r -d '' entry; do
            case "$entry" in
                100755\ *)
                    path="${entry#*$'\t'}"
                    [ -f "$REPO/$path" ] && chmod +x "$REPO/$path"
                    ;;
            esac
        done < <(GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
            git -C "$REPO" -c "safe.directory=$REPO" ls-files -sz 2>/dev/null)
        return 0
    fi
    find "$REPO" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} +
    for path in scripts/modern scripts/modern-game scripts/modern-launch \
        install/system/modern-usersd; do
        [ -f "$REPO/$path" ] && chmod +x "$REPO/$path"
    done
    return 0
}

pin_resolver() {
    if [ -n "${MODERN_LATE_TEST:-}" ]; then
        return 0
    fi
    ensure_dns
    ensure_nss
    if command -v chattr >/dev/null 2>&1; then
        chattr +i /etc/resolv.conf /etc/nsswitch.conf 2>/dev/null || true
    fi
}

unpin_resolver() {
    if [ -n "${MODERN_LATE_TEST:-}" ]; then
        return 0
    fi
    if command -v chattr >/dev/null 2>&1; then
        chattr -i /etc/resolv.conf /etc/nsswitch.conf 2>/dev/null || true
    fi
}

# ensure_dns leaves a regular file so the chroot can resolve while /run
# is empty. That file still holds the cable's nameservers after reboot.
# NetworkManager then hands the Wi-Fi DNS to systemd-resolved, and glibc
# never asks it, so the link looks connected and names do not resolve.
# The stub symlink is what the live image shipped; resolved is already
# enabled and starts on the installed boot.
restore_boot_dns() {
    local resolv="${MODERN_LATE_RESOLV:-/etc/resolv.conf}"
    if [ -n "${MODERN_LATE_TEST:-}" ] && [ -z "${MODERN_LATE_RESOLV:-}" ]; then
        return 0
    fi
    if command -v chattr >/dev/null 2>&1; then
        chattr -i "$resolv" /etc/nsswitch.conf 2>/dev/null || true
    fi
    ln -sfn /run/systemd/resolve/stub-resolv.conf "$resolv" \
        || die "cannot point resolv.conf at systemd-resolved"
    if [ -n "${MODERN_LATE_TEST:-}" ]; then
        return 0
    fi
    systemctl enable systemd-resolved.service 2>/dev/null || true
    log "DNS handed back to systemd-resolved"
}

# The live image enables iwd. Stripping its wants symlink is not enough:
# the D-Bus service starts it again and it takes the radio from
# NetworkManager on the installed boot.
mask_iwd() {
    if [ -n "${MODERN_LATE_TEST:-}" ]; then
        return 0
    fi
    install -d -m 0755 /etc/systemd/system
    ln -sfn /dev/null /etc/systemd/system/iwd.service
}

# Without a country cfg80211 stays on the world domain: fewer 5 GHz
# channels, passive scanning there, and lower transmit power. The
# timezone from the Locale page names the country; set-wireless-regdom
# reads this file when the radio comes up.
set_wifi_country() {
    local root="${MODERN_LATE_STRIP_ROOT:-}"
    local conf="$root/etc/conf.d/wireless-regdom"
    local tab="${MODERN_LATE_ZONE_TAB:-$root/usr/share/zoneinfo/zone.tab}"
    local zone cc
    zone="$(readlink "$root/etc/localtime" 2>/dev/null || true)"
    zone="${zone#*zoneinfo/}"
    [ -n "$zone" ] && [ -f "$tab" ] || return 0
    cc="$(awk -v z="$zone" '$1 !~ /^#/ && $3 == z { print $1; exit }' "$tab")"
    [[ $cc =~ ^[A-Z]{2}$ ]] || return 0
    install -d -m 0755 "$(dirname "$conf")"
    if [ -f "$conf" ] && grep -q "^#\\?WIRELESS_REGDOM=\"$cc\"" "$conf"; then
        sed -i -e 's/^WIRELESS_REGDOM=/#WIRELESS_REGDOM=/' \
            -e "s/^#WIRELESS_REGDOM=\"$cc\"/WIRELESS_REGDOM=\"$cc\"/" "$conf"
    else
        sed -i 's/^WIRELESS_REGDOM=/#WIRELESS_REGDOM=/' "$conf" 2>/dev/null || true
        printf 'WIRELESS_REGDOM="%s"\n' "$cc" >>"$conf"
    fi
    log "Wi-Fi country set to $cc"
}

# localecfg only enables a locale that sits commented in the target's
# locale.gen and otherwise writes "# Missing:", which leaves that LANG or
# LC_* on the C locale. The generated locale.gen lists every language +
# country, so this only fires for a value it missed; glibc's SUPPORTED has
# the line then. A locale problem never fails the install: the desktop
# still starts, only dates and numbers fall back.
locale_enabled() {
    grep -qE "^[[:space:]]*${2}[[:space:]]" "$1" 2>/dev/null
}

ensure_target_locales() {
    local root="${MODERN_LATE_STRIP_ROOT:-}"
    local conf="$root/etc/locale.conf" gen="$root/etc/locale.gen"
    local supported="${MODERN_LATE_SUPPORTED:-$root/usr/share/i18n/SUPPORTED}"
    local loc re line changed=0 wanted=()
    [ -f "$conf" ] || { log "no /etc/locale.conf yet; nothing to generate"; return 0; }
    while IFS= read -r loc; do
        [ -n "$loc" ] || continue
        if ! [[ $loc =~ ^[A-Za-z0-9_.@-]+$ ]]; then
            log "WARNING: ignoring odd locale value '$loc' in locale.conf"
            continue
        fi
        [[ " ${wanted[*]} " == *" $loc "* ]] || wanted+=("$loc")
    done < <(sed -nE 's/^(LANG|LC_[A-Z]+)="?([^"]*)"?$/\2/p' "$conf")
    touch "$gen"
    for loc in "${wanted[@]}"; do
        case "$loc" in C | POSIX | C.UTF-8 | C.utf8) continue ;; esac
        re="${loc//./\\.}"
        locale_enabled "$gen" "$re" && continue
        if grep -qE "^#[[:space:]]*${re}[[:space:]]" "$gen"; then
            awk -v re="^#[[:space:]]*${re}[[:space:]]" '
                !done && $0 ~ re { sub(/^#[[:space:]]*/, ""); done = 1 } { print }
            ' "$gen" >"$gen.modern" && mv "$gen.modern" "$gen"
        else
            line="$(grep -m1 -E "^${re}[[:space:]]" "$supported" 2>/dev/null || true)"
            if [ -z "$line" ]; then
                log "WARNING: $loc is not a glibc locale; it falls back to C"
                continue
            fi
            printf '%s\n' "$line" >>"$gen"
        fi
        log "enabled locale $loc in /etc/locale.gen"
        changed=1
    done
    log "locales for this install: ${wanted[*]:-none}"
    [ "$changed" -eq 1 ] || return 0
    [ -z "${MODERN_LATE_TEST:-}" ] || return 0
    if ! locale-gen >>"$LATE_LOG" 2>&1; then
        log "WARNING: locale-gen failed; see $LATE_LOG"
        return 0
    fi
    for loc in "${wanted[@]}"; do
        locale -a 2>/dev/null | grep -qix "$(printf '%s' "$loc" | sed 's/UTF-8/utf8/I')" \
            || log "WARNING: $loc still missing after locale-gen"
    done
}

# live-wifi-up.sh writes its rtw88 option to the live overlay, which
# unpackfs does not copy. /sys in this chroot is the live kernel's, so
# the loaded parameters say whether the chip needed it.
carry_rtw88_quirk() {
    local params="${MODERN_LATE_RTW88_PARAMS:-/sys/module/rtw88_pci/parameters}"
    local dest="${MODERN_LATE_STRIP_ROOT:-}/etc/modprobe.d/modern-rtw88.conf"
    if [ -n "${MODERN_LATE_TEST:-}" ] && [ -z "${MODERN_LATE_RTW88_PARAMS:-}" ]; then
        return 0
    fi
    [ "$(cat "$params/disable_aspm" 2>/dev/null)" = Y ] || return 0
    install -d -m 0755 "$(dirname "$dest")"
    printf 'options rtw88_pci disable_aspm=y disable_msi=y\n' >"$dest"
    log "rtw88 Wi-Fi keeps PCIe ASPM and MSI off"
}

# The installed tree is the release tag, not this script. v0.6.21's
# ge_proton_ensure aborts install.sh when curl cannot resolve github.com.
overlay_pin_ge_proton() {
    local f="$REPO/install/lib/ge-proton.sh"
    [ -f "$f" ] || return 0
    grep -qF 'continuing without it' "$f" && return 0
    # shellcheck disable=SC2016
    grep -qF 'curl -fL --retry 3 -o "$tar.part" "$GE_PROTON_URL"' "$f" || return 0
    python3 - "$f" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
old = """        log_info "downloading GE-Proton${GE_PROTON_VERSION}"
        curl -fL --retry 3 -o "$tar.part" "$GE_PROTON_URL"
        mv -f "$tar.part" "$tar"
"""
new = """        log_info "downloading GE-Proton${GE_PROTON_VERSION}"
        if ! curl -fL --retry 2 --retry-max-time 20 --connect-timeout 10 -o "$tar.part" "$GE_PROTON_URL"; then
            rm -f "$tar.part"
            log_warn "could not download GE-Proton${GE_PROTON_VERSION} from ${GE_PROTON_URL}; continuing without it"
            return 0
        fi
        mv -f "$tar.part" "$tar"
"""
text = path.read_text()
if old not in text:
    sys.exit(0)
path.write_text(text.replace(old, new, 1))
PY
    if grep -qF 'continuing without it' "$f"; then
        log "GE-Proton download no longer aborts the install"
    else
        log "GE-Proton download patch did not apply"
    fi
}

# v0.6.22 parks the menu on recovery whenever that entry exists.
# A first install has not booted yet, so the default must be ModernOS.
overlay_pin_kernel_boot() {
    local f="$REPO/install/lib/kernel-boot.sh"
    [ -f "$f" ] || return 0
    grep -qF 'kernel_boot_has_confirmed' "$f" && return 0
    grep -qF 'kernel_boot_arm()' "$f" || return 0
    python3 - "$f" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
end = "}\n"
old = """kernel_boot_arm() {
    local root="$1" boot
    boot="$root/boot"
    if [ -f "$boot/loader/entries/modern-keep.conf" ] && kernel_boot_oneshot "$root" modern.conf; then
        kernel_boot_set_default "$boot" modern-keep.conf
        kernel_boot_note "next boot tries the new kernel once"
        return 0
    fi
    kernel_boot_set_default "$boot" modern.conf
""" + end
new = """kernel_boot_confirmed_file() {
    printf '%s/var/lib/modern/boot-confirmed\\n' "$(kernel_boot_root)"
    """ + end + """
kernel_boot_has_confirmed() {
    [ -s "$(kernel_boot_confirmed_file)" ]
    """ + end + """
kernel_boot_mark_confirmed() {
    local dest
    dest="$(kernel_boot_confirmed_file)"
    install -d -m 0755 "$(dirname "$dest")"
    printf '%s\\n' "$(kernel_boot_boot_id)" >"$dest"
    chmod 0644 "$dest"
    """ + end + """
kernel_boot_arm() {
    local root="$1" boot
    boot="$root/boot"
    if kernel_boot_has_confirmed \\
        && [ -f "$boot/loader/entries/modern-keep.conf" ] \\
        && kernel_boot_oneshot "$root" modern.conf; then
        kernel_boot_set_default "$boot" modern-keep.conf
        kernel_boot_note "next boot tries the new kernel once"
        return 0
    fi
    kernel_boot_set_default "$boot" modern.conf
""" + end
text = path.read_text()
if old not in text:
    sys.exit(0)
text = text.replace(old, new, 1)
needle = '    kernel_boot_set_default "$root/boot" modern.conf\n    kernel_boot_note "boot menu keeps /vmlinuz-linux-zen"'
insert = '    kernel_boot_set_default "$root/boot" modern.conf\n    kernel_boot_mark_confirmed\n    kernel_boot_note "boot menu keeps /vmlinuz-linux-zen"'
if needle in text:
    text = text.replace(needle, insert, 1)
path.write_text(text)
PY
    if grep -qF 'kernel_boot_has_confirmed' "$f"; then
        log "boot menu defaults to ModernOS until a kernel has booted"
    else
        log "boot menu default patch did not apply"
    fi
}

overlay_pin_install_native() {
    local pkg="$REPO/install/lib/pkg.sh"
    [ -f "$pkg" ] || return 0
    sed -i 's/sudo pacman -S --needed --noconfirm/sudo pacman --disable-sandbox -S --needed --noconfirm/' \
        "$pkg" || true
    grep -qF 'modern ISO pin overlay' "$pkg" && return 0
    cat >>"$pkg" <<'EOF'

# modern ISO pin overlay (appended by calamares-late.sh)
install_native() {
    local pkgs=("$@") providers=() rest=() p
    [ ${#pkgs[@]} -eq 0 ] && return 0
    log_info "Installing ${#pkgs[@]} native package(s): ${pkgs[*]}"
    run sudo pacman --disable-sandbox -Rdd --noconfirm \
        jack2 jack2-dbus lib32-jack2 \
        pulseaudio pulseaudio-bluetooth pulseaudio-jack \
        pipewire-media-session || true
    for p in "${pkgs[@]}"; do
        case "$p" in
            pipewire|pipewire-alsa|pipewire-jack|pipewire-pulse|wireplumber)
                providers+=("$p") ;;
            *) rest+=("$p") ;;
        esac
    done
    if [ ${#providers[@]} -gt 0 ]; then
        run sudo pacman --disable-sandbox -S --needed --noconfirm "${providers[@]}"
    fi
    [ ${#rest[@]} -eq 0 ] && return 0
    run sudo pacman --disable-sandbox -S --needed --noconfirm "${rest[@]}"
}

install_aur() {
    local requested=("$@") pkgs=() p
    [ ${#requested[@]} -eq 0 ] && return 0
    for p in "${requested[@]}"; do
        if aur_pkg_present "$p"; then
            continue
        fi
        pkgs+=("$p")
    done
    if [ ${#pkgs[@]} -eq 0 ]; then
        log_ok "AUR packages already installed"
        return 0
    fi
    if [ -n "${MODERN_SKIP_AUR:-}" ]; then
        log_warn "skipping AUR (${#pkgs[@]} not installed): ${pkgs[*]}"
        return 0
    fi
    log_info "Installing ${#pkgs[@]} AUR package(s): ${pkgs[*]}"
    run yay -S --needed --noconfirm "${pkgs[@]}"
}
EOF
}

# The overlay above is only for this chroot install. Left in the home
# clone, the next desktop update stops with "work tree is dirty".
restore_installer_edits() {
    [ -d "$REPO/.git" ] || return 0
    local path paths=()
    for path in install/lib/pkg.sh install/lib/kernel-boot.sh install/manifests/20-theming.aur.txt; do
        if GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
            git -C "$REPO" -c "safe.directory=$REPO" -c core.hooksPath=/dev/null \
            cat-file -e "HEAD:$path" 2>/dev/null; then
            paths+=("$path")
        fi
    done
    [ "${#paths[@]}" -eq 0 ] && return 0
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
        git -C "$REPO" -c "safe.directory=$REPO" -c core.hooksPath=/dev/null \
        checkout -- "${paths[@]}" \
        || die "could not restore installer edits in $REPO"
}

ensure_pts() {
    if [ -n "${MODERN_LATE_TEST:-}" ]; then
        return 0
    fi
    install -d -m 0755 /dev/pts
    if mountpoint -q /dev/pts 2>/dev/null; then
        return 0
    fi
    mount -t devpts -o nosuid,noexec,gid=5,mode=620,ptmxmode=666 \
        devpts /dev/pts 2>/dev/null || true
}

# Prefer the target's locale.conf over the live ISO LANG so
# xdg-user-dirs-update creates Bilder rather than Pictures.
user_locale_lang() {
    local conf="${MODERN_LOCALE_CONF:-/etc/locale.conf}" line
    if [ -f "$conf" ]; then
        line="$(sed -nE "s/^[[:space:]]*LANG=[\"']?([^\"'[:space:]]+).*/\1/p" "$conf" | head -1)"
        if [ -n "$line" ]; then
            printf '%s\n' "$line"
            return
        fi
    fi
    printf '%s\n' "${LANG:-C.UTF-8}"
}

as_user() {
    local lang
    lang="$(user_locale_lang)"
    if [ -n "${MODERN_LATE_TEST:-}" ]; then
        env HOME="$USER_HOME" \
            XDG_CONFIG_HOME="$USER_HOME/.config" \
            XDG_STATE_HOME="$USER_HOME/.local/state" \
            XDG_DATA_HOME="$USER_HOME/.local/share" \
            LANG="$lang" LC_MESSAGES="$lang" \
            GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
            MODERN_PACMAN_NOSANDBOX=1 \
            MODERN_SKIP_AUR=1 \
            "$@"
        return
    fi
    command -v runuser >/dev/null 2>&1 || die "runuser missing (util-linux)"
    runuser -u "$USERNAME" -- env HOME="$USER_HOME" \
        XDG_CONFIG_HOME="$USER_HOME/.config" \
        XDG_STATE_HOME="$USER_HOME/.local/state" \
        XDG_DATA_HOME="$USER_HOME/.local/share" \
        LANG="$lang" LC_MESSAGES="$lang" \
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
        MODERN_PACMAN_NOSANDBOX=1 \
        MODERN_SKIP_AUR=1 \
        "$@"
}

# unpackfs lays the live airootfs down as the installed root, so every
# live-only file arrives with it. This runs before bootloader, because that
# step's kernel-install builds the initramfs, and mkinitcpio reads
# /etc/mkinitcpio.conf.d after /etc/mkinitcpio.conf — archiso.conf's
# HOOKS win over anything initcpiocfg writes. The archiso hook swaps the
# root mount handler for one that mounts $archisodevice, and a disk boot
# passes no archisolabel, so the initramfs drops to a rescue shell with
# "'' device did not show up after 30 seconds".
#
# The rest are not cosmetic either. etc-pacman.d-gnupg.mount tmpfs-mounts
# over the keyring and pacman-init.service re-creates it on every boot.
# getty@tty1 is masked to /dev/null for the kiosk, which would leave no
# console when greetd fails. greetd.service.wants starts
# modern-live-setup.service, which creates the passwordless liveuser that
# 99-liveuser and the polkit rule hand root to. iwd.service enabled on its
# own fights NetworkManager.
#
# Networking is the live split too: releng runs systemd-networkd for wired
# and wlan DHCP, and wifi-backend.conf tells NetworkManager to leave
# Ethernet to networkd and drive Wi-Fi with wpa_supplicant. Kept on the
# installed system that hides a cable from Settings > Network, races NM's
# DHCP on wifi, and stalls boot in networkd-wait-online without one.
# NetworkManager owns every interface there, on that same backend.
LIVE_ONLY_PATHS=(
    etc/mkinitcpio.conf.d/archiso.conf
    etc/mkinitcpio.d/linux.preset
    etc/mkinitcpio.d/linux-zen.preset
    etc/systemd/system/getty@tty1.service
    etc/systemd/system/getty@tty1.service.d/autologin.conf
    etc/systemd/system/choose-mirror.service
    etc/systemd/system/livecd-alsa-unmuter.service
    etc/systemd/system/livecd-talk.service
    etc/systemd/system/pacman-init.service
    etc/systemd/system/etc-pacman.d-gnupg.mount
    etc/systemd/system/multi-user.target.wants/choose-mirror.service
    etc/systemd/system/multi-user.target.wants/livecd-talk.service
    etc/systemd/system/multi-user.target.wants/pacman-init.service
    etc/systemd/system/multi-user.target.wants/iwd.service
    etc/systemd/system/multi-user.target.wants/sshd.service
    etc/systemd/system/multi-user.target.wants/systemd-networkd.service
    etc/systemd/system/sockets.target.wants/systemd-networkd.socket
    etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service
    etc/systemd/network/20-ethernet.network
    etc/systemd/network/20-wlan.network
    etc/systemd/network/20-wwan.network
    etc/NetworkManager/conf.d/wifi-backend.conf
    etc/systemd/system/greetd.service.wants/modern-live-i18n.service
    etc/systemd/system/greetd.service.wants/modern-live-setup.service
    usr/lib/systemd/system/modern-live-i18n.service
    usr/lib/systemd/system/modern-live-setup.service
    usr/lib/modern/live-calamares.sh
    usr/lib/modern/live-i18n.sh
    usr/lib/modern/live-session.sh
    usr/lib/modern/live-setup.sh
    usr/lib/modern/live-xdg-open.sh
    usr/lib/modern/live-xkb-filter.py
    usr/lib/modern/live-xkb.sh
    usr/lib/modern/live-xkb-cage.so
    usr/lib/modern/live-wifi-sim.sh
    usr/lib/modern/live-wifi-wl.sh
    usr/lib/modern/live-wifi-up.sh
    usr/lib/modern/wifi-wl.sh
    usr/lib/modern/wifi-join.sh
    usr/local/bin/xdg-open
    etc/modern/live-hyprland.lua
    etc/modern/openbox-rc.xml
    etc/sudoers.d/99-liveuser
    etc/polkit-1/rules.d/49-modern-liveuser.rules
    root/.automated_script.sh
    root/.zlogin
)

strip_live() {
    local root="${MODERN_LATE_STRIP_ROOT:-}"
    local p dest
    for p in "${LIVE_ONLY_PATHS[@]}"; do
        rm -f "$root/$p"
    done
    dest="$root/etc/mkinitcpio.d/linux-zen.preset"
    install -d -m 0755 "$(dirname "$dest")"
    cat >"$dest" <<'EOF'
# Restored after the live archiso preset is stripped.
# ALL_kver is where the kernel package copies the new vmlinuz. Without
# it, mkinitcpio skips the image and the next boot loads the previous
# kernel after its modules have been removed.
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux-zen"
PRESETS=('default' 'fallback')
default_image="/boot/initramfs-linux-zen.img"
fallback_image="/boot/initramfs-linux-zen-fallback.img"
fallback_options="-S autodetect"
EOF
    rm -rf "$root/etc/calamares"
    if [ -z "${MODERN_LATE_TEST:-}" ] && id liveuser >/dev/null 2>&1; then
        userdel -r liveuser >/dev/null 2>&1 || true
    fi
}

# Installer and kiosk packages from packages.x86_64 that unpackfs copied
# as explicit installs. Runs last: provision-iso.sh and install.sh still
# use pacman's db in this chroot, not these binaries. If something outside
# the set depends on one name, the set fails as a whole; then each name
# goes on its own so only the depended-on one stays.
LIVE_ONLY_PKGS=(
    calamares kcrash cage openbox firefox xorg-xhost xorg-setxkbmap
    syslinux mkinitcpio-archiso squashfs-tools nano
)

live_only_removable() {
    local efi="${MODERN_LATE_EFI_DIR:-/sys/firmware/efi}"
    local p
    for p in "${LIVE_ONLY_PKGS[@]}"; do
        printf '%s\n' "$p"
    done
    # systemd-boot owns UEFI installs; GRUB is the BIOS bootloader only.
    [ -d "$efi" ] && printf 'grub\n'
    return 0
}

strip_live_packages() {
    local p pkgs=() kept=()
    while IFS= read -r p; do
        pacman -Q "$p" >/dev/null 2>&1 && pkgs+=("$p")
    done < <(live_only_removable)
    [ ${#pkgs[@]} -gt 0 ] || return 0
    log "removing live-only packages: ${pkgs[*]}"
    pacman --disable-sandbox -Rns --noconfirm "${pkgs[@]}" >/dev/null 2>&1 && return 0
    for p in "${pkgs[@]}"; do
        pacman -Q "$p" >/dev/null 2>&1 || continue
        pacman --disable-sandbox -Rns --noconfirm "$p" >/dev/null 2>&1 || kept+=("$p")
    done
    [ ${#kept[@]} -eq 0 ] || log "kept (still a dependency): ${kept[*]}"
}

phase_strip() {
    log "removing the live-only files unpackfs copied into the target"
    strip_live
    carry_rtw88_quirk
    set_wifi_country
    ensure_target_locales
    local drop="${MODERN_LATE_STRIP_ROOT:-}/etc/mkinitcpio.conf.d/archiso.conf"
    [ ! -e "$drop" ] || die "$drop survived; the target would boot to a rescue shell"
    log "live-only files removed"
}

# UEFI installs get kernel and initramfs from systemd-boot's kernel-install.
# On BIOS the bootloader job runs grub-install + grub-mkconfig instead, and
# grub-mkconfig only finds /boot/vmlinuz-*. mkarchiso empties /boot in the
# squashfs, so without this GRUB is written with no menu entry at all.
phase_biosboot() {
    local efi="${MODERN_LATE_EFI_DIR:-/sys/firmware/efi}"
    local root="${MODERN_LATE_STRIP_ROOT:-}"
    if [ -d "$efi" ]; then
        log "UEFI firmware — systemd-boot installs the kernel"
        return 0
    fi
    local d kver=""
    for d in "$root"/usr/lib/modules/*/; do
        if [ "$(cat "$d/pkgbase" 2>/dev/null)" = linux-zen ] && [ -f "$d/vmlinuz" ]; then
            kver="$(basename "$d")"
            break
        fi
    done
    [ -n "$kver" ] || die "no linux-zen kernel under /usr/lib/modules"
    log "BIOS firmware — installing linux-zen $kver to /boot for GRUB"
    install -D -m 0644 "$root/usr/lib/modules/$kver/vmlinuz" "$root/boot/vmlinuz-linux-zen"
    # Kernel updates run `mkinitcpio -p linux-zen`. With no ALL_kver the
    # image is skipped and the previous kernel boots without its modules.
    local preset="$root/etc/mkinitcpio.d/linux-zen.preset"
    if [ -f "$preset" ] && ! grep -q '^ALL_kver=' "$preset"; then
        printf 'ALL_kver="/boot/vmlinuz-linux-zen"\n' >>"$preset"
    fi
    if [ -n "${MODERN_LATE_TEST:-}" ]; then
        return 0
    fi
    local out
    out="$(mktemp)" || die "mktemp mkinitcpio log failed"
    if ! mkinitcpio -k "$kver" -g /boot/initramfs-linux-zen.img >"$out" 2>&1 \
        || ! mkinitcpio -k "$kver" -S autodetect -g /boot/initramfs-linux-zen-fallback.img >>"$out" 2>&1; then
        die "mkinitcpio for $kver failed: $(tail -n 20 "$out" | tr '\n' ' ')"
    fi
    rm -f "$out"
    log "initramfs for $kver written"
}

# The ISO carries the deploy key root-only. Move it into the new
# account and drop the system copy so it does not stay on the disk
# world-reachable after install. No key file means HTTPS updates.
install_deploy_key() {
    local src dest
    if [ -n "${MODERN_DEPLOY_KEY_SRC:-}" ]; then
        src="$MODERN_DEPLOY_KEY_SRC"
    elif [ -n "${MODERN_LATE_TEST:-}" ]; then
        return 0
    else
        src="/usr/lib/modern/deploy_key"
    fi
    [ -e "$src" ] || [ -L "$src" ] || return 0
    if [ -L "$src" ]; then
        rm -f "$src"
        log "ignored deploy key symlink"
        return 0
    fi
    dest="$USER_HOME/.config/modern/deploy_key"
    install -d -m 0700 "$USER_HOME/.config/modern"
    install -m 0600 "$src" "$dest" || die "could not install the GitHub deploy key"
    rm -f "$src" || die "could not remove the deploy key from the system image"
    log "GitHub deploy key installed for $USERNAME"
}

phase_clone() {
    ensure_dns
    ensure_nss
    install -d -m 0750 "$USER_HOME"
    install_deploy_key
    rm -rf "$REPO"
    log "clone $PIN user=$USERNAME home=$USER_HOME bundle=$BUNDLE url=$ALLOWED_URL"
    if [ -d "$BUNDLE/install" ]; then
        log "using ISO bundle $BUNDLE"
        cp -a "$BUNDLE" "$REPO" || die "copy of ISO bundle to $REPO failed"
    else
        file_allow=never
        if [ -n "${MODERN_LATE_TEST:-}" ]; then
            file_allow=always
        fi
        log "git clone $ALLOWED_URL at $PIN"
        clone_log="$(mktemp)" || die "mktemp failed"
        if ! GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
            GIT_HTTP_LOW_SPEED_LIMIT=1024 GIT_HTTP_LOW_SPEED_TIME=45 \
            /usr/bin/timeout 180 /usr/bin/git \
            -c core.hooksPath=/dev/null -c "protocol.file.allow=${file_allow}" \
            -c fetch.recurseSubmodules=false \
            clone --depth 1 --branch "$PIN" "$ALLOWED_URL" "$REPO" \
            >"$clone_log" 2>&1; then
            die "git clone of $PIN failed (network or timeout): $(tr '\n' ' ' <"$clone_log")"
        fi
        rm -f "$clone_log"
    fi
    if [ -d "$REPO/.git" ]; then
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
            /usr/bin/git -C "$REPO" -c core.hooksPath=/dev/null config core.hooksPath /dev/null
    fi
    restore_exec_bits
    if [ -z "${MODERN_LATE_TEST:-}" ]; then
        chown -R "$USERNAME:$USERNAME" "$REPO" "$USER_HOME" \
            || die "chown of $REPO for $USERNAME failed"
    fi
    log "cloned $PIN for $USERNAME"
}

INSTALL_SUDOERS=/etc/sudoers.d/99-modern-calamares

# Passwordless sudo exists only for install.sh. A failed or aborted run
# must not leave it in the installed system.
drop_install_sudo() {
    [ -n "${MODERN_LATE_TEST:-}" ] || rm -f "$INSTALL_SUDOERS"
}

# modern-portal comes from the squashfs (iso-local-pkgs.sh) or install.sh.
# Missing it does not break the desktop, so this only reports.
report_portal() {
    [ -z "${MODERN_LATE_TEST:-}" ] || return 0
    if pacman -Q modern-portal >/dev/null 2>&1; then
        log "file chooser portal installed"
    else
        log "WARN: modern-portal is missing; apps keep the GTK file chooser"
    fi
}

phase_desktop() {
    [ -d "$REPO/install" ] || die "clone phase did not leave $REPO"
    ensure_dns
    ensure_nss
    probe_dns
    ensure_pacman_db
    ensure_pipewire_jack
    ensure_pts
    if [ -z "${MODERN_LATE_TEST:-}" ]; then
        # install -d -m 0750 /etc also chmod's an existing /etc to 0750.
        # The target user then cannot read /etc/gitconfig (yay bootstrap).
        chmod a+rx /etc 2>/dev/null || true
        install -d -m 0750 /etc/sudoers.d
        # sudo 1.9+ Defaults use_pty; Calamares chroot has no /dev/pts.
        trap drop_install_sudo EXIT
        printf 'Defaults !use_pty\n%s ALL=(ALL) NOPASSWD: ALL\n' "$USERNAME" \
            >"$INSTALL_SUDOERS"
        chmod 0440 "$INSTALL_SUDOERS"
    fi
    # ISO pin's pkg.sh may not pass --disable-sandbox; install.sh itself
    # is the tagged copy, not this working tree.
    overlay_pin_ge_proton
    overlay_pin_kernel_boot
    overlay_pin_install_native
    overlay_pin_aur_names
    pin_resolver
    export MODERN_PACMAN_NOSANDBOX=1
    log "running install.sh --profile m0 --yes"
    local out
    out="$(mktemp)" || die "mktemp install.sh log failed"
    if ! as_user bash "$REPO/install/install.sh" --profile m0 --yes >"$out" 2>&1; then
        unpin_resolver
        log "ERROR: install.sh --profile m0 --yes failed"
        if [ -s "$out" ]; then
            sed 's/\x1b\[[0-9;]*[mK]//g' "$out" | tail -n 40 \
                | while IFS= read -r line || [ -n "$line" ]; do
                    _emit "$line"
                done
        elif [ -f "$REPO/install/install.log" ]; then
            tail -n 40 "$REPO/install/install.log" \
                | while IFS= read -r line || [ -n "$line" ]; do
                    _emit "$line"
                done
        fi
        rm -f "$out"
        exit 1
    fi
    unpin_resolver
    rm -f "$out"
    ensure_provision_units
    report_portal
    restore_installer_edits
    log "desktop install finished for $USERNAME"
}

# install.sh copied the release pin's greeter. That pin modesets a dark
# panel, which is the firmware picture between the login screen and the
# desktop. The .next files are this image's copies and are what the
# installed system has to run.
install_image_seat() {
    local pair src dest
    [ -n "${MODERN_LATE_TEST:-}" ] && return 0
    for pair in \
        /usr/lib/modern/seat-cover.next:/usr/lib/modern/seat-cover.py \
        /usr/lib/modern/seat-nomodeset.next:/usr/lib/modern/seat-nomodeset.so \
        /usr/lib/modern/desktop-session.next:/usr/lib/modern/desktop-session.sh \
        /etc/greetd/kiosk.next:/etc/greetd/kiosk.sh
    do
        src=${pair%%:*}
        dest=${pair#*:}
        [ -f "$src" ] || continue
        install -m 0755 "$src" "$dest" || log "could not install $dest"
        log "installed $(basename "$dest") from this image"
    done
}

phase_provision() {
    # -f, not -x: the bundle arrives mode-stripped and this runs via bash.
    [ -f "$REPO/install/system/provision-iso.sh" ] || die "clone phase did not leave provision-iso.sh"
    drop_install_sudo
    ensure_dns
    ensure_nss
    export MODERN_ISO_PROVISION=1
    log "provisioning greetd and NetworkManager"
    bash "$REPO/install/system/provision-iso.sh" "$USERNAME" \
        || die "provision-iso.sh failed"
    [ -n "${MODERN_LATE_TEST:-}" ] || strip_live_packages
    # DisableSandbox and the commented DownloadUser were for this chroot.
    if [ -z "${MODERN_LATE_TEST:-}" ] && [ -f "$REPO/scripts/lib/pacman-conf.sh" ]; then
        # shellcheck source=/dev/null
        source "$REPO/scripts/lib/pacman-conf.sh"
        pacman_conf_repair /etc/pacman.conf || log "could not tidy pacman.conf"
    fi
    mask_iwd
    restore_boot_dns
    install_image_seat
    log "late install finished for $USERNAME at $PIN"
}

case "$phase" in
    strip) phase_strip ;;
    biosboot) phase_biosboot ;;
    clone) phase_clone ;;
    desktop) phase_desktop ;;
    provision) phase_provision ;;
esac
