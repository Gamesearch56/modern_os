#!/usr/bin/env bash
# Solid boot/shutdown splash. Sourced by provision-iso.sh, which rebuilds
# the initramfs once after NVIDIA modules are staged. Run this file
# directly to enable the splash on an already installed machine:
#   sudo install/system/plymouth/apply.sh
# Settings → Update runs the same function from the root plan.
# theme-apply.sh and wallpaper-sync.sh must not call it. The initramfs
# is rebuilt only when the theme or the hook actually changed.
set -euo pipefail

plymouth_repo() {
    if [ -n "${PROVISION_ROOT:-}" ]; then
        printf '%s\n' "$PROVISION_ROOT"
        return 0
    fi
    cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd
}

# Drop a replaced flag, keep everything else (root=, NVIDIA modeset).
plymouth_merge_options() {
    local line="$1" word
    local -a words=() keep=()
    line="${line#options}"
    read -ra words <<<"$line"
    for word in "${words[@]+"${words[@]}"}"; do
        case "$word" in
            ""|loglevel=*|systemd.show_status=*|rd.systemd.show_status=*|rd.udev.log_priority=*|udev.log_level=*|vt.global_cursor_default=*|i915.fastboot=*|i915.enable_psr=*)
                continue ;;
        esac
        keep+=("$word")
    done
    local has_quiet=0 has_splash=0
    for word in "${keep[@]+"${keep[@]}"}"; do
        [ "$word" = quiet ] && has_quiet=1
        [ "$word" = splash ] && has_splash=1
    done
    [ "$has_quiet" -eq 1 ] || keep=(quiet ${keep[@]+"${keep[@]}"})
    [ "$has_splash" -eq 1 ] || keep+=(splash)
    # auto prints status on the console whenever Plymouth is not running.
    # That is the terminal text between the splash, the login screen and
    # the desktop, and on shutdown. 0 keeps the console quiet; the journal
    # still has the lines. i915.fastboot was removed in Linux 6.7 (the
    # driver already keeps the mode, and the parameter is logged as
    # unknown). Panel self-refresh is what puts the firmware picture back
    # on an Intel laptop panel while no CRTC is scanning.
    keep+=(loglevel=3 systemd.show_status=0 rd.systemd.show_status=0 rd.udev.log_priority=3 udev.log_level=3 vt.global_cursor_default=0 i915.enable_psr=0)
    printf '%s\n' "${keep[*]}"
}

plymouth_write_options_file() {
    local file="$1" prefix="$2" current merged
    [ -f "$file" ] || return 0
    if [ -n "$prefix" ]; then
        current="$(grep -E "^${prefix}" "$file" | head -n 1 || true)"
    else
        current="$(head -n 1 "$file" || true)"
    fi
    [ -n "$current" ] || return 0
    merged="$(plymouth_merge_options "$current")"
    local tmp
    tmp="$(mktemp)"
    if [ -n "$prefix" ]; then
        awk -v repl="options ${merged}" '
            BEGIN { done = 0 }
            /^options[[:space:]]/ && !done { print repl; done = 1; next }
            { print }
        ' "$file" >"$tmp"
    else
        printf '%s\n' "$merged" >"$tmp"
    fi
    cat "$tmp" >"$file"
    rm -f "$tmp"
}

