# shellcheck shell=bash
# Services and groups for the `full` profile's 70-workstation layer.
# Only socket-activated, local services: Samba and wsdd stay off until
# smb.conf has shares, since they open the machine to the network.
# Source, never execute directly.

WORKSTATION_UNITS=(docker.socket libvirtd.socket)
WORKSTATION_GROUPS=(docker libvirt)

workstation_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo -- "$@"
    fi
}

# Enables each unit that is installed and adds the user to each group
# that exists. A missing package skips its unit; it does not fail the
# install.
workstation_apply() {
    local user="$1" unit group failed=0
    [ -n "$user" ] || return 1
    for unit in "${WORKSTATION_UNITS[@]}"; do
        systemctl cat "$unit" >/dev/null 2>&1 || continue
        workstation_as_root systemctl enable --now "$unit" >/dev/null 2>&1 || failed=1
    done
    for group in "${WORKSTATION_GROUPS[@]}"; do
        getent group "$group" >/dev/null 2>&1 || continue
        id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx "$group" && continue
        workstation_as_root usermod -aG "$group" "$user" || failed=1
    done
    return "$failed"
}
