#!/usr/bin/env bash
# Keep the boot menu on the kernel whose modules are installed.
#
# The linux-zen package deletes the previous /usr/lib/modules tree as
# soon as it installs the new one. mkinitcpio rebuilds the initramfs
# only when the preset's ALL_kver names a file the package copies the
# new vmlinuz onto (/boot/vmlinuz-linux-zen). A preset without that
# line skips the image, systemd-boot keeps the previous kernel, and
# the machine comes back with no Wi-Fi, touchpad, sound, or zram.
#
# Sourced by install.sh and update-apply.sh. Pacman hooks execute it.
# shellcheck disable=SC2034
set -euo pipefail

kernel_boot_note() {
    if [ -z "${KERNEL_BOOT_HOOK:-}" ] && command -v log_info >/dev/null 2>&1; then
        log_info "kernel-boot: $*"
        return 0
    fi
    printf 'kernel-boot: %s\n' "$*"
}

kernel_boot_fail() {
    if [ -z "${KERNEL_BOOT_HOOK:-}" ] && command -v log_error >/dev/null 2>&1; then
        log_error "kernel-boot: $*"
    else
        printf 'kernel-boot: %s\n' "$*" >&2
    fi
    return 1
}

kernel_boot_self() {
    readlink -f "${BASH_SOURCE[0]}"
}

kernel_boot_root() {
    printf '%s' "${KERNEL_BOOT_ROOT:-}"
}

# Empty when this process is not sitting on the live system (a test
# root) and no KERNEL_BOOT_RUNNING was injected.
kernel_boot_running() {
    if [ -n "${KERNEL_BOOT_RUNNING+x}" ]; then
        [ -n "$KERNEL_BOOT_RUNNING" ] || return 1
        printf '%s\n' "$KERNEL_BOOT_RUNNING"
        return 0
    fi
    [ -z "$(kernel_boot_root)" ] || return 1
    uname -r
}

