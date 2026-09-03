#!/usr/bin/env bash
# Privileged login-path mutate. Settings writes config.json only; this
# script (via pkexec) is what the next reboot actually reads.
# enable/disable take a validated username; never interpolates caller
# strings into a shell. Root always writes the real paths — env overrides
# are test-only when unprivileged.
set -euo pipefail

usage() {
    printf 'usage: autologin-apply.sh enable|disable USER\n' >&2
    exit 2
}

die() {
    printf 'autologin-apply: %s\n' "$*" >&2
    exit 1
}

valid_user() {
    local name="$1"
    [[ "$name" =~ ^[a-z_][a-z0-9_-]*$ ]] || return 1
    [ "${#name}" -le 32 ] || return 1
    [ "$name" != "greeter" ] && [ "$name" != "root" ] && [ "$name" != "nobody" ]
}

user_ok() {
    local name="$1" ent uid shell
    ent="$(getent passwd "$name" || true)"
    [ -n "$ent" ] || return 1
    uid="$(printf '%s' "$ent" | cut -d: -f3)"
    shell="$(printf '%s' "$ent" | cut -d: -f7)"
    [ "$uid" -ge 1000 ] || return 1
    case "$shell" in
        */nologin|*/false) return 1 ;;
    esac
    return 0
}

[ "$#" -eq 2 ] || usage
cmd="$1"
user="$2"
valid_user "$user" || die "invalid user"

rootful=0
if [ "$(id -u)" -eq 0 ]; then
    rootful=1
fi

if [ "$rootful" -eq 1 ]; then
    user_ok "$user" || die "user is not a login account"
    GREETD_FILE=/etc/greetd/config.toml
    GETTY_FILE=/etc/systemd/system/getty@tty1.service.d/99-modern-autologin.conf
    if systemctl is-enabled greetd.service >/dev/null 2>&1; then
        backend=greetd
    else
        backend=getty
    fi
else
    GREETD_FILE="${MODERN_AUTOLOGIN_GREETD:-}"
    GETTY_FILE="${MODERN_AUTOLOGIN_GETTY:-}"
    backend="${MODERN_AUTOLOGIN_BACKEND:-}"
    [ -n "$backend" ] || die "must run as root"
fi

write_greetd() {
    local dest="$1" with_initial="$2"
    local tmp
    tmp="$(mktemp "${dest}.XXXXXX")"
    {
        printf '%s\n' '[terminal]'
        printf '%s\n' 'vt = 1'
        printf '\n'
        printf '%s\n' '[default_session]'
        printf '%s\n' 'command = "start-hyprland -- --config /etc/greetd/hyprland.lua"'
        printf '%s\n' 'user = "greeter"'
        if [ "$with_initial" = 1 ]; then
            printf '\n'
            printf '%s\n' '[initial_session]'
            printf '%s\n' 'command = "start-hyprland"'
            printf 'user = "%s"\n' "$user"
        fi
    } >"$tmp"
    chmod 0644 "$tmp"
    mv "$tmp" "$dest"
}

write_getty() {
    local dest="$1"
    local dir tmp
    dir="$(dirname "$dest")"
    mkdir -p "$dir"
    tmp="$(mktemp "${dest}.XXXXXX")"
    {
        printf '%s\n' '[Service]'
        printf '%s\n' 'ExecStart='
        printf '%s\n' "ExecStart=-/usr/bin/agetty --skip-login --nonewline --noissue --autologin ${user} --noclear %I \$TERM"
    } >"$tmp"
    chmod 0644 "$tmp"
    mv "$tmp" "$dest"
}

case "$cmd" in
    enable)
        case "$backend" in
            greetd)
                [ -n "$GREETD_FILE" ] || die "greetd path missing"
                if [ "$rootful" -eq 1 ] && [ ! -f /etc/greetd/config.toml ]; then
                    die "greetd is not installed"
                fi
                write_greetd "$GREETD_FILE" 1
                ;;
            getty)
                [ -n "$GETTY_FILE" ] || die "getty path missing"
                write_getty "$GETTY_FILE"
                if [ "$rootful" -eq 1 ]; then
                    systemctl daemon-reload
                fi
                ;;
            *)
                die "unknown backend"
                ;;
        esac
        ;;
    disable)
        case "$backend" in
            greetd)
                [ -n "$GREETD_FILE" ] || die "greetd path missing"
                if [ "$rootful" -eq 1 ] && [ ! -f /etc/greetd/config.toml ]; then
                    die "greetd is not installed"
                fi
                write_greetd "$GREETD_FILE" 0
                ;;
            getty)
                [ -n "$GETTY_FILE" ] || die "getty path missing"
                rm -f "$GETTY_FILE"
                if [ "$rootful" -eq 1 ]; then
                    systemctl daemon-reload
                fi
                ;;
            *)
                die "unknown backend"
                ;;
        esac
        ;;
    *)
        usage
        ;;
esac
