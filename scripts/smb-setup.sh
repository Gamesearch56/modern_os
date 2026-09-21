#!/usr/bin/env bash
# Privileged Samba media share. Writes smb.conf (guest LAN share, SMB2+,
# NetBIOS ARCHNAS, share Filme) so existing clients keep the same UNC.
# Username comes from pkexec; path is an allowlisted absolute directory.
set -euo pipefail

CONF="${MODERN_SMB_CONF:-/etc/samba/smb.conf}"
DROPIN="${MODERN_WSDD_DROPIN:-/etc/systemd/system/wsdd.service.d/modern.conf}"
SYSTEMCTL="${MODERN_SMB_SYSTEMCTL:-/usr/bin/systemctl}"
NAME=ARCHNAS
SHARE=Filme
export LC_ALL=C

usage() {
    printf 'usage: smb-setup.sh [PATH]\n' >&2
    exit 2
}

[ "$#" -le 1 ] || usage

ok_user() {
    [[ "$1" =~ ^[a-z_][a-z0-9_-]*$ ]]
}

ok_path() {
    local p="$1"
    [[ "$p" == /* ]] || return 1
    [[ "$p" != *..* ]] || return 1
    [[ "$p" =~ ^/[A-Za-z0-9._/-]+$ ]] || return 1
    [ "${MODERN_SMB_ALLOW_MISSING:-0}" = "1" ] || [ -d "$p" ]
}

conf_path() {
    local f="$1"
    [ -f "$f" ] || return 0
    awk '
        BEGIN { s = 0 }
        /^\[Filme\]/ { s = 1; next }
        /^\[/ { if (s) exit; s = ($0 != "[global]") }
        s && $1 ~ /^path$/ {
            sub(/^[^=]*=[ \t]*/, "")
            print
            exit
        }
    ' "$f"
}

resolve_user() {
    local uid user
    if [ -n "${MODERN_SMB_USER:-}" ]; then
        printf '%s\n' "$MODERN_SMB_USER"
        return
    fi
    uid="${PKEXEC_UID:-${SUDO_UID:-}}"
    if [ -n "$uid" ]; then
        user="$(getent passwd "$uid" | cut -d: -f1 || true)"
        if [ -n "$user" ]; then
            printf '%s\n' "$user"
            return
        fi
    fi
    id -un
}

path="${1:-}"
if [ -z "$path" ]; then
    path="$(conf_path "$CONF")"
fi
ok_path "$path" || {
    printf 'smb-setup: need an existing folder path\n' >&2
    exit 1
}

user="$(resolve_user)"
ok_user "$user" || {
    printf 'smb-setup: invalid user\n' >&2
    exit 1
}

umask 022
mkdir -p "$(dirname "$CONF")"
cat >"$CONF" <<EOF
[global]
   workgroup = WORKGROUP
   server string = Media Server
   netbios name = ${NAME}
   security = user
   map to guest = Bad User
   guest account = ${user}
   server min protocol = SMB2
   server max protocol = SMB3
   server signing = disabled
   smb encrypt = off
   local master = yes
   preferred master = yes
   load printers = no
   printcap name = /dev/null
   disable spoolss = yes

[${SHARE}]
   path = ${path}
   guest ok = yes
   read only = no
   browsable = yes
   force user = ${user}
EOF
chmod 644 "$CONF"

mkdir -p "$(dirname "$DROPIN")"
cat >"$DROPIN" <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/wsdd --shortinterface --hostname ${NAME} --workgroup WORKGROUP
EOF
chmod 644 "$DROPIN"

if [ -x "$SYSTEMCTL" ] && "$SYSTEMCTL" is-active --quiet smb 2>/dev/null; then
    "$SYSTEMCTL" daemon-reload >/dev/null 2>&1 || true
    "$SYSTEMCTL" reload-or-restart smb >/dev/null 2>&1 || true
    "$SYSTEMCTL" try-restart nmb >/dev/null 2>&1 || true
    "$SYSTEMCTL" try-restart wsdd >/dev/null 2>&1 || true
fi