# Newest installed linux-zen, or nothing.
kernel_boot_kver() {
    local root="$1" d name best=""
    [ -d "$root/usr/lib/modules" ] || return 1
    shopt -s nullglob
    for d in "$root"/usr/lib/modules/*/; do
        [ -f "${d}vmlinuz" ] || continue
        [ -f "${d}pkgbase" ] || continue
        [ "$(tr -d '[:space:]' <"${d}pkgbase")" = linux-zen ] || continue
        name="$(basename "$d")"
        if [ -z "$best" ] || [ "$(printf '%s\n%s\n' "$best" "$name" | sort -V | tail -n 1)" = "$name" ]; then
            best="$name"
        fi
    done
    shopt -u nullglob
    [ -n "$best" ] || return 1
    printf '%s\n' "$best"
}

kernel_boot_write_preset() {
    local dest="$1"
    install -d -m 0755 "$(dirname "$dest")"
    cat >"$dest" <<'EOF'
# ALL_kver is where each kernel upgrade copies the new vmlinuz.
# Without it mkinitcpio skips the image and the previous kernel boots
# after its modules have been removed.
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux-zen"
PRESETS=('default' 'fallback')
default_image="/boot/initramfs-linux-zen.img"
fallback_image="/boot/initramfs-linux-zen-fallback.img"
fallback_options="-S autodetect"
EOF
    chmod 0644 "$dest"
}

# The stock mkinitcpio preset already has this path. strip_live used to
# replace that file and drop the line; repair either shape.
kernel_boot_preset_pin() {
    local root dest
    root="$(kernel_boot_root)"
    dest="$root/etc/mkinitcpio.d/linux-zen.preset"
    if [ ! -f "$dest" ]; then
        kernel_boot_kver "$root" >/dev/null 2>&1 || return 0
        kernel_boot_write_preset "$dest"
        kernel_boot_note "wrote the linux-zen preset"
        return 0
    fi
    if grep -q '^ALL_kver="/boot/vmlinuz-linux-zen"[[:space:]]*$' "$dest"; then
        return 0
    fi
    if grep -q '^ALL_kver=' "$dest"; then
        grep -v '^ALL_kver=' "$dest" >"$dest.new"
        printf 'ALL_kver="/boot/vmlinuz-linux-zen"\n' >>"$dest.new"
        mv "$dest.new" "$dest"
    else
        printf '\nALL_kver="/boot/vmlinuz-linux-zen"\n' >>"$dest"
    fi
    kernel_boot_note "pinned ALL_kver in the linux-zen preset"
}

kernel_boot_install_hooks() {
    local root self hookdir
    root="$(kernel_boot_root)"
    self="$(kernel_boot_self)"
    install -d -m 0755 "$root/usr/lib/modern" "$root/etc/pacman.d/hooks"
    install -m 0755 "$self" "$root/usr/lib/modern/kernel-boot.sh"
    hookdir="$root/etc/pacman.d/hooks"
    cat >"$hookdir/89-modern-kernel-preset.hook" <<'EOF'
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Target = usr/lib/modules/*/vmlinuz

[Action]
Description = Pinning the kernel image path before the initramfs is built...
When = PostTransaction
Exec = /usr/lib/modern/kernel-boot.sh preset
NeedsTargets
EOF
    cat >"$hookdir/95-modern-kernel-boot.hook" <<'EOF'
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Target = usr/lib/modules/*/vmlinuz

[Action]
Description = Booting the kernel whose modules were just installed...
When = PostTransaction
Exec = /usr/lib/modern/kernel-boot.sh boot
NeedsTargets
EOF
    chmod 0644 "$hookdir/89-modern-kernel-preset.hook" "$hookdir/95-modern-kernel-boot.hook"
    install -d -m 0755 "$root/etc/systemd/system"
    cat >"$root/etc/systemd/system/modern-boot-confirm.service" <<'EOF'
[Unit]
Description=Keep the boot menu on the kernel that just reached userspace
ConditionPathExists=/boot/loader/entries/modern.conf
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/lib/modern/kernel-boot.sh confirm

[Install]
WantedBy=multi-user.target
EOF
    chmod 0644 "$root/etc/systemd/system/modern-boot-confirm.service"
    if [ -z "$root" ] && command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl enable modern-boot-confirm.service >/dev/null 2>&1 || true
    fi
}

kernel_boot_prepare() {
    kernel_boot_preset_pin
    kernel_boot_install_hooks
    kernel_boot_shelter
}

kernel_boot_esp_ready() {
    local root
    root="$(kernel_boot_root)"
    if [ -n "$root" ]; then
        [ -d "$root/boot/loader" ] || [ -d "$root/boot/grub" ]
        return
    fi
    if [ -d /boot/loader ] || [ -d /boot/grub ]; then
        return 0
    fi
    findmnt -n -o TARGET /boot 2>/dev/null | grep -qx /boot
}

kernel_boot_field() {
    local key="$1" file="$2" line
    line="$(grep -m1 "^${key}[[:space:]]" "$file" 2>/dev/null || true)"
    printf '%s\n' "${line#"${key}"}" | sed 's/^[[:space:]]*//'
}