plymouth_insert_hook() {
    local file="$1" tmp
    [ -f "$file" ] || return 1
    grep -q '^HOOKS=(' "$file" || return 1
    tmp="$(mktemp)"
    awk '
        function emit(parts, n, out, i) {
            n = split(parts, a, /[[:space:]]+/)
            out = ""
            for (i = 1; i <= n; i++) {
                if (a[i] == "" || a[i] == "plymouth")
                    continue
                out = out (out == "" ? "" : " ") a[i]
                if (a[i] == "kms")
                    out = out " plymouth"
            }
            if (out !~ /(^| )plymouth( |$)/) {
                if (out ~ /(^| )block( |$)/)
                    sub(/block/, "kms plymouth block", out)
                else
                    out = out (out == "" ? "" : " ") "plymouth"
            }
            return out
        }
        /^HOOKS=\(/ && !done {
            line = $0
            sub(/^HOOKS=\(/, "", line)
            sub(/\).*/, "", line)
            print "HOOKS=(" emit(line) ")"
            done = 1
            next
        }
        { print }
    ' "$file" >"$tmp"
    cat "$tmp" >"$file"
    rm -f "$tmp"
}

plymouth_hooks_file() {
    local root="$1" f last=""
    if [ -d "${root%/}/etc/mkinitcpio.conf.d" ]; then
        for f in "${root%/}/etc/mkinitcpio.conf.d"/*.conf; do
            [ -f "$f" ] || continue
            grep -q '^HOOKS=(' "$f" && last="$f"
        done
    fi
    if [ -n "$last" ]; then
        printf '%s\n' "$last"
        return 0
    fi
    printf '%s\n' "${root%/}/etc/mkinitcpio.conf"
}

plymouth_apply() {
    local root="${1:-/}"
    local repo theme dest conf hooks entries ent
    root="${root%/}"
    [ -n "$root" ] || root="/"
    repo="$(plymouth_repo)"
    theme="$repo/install/system/plymouth/modern"
    dest="$root/usr/share/plymouth/themes/modern"
    plymouth_rebuild=0
    [ -f "$theme/modern.script" ] || return 1
    install -d -m 0755 "$dest" "$root/etc/plymouth" "$root/usr/share/plymouth/themes" \
        "$root/etc/systemd/system/plymouth-quit.service.d" \
        "$root/usr/lib/modern" "$root/etc/polkit-1/rules.d"
    install -m 0644 "$repo/install/system/plymouth/retain.conf" \
        "$root/etc/systemd/system/plymouth-quit.service.d/retain.conf"
    # Opens the real GPU before Plymouth quits, so that quit cannot put
    # the firmware picture back. It does not delay quit and does not stay
    # master. The old handoff that blocked quit is still removed below.
    install -m 0644 "$repo/install/system/plymouth/modern-splash-pin.service" \
        "$root/etc/systemd/system/modern-splash-pin.service"
    install -m 0644 "$repo/install/system/plymouth/pin.conf" \
        "$root/etc/systemd/system/plymouth-quit.service.d/pin.conf"
    # Holding Plymouth until the login compositor painted left some
    # laptops on the loading screen: the compositor never got the
    # display, and the splash stayed. Remove that handoff on update.
    rm -f "$root/etc/systemd/system/greetd.service.d/plymouth.conf" \
        "$root/etc/systemd/system/modern-plymouth-handoff.service" \
        "$root/usr/lib/modern/plymouth-handoff.sh" \
        "$root/usr/lib/modern/display-handoff.sh"
    install -m 0644 "$repo/install/system/plymouth/modern-splash.service" \
        "$root/etc/systemd/system/modern-splash.service"
    install -m 0755 "$repo/scripts/splash-hold.sh" \
        "$root/usr/lib/modern/splash-hold.sh"
    install -m 0644 "$repo/install/system/plymouth/50-modern-splash.rules" \
        "$root/etc/polkit-1/rules.d/50-modern-splash.rules"
    if [ "$root" = "/" ] && command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload || true
    fi
    if ! cmp -s "$theme/modern.plymouth" "$dest/modern.plymouth" \
        || ! cmp -s "$theme/modern.script" "$dest/modern.script"; then
        install -m 0644 "$theme/modern.plymouth" "$theme/modern.script" "$dest/"
        plymouth_rebuild=1
    fi
    ln -sfn modern/modern.plymouth "$root/usr/share/plymouth/themes/default.plymouth"
    conf="$root/etc/plymouth/plymouthd.conf"
    if [ -f "$conf" ] && grep -q '^Theme=' "$conf"; then
        sed -i 's/^Theme=.*/Theme=modern/' "$conf"
    elif [ -f "$conf" ] && grep -q '^\[Daemon\]' "$conf"; then
        sed -i '/^\[Daemon\]/a Theme=modern' "$conf"
    else
        printf '[Daemon]\nTheme=modern\n' >"$conf"
    fi
    hooks="$(plymouth_hooks_file "$root")"
    if ! grep -q 'kms plymouth' "$hooks"; then
        plymouth_insert_hook "$hooks"
        plymouth_rebuild=1
    fi
    if [ -f "$root/etc/kernel/cmdline" ]; then
        plymouth_write_options_file "$root/etc/kernel/cmdline" ""
    fi
    entries="$root/boot/loader/entries"
    if [ -d "$entries" ]; then
        for ent in "$entries"/*.conf; do
            [ -f "$ent" ] || continue
            plymouth_write_options_file "$ent" "options"
        done
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    [ "$(id -u)" -eq 0 ] || {
        printf 'plymouth-apply: run as root\n' >&2
        exit 1
    }
    if ! command -v plymouth >/dev/null 2>&1; then
        pacman -S --needed --noconfirm plymouth
    fi
    plymouth_apply /
    if [ "$plymouth_rebuild" -eq 1 ]; then
        mkinitcpio -P
    fi
fi