# Versioned systemd-boot entries stay on the ESP after the package
# deletes that kernel's modules. Drop those so the menu cannot boot them.
kernel_boot_drop_stale() {
    local root="$1" entries conf base ver linux rel dir running
    running="$(kernel_boot_running 2>/dev/null || true)"
    entries="$root/boot/loader/entries"
    [ -d "$entries" ] || return 0
    shopt -s nullglob
    for conf in "$entries"/*.conf; do
        base="$(basename "$conf")"
        case "$base" in
            modern.conf | modern-fallback.conf | modern-keep.conf) continue ;;
        esac
        ver="$(kernel_boot_field version "$conf")"
        linux="$(kernel_boot_field linux "$conf")"
        if [ -z "$ver" ] && [ -n "$linux" ]; then
            rel="${linux%/*}"
            ver="${rel##*/}"
        fi
        [ -n "$ver" ] || continue
        # The kernel this session booted must stay selectable until a
        # later boot has actually run the one we just installed.
        if [ -n "${running:-}" ] && [ "$ver" = "$running" ]; then
            continue
        fi
        case "$ver" in
            *..* | */*) continue ;;
        esac
        [ -d "$root/usr/lib/modules/$ver" ] && continue
        rm -f -- "$conf"
        case "$linux" in
            /*/*/*) ;;
            *) continue ;;
        esac
        rel="${linux#/}"
        dir="$root/boot/${rel%/linux}"
        case "$dir" in
            "$root/boot"/*/*) ;;
            *) continue ;;
        esac
        case "$dir" in
            */loader | */loader/* | */EFI | */EFI/* | */grub | */grub/* | */modern-keep | */modern-keep/*) continue ;;
        esac
        [ -d "$dir" ] && rm -rf -- "$dir"
    done
    shopt -u nullglob
}

# The current default's command line, including modern.conf. Skipping
# that file made the second kernel update rewrite the menu as `quiet`
# and drop the root device.
kernel_boot_cmdline() {
    local entries="$1" loader conf line def
    loader="$(dirname "$entries")/loader.conf"
    if [ -f "$loader" ]; then
        def="$(kernel_boot_field default "$loader")"
        def="${def%% *}"
        if [ -n "$def" ] && [ -f "$entries/$def" ]; then
            line="$(kernel_boot_field options "$entries/$def")"
            if [ -n "$line" ]; then
                printf '%s\n' "$line"
                return 0
            fi
        fi
    fi
    shopt -s nullglob
    for conf in "$entries"/*.conf; do
        case "$(basename "$conf")" in
            modern-keep.conf) continue ;;
        esac
        line="$(kernel_boot_field options "$conf")"
        if [ -n "$line" ]; then
            printf '%s\n' "$line"
            shopt -u nullglob
            return 0
        fi
    done
    shopt -u nullglob
    printf 'quiet\n'
}

kernel_boot_write_entry() {
    local root="$1" boot entries options ucode
    boot="$root/boot"
    entries="$boot/loader/entries"
    [ -f "$boot/vmlinuz-linux-zen" ] || return 1
    [ -f "$boot/initramfs-linux-zen.img" ] || return 1
    install -d -m 0755 "$entries" "$boot/loader"
    options="$(kernel_boot_cmdline "$entries")"
    {
        printf '%s\n' "title   ModernOS" "linux   /vmlinuz-linux-zen"
        for ucode in intel-ucode.img amd-ucode.img; do
            if [ -f "$boot/$ucode" ]; then
                printf 'initrd  /%s\n' "$ucode"
            fi
        done
        printf '%s\n' "initrd  /initramfs-linux-zen.img" "options $options"
    } >"$entries/modern.conf"
    if [ -f "$boot/initramfs-linux-zen-fallback.img" ]; then
        {
            printf '%s\n' "title   ModernOS (fallback)" "linux   /vmlinuz-linux-zen"
            for ucode in intel-ucode.img amd-ucode.img; do
                if [ -f "$boot/$ucode" ]; then
                    printf 'initrd  /%s\n' "$ucode"
                fi
            done
            printf '%s\n' "initrd  /initramfs-linux-zen-fallback.img" "options $options"
        } >"$entries/modern-fallback.conf"
    fi
    kernel_boot_arm "$root"
    kernel_boot_drop_stale "$root"
    kernel_boot_note "boot menu loads /vmlinuz-linux-zen"
}

# Try the new kernel once. Until that boot reaches userspace, the
# default stays the recovery kernel, so a kernel that cannot mount
# the disk does not become the only way in.
kernel_boot_set_default() {
    local boot="$1" entry="$2" conf
    conf="$boot/loader/loader.conf"
    if [ -f "$conf" ] && grep -q '^default[[:space:]]' "$conf"; then
        sed "s/^default[[:space:]].*/default ${entry}/" "$conf" >"$conf.new"
        mv "$conf.new" "$conf"
    else
        printf 'default %s\n' "$entry" >>"$conf"
    fi
}

kernel_boot_oneshot() {
    local root="$1" entry="$2" bin
    bin="${KERNEL_BOOT_BOOTCTL:-}"
    if [ -z "$bin" ]; then
        [ -z "$root" ] || return 1
        bin=bootctl
    fi
    command -v "$bin" >/dev/null 2>&1 || return 1
    "$bin" set-oneshot "$entry"
}

kernel_boot_arm() {
    local root="$1" boot
    boot="$root/boot"
    if [ -f "$boot/loader/entries/modern-keep.conf" ] && kernel_boot_oneshot "$root" modern.conf; then
        kernel_boot_set_default "$boot" modern-keep.conf
        kernel_boot_note "next boot tries the new kernel once"
        return 0
    fi
    kernel_boot_set_default "$boot" modern.conf
}

# Promotes the new kernel to the default after it has actually booted.
kernel_boot_confirm() {
    local root run kver
    root="$(kernel_boot_root)"
    run="$(kernel_boot_running 2>/dev/null || true)"
    [ -n "$run" ] || return 0
    kver="$(kernel_boot_kver "$root" 2>/dev/null || true)"
    [ -n "$kver" ] && [ "$run" = "$kver" ] || return 0
    [ -f "$root/boot/loader/entries/modern.conf" ] || return 0
    [ -f "$root/boot/loader/loader.conf" ] || return 0
    kernel_boot_set_default "$root/boot" modern.conf
    kernel_boot_note "boot menu keeps /vmlinuz-linux-zen"
}

kernel_boot_restore() {
    local dest="$1"
    if [ -f "$dest.bak" ]; then
        mv "$dest.bak" "$dest"
    else
        rm -f -- "$dest"
    fi
}

# Copy the installed vmlinuz over the boot menu's kernel and rebuild
# both images for that file, not for `uname -r`.
kernel_boot_reconcile() {
    local root kver src dest boot bin
    root="$(kernel_boot_root)"
    if ! kver="$(kernel_boot_kver "$root")"; then
        kernel_boot_note "no linux-zen module tree; nothing to boot"
        return 0
    fi
    if ! kernel_boot_esp_ready; then
        kernel_boot_note "/boot is not the boot partition; left the boot menu alone"
        return 0
    fi
    src="$root/usr/lib/modules/$kver/vmlinuz"
    boot="$root/boot"
    dest="$boot/vmlinuz-linux-zen"
    install -d -m 0755 "$boot"
    if [ ! -f "$dest" ] || ! cmp -s "$src" "$dest" \
        || [ ! -f "$boot/initramfs-linux-zen.img" ] \
        || [ ! -f "$boot/initramfs-linux-zen-fallback.img" ]; then
        [ -f "$dest" ] && cp -a "$dest" "$dest.bak"
        [ -f "$boot/initramfs-linux-zen.img" ] && cp -a "$boot/initramfs-linux-zen.img" "$boot/initramfs-linux-zen.img.bak"
        [ -f "$boot/initramfs-linux-zen-fallback.img" ] && cp -a "$boot/initramfs-linux-zen-fallback.img" "$boot/initramfs-linux-zen-fallback.img.bak"
        install -m 0644 "$src" "$dest"
        bin="${KERNEL_BOOT_MKINITCPIO:-mkinitcpio}"
        if ! "$bin" -k "$dest" -g "$boot/initramfs-linux-zen.img" \
            || ! "$bin" -k "$dest" -S autodetect -g "$boot/initramfs-linux-zen-fallback.img"; then
            kernel_boot_restore "$dest"
            kernel_boot_restore "$boot/initramfs-linux-zen.img"
            kernel_boot_restore "$boot/initramfs-linux-zen-fallback.img"
            kernel_boot_fail "initramfs for $kver was not built; the previous boot files were put back"
            return 1
        fi
        rm -f -- "$dest.bak" "$boot/initramfs-linux-zen.img.bak" "$boot/initramfs-linux-zen-fallback.img.bak"
        kernel_boot_note "built the initramfs for $kver"
    fi
    # GRUB reads the stable filenames itself. systemd-boot needs an
    # entry, and it must be the default or the old versioned one wins.
    if [ -d "$boot/loader" ] || { [ -z "$root" ] && [ -d /sys/firmware/efi ]; }; then
        kernel_boot_write_entry "$root"
    fi
}

kernel_boot_copy() {
    local src="$1" dest="$2"
    [ -f "$src" ] || return 1
    install -d -m 0755 "$(dirname "$dest")"
    cp -a "$src" "$dest.new"
    mv -f "$dest.new" "$dest"
}

kernel_boot_last_initrd() {
    local file="$1" line rel=""
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            initrd[[:space:]]*)
                rel="${line#initrd}"
                rel="$(printf '%s\n' "$rel" | sed 's/^[[:space:]]*//')"
                ;;
        esac
    done <"$file"
    printf '%s\n' "$rel"
}

# The image this session booted, plus the initramfs that mounted root.
kernel_boot_booted_files() {
    local root="$1" run="$2" boot entries conf ver linux rel initrd
    boot="$root/boot"
    if [ -f "$boot/vmlinuz-linux-zen" ] \
        && [ -f "$root/usr/lib/modules/$run/vmlinuz" ] \
        && cmp -s "$root/usr/lib/modules/$run/vmlinuz" "$boot/vmlinuz-linux-zen" \
        && [ -f "$boot/initramfs-linux-zen.img" ]; then
        printf '%s\n%s\n' "$boot/vmlinuz-linux-zen" "$boot/initramfs-linux-zen.img"
        return 0
    fi
    entries="$boot/loader/entries"
    [ -d "$entries" ] || return 1
    shopt -s nullglob
    for conf in "$entries"/*.conf; do
        case "$(basename "$conf")" in
            modern-keep.conf) continue ;;
        esac
        ver="$(kernel_boot_field version "$conf")"
        [ "$ver" = "$run" ] || continue
        linux="$(kernel_boot_field linux "$conf")"
        [ -n "$linux" ] || continue
        rel="${linux#/}"
        [ -f "$boot/$rel" ] || continue
        initrd="$(kernel_boot_last_initrd "$conf")"
        initrd="${initrd#/}"
        [ -n "$initrd" ] && [ -f "$boot/$initrd" ] || continue
        printf '%s\n%s\n' "$boot/$rel" "$boot/$initrd"
        shopt -u nullglob
        return 0
    done
    shopt -u nullglob
    return 1
}

kernel_boot_healthy() {
    local root run
    root="$(kernel_boot_root)"
    run="$(kernel_boot_running 2>/dev/null || true)"
    [ -n "$run" ] || return 1
    [ -f "$root/usr/lib/modules/$run/vmlinuz" ]
}

kernel_boot_write_keep() {
    local root="$1" boot entries options ucode
    boot="$root/boot"
    entries="$boot/loader/entries"
    [ -f "$boot/modern-keep/vmlinuz" ] || return 0
    [ -f "$boot/modern-keep/initramfs.img" ] || return 0
    install -d -m 0755 "$entries" "$boot/loader"
    options="$(kernel_boot_cmdline "$entries")"
    {
        printf '%s\n' "title   ModernOS (recovery)" "linux   /modern-keep/vmlinuz"
        for ucode in intel-ucode.img amd-ucode.img; do
            if [ -f "$boot/$ucode" ]; then
                printf 'initrd  /%s\n' "$ucode"
            fi
        done
        printf '%s\n' "initrd  /modern-keep/initramfs.img" "options $options"
    } >"$entries/modern-keep.conf"
}

# Copy the kernel that is running now to a path mkinitcpio's remove
# hook does not know. A cut-off upgrade deletes the preset's images
# before it writes the new ones; this copy is what still boots.
kernel_boot_shelter() {
    local root run boot pair kimg initrd
    root="$(kernel_boot_root)"
    if ! kernel_boot_esp_ready; then
        return 0
    fi
    if ! kernel_boot_healthy; then
        kernel_boot_note "this boot has no modules; leaving the recovery kernel in place"
        return 0
    fi
    run="$(kernel_boot_running)"
    boot="$root/boot"
    pair="$(kernel_boot_booted_files "$root" "$run" 2>/dev/null || true)"
    kimg="$(printf '%s\n' "$pair" | sed -n '1p')"
    initrd="$(printf '%s\n' "$pair" | sed -n '2p')"
    [ -n "$kimg" ] && [ -f "$kimg" ] && [ -n "$initrd" ] && [ -f "$initrd" ] || return 0
    if [ ! -f "$boot/modern-keep/vmlinuz" ] || [ ! -f "$boot/modern-keep/initramfs.img" ] \
        || ! cmp -s "$kimg" "$boot/modern-keep/vmlinuz" \
        || ! cmp -s "$initrd" "$boot/modern-keep/initramfs.img"; then
        kernel_boot_copy "$kimg" "$boot/modern-keep/vmlinuz"
        kernel_boot_copy "$initrd" "$boot/modern-keep/initramfs.img"
        kernel_boot_note "recovery kernel is the one running now ($run)"
    fi
    if [ -d "$boot/loader" ] || { [ -z "$root" ] && [ -d /sys/firmware/efi ]; }; then
        kernel_boot_write_keep "$root"
    fi
}

# True when the next boot would not load the installed linux-zen, or
# the previous update was cut off. /boot is often unreadable here, so
# a permission error is not treated as a broken menu.
kernel_boot_needs_repair() {
    local root run preset kver dest def ver
    root="$(kernel_boot_root)"
    if [ -s "$root/var/lib/modern/update-snapshot" ]; then
        return 0
    fi
    run="$(kernel_boot_running 2>/dev/null || true)"
    if [ -n "$run" ] && [ ! -e "$root/usr/lib/modules/$run" ]; then
        return 0
    fi
    preset="$root/etc/mkinitcpio.d/linux-zen.preset"
    if [ -f "$preset" ] && [ -r "$preset" ] \
        && ! grep -q '^ALL_kver="/boot/vmlinuz-linux-zen"[[:space:]]*$' "$preset"; then
        return 0
    fi
    if ! kver="$(kernel_boot_kver "$root" 2>/dev/null)"; then
        return 1
    fi
    dest="$root/boot/vmlinuz-linux-zen"
    if [ -r "$dest" ] && [ -r "$root/usr/lib/modules/$kver/vmlinuz" ] \
        && ! cmp -s "$root/usr/lib/modules/$kver/vmlinuz" "$dest"; then
        return 0
    fi
    if [ -r "$dest" ] && [ ! -f "$root/boot/initramfs-linux-zen.img" ]; then
        return 0
    fi
    if [ -r "$root/boot/loader/loader.conf" ]; then
        def="$(kernel_boot_field default "$root/boot/loader/loader.conf")"
        def="${def%% *}"
        case "$def" in
            "" | modern.conf | modern-fallback.conf) ;;
            *)
                if [ -r "$root/boot/loader/entries/$def" ]; then
                    ver="$(kernel_boot_field version "$root/boot/loader/entries/$def")"
                    if [ -n "$ver" ] && [ ! -d "$root/usr/lib/modules/$ver" ]; then
                        return 0
                    fi
                fi
                ;;
        esac
    fi
    return 1
}

kernel_boot_apply() {
    if [ "${DRY_RUN:-0}" = 1 ]; then
        kernel_boot_note "would pin the preset and boot the installed kernel"
        return 0
    fi
    if [ -z "${KERNEL_BOOT_ROOT:-}" ] && [ "$(id -u)" -ne 0 ]; then
        sudo /usr/bin/bash "$(kernel_boot_self)" apply
        return
    fi
    kernel_boot_prepare
    kernel_boot_reconcile
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    cmd="${1:-}"
    case "$cmd" in
        preset | boot)
            # NeedsTargets feeds the hook the package paths. Drain them
            # so a long list cannot fill the pipe and stall pacman.
            cat >/dev/null || true
            KERNEL_BOOT_HOOK=1
            export KERNEL_BOOT_HOOK
            if [ "$cmd" = preset ]; then
                kernel_boot_prepare
            else
                kernel_boot_reconcile
            fi
            ;;
        apply)
            kernel_boot_apply
            ;;
        confirm)
            kernel_boot_confirm
            ;;
        *)
            printf 'usage: kernel-boot.sh preset|boot|apply|confirm\n' >&2
            exit 2
            ;;
    esac
fi
