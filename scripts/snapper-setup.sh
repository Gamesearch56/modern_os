#!/usr/bin/env bash
# Privileged Snapper root setup. Settings calls this once via pkexec so
# Phylax is not asked twice. When /.snapshots is already the @snapshots
# mount (docs/BACKUP.md), create-config cannot make a nested .snapshots
# — write the config files and leave the mount alone.
set -euo pipefail

NAME=root
SNAPPER=/usr/bin/snapper
CONFIGS_DIR="${MODERN_SNAPPER_CONFIGS_DIR:-/etc/snapper/configs}"
CONF_D="${MODERN_SNAPPER_CONF_D:-/etc/conf.d/snapper}"
TEMPLATE="${MODERN_SNAPPER_TEMPLATE:-/usr/share/snapper/config-templates/default}"
SNAPSHOTS="${MODERN_SNAPPER_SNAPSHOTS:-/.snapshots}"

export LC_ALL=C

if [ "$#" -ne 0 ]; then
    printf 'usage: snapper-setup.sh\n' >&2
    exit 2
fi

has_name() {
    local file="$1"
    [ -f "$file" ] || return 1
    awk -v n="$NAME" '
        $0 ~ /^SNAPPER_CONFIGS=/ {
            line = $0
            sub(/^SNAPPER_CONFIGS="/, "", line)
            sub(/"$/, "", line)
            nsplit = split(line, a, /[[:space:]]+/)
            for (i = 1; i <= nsplit; i++)
                if (a[i] == n)
                    found = 1
        }
        END { exit !found }
    ' "$file"
}

add_name() {
    local file="$1"
    mkdir -p "$(dirname "$file")"
    if [ ! -f "$file" ]; then
        printf 'SNAPPER_CONFIGS="%s"\n' "$NAME" >"$file"
        return
    fi
    if has_name "$file"; then
        return
    fi
    if grep -q '^SNAPPER_CONFIGS=""' "$file"; then
        sed -i "s/^SNAPPER_CONFIGS=\"\"/SNAPPER_CONFIGS=\"${NAME}\"/" "$file"
        return
    fi
    if grep -q '^SNAPPER_CONFIGS="' "$file"; then
        sed -i "s/^SNAPPER_CONFIGS=\"/SNAPPER_CONFIGS=\"${NAME} /" "$file"
        return
    fi
    printf '\nSNAPPER_CONFIGS="%s"\n' "$NAME" >>"$file"
}

write_root_config() {
    if [ ! -f "$TEMPLATE" ]; then
        printf 'snapper template missing\n' >&2
        exit 1
    fi
    mkdir -p "$CONFIGS_DIR"
    umask 022
    sed \
        -e 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="no"/' \
        -e 's/^ALLOW_GROUPS=.*/ALLOW_GROUPS="wheel"/' \
        "$TEMPLATE" >"$CONFIGS_DIR/$NAME"
    chmod 644 "$CONFIGS_DIR/$NAME"
    add_name "$CONF_D"
}

if [ -f "$CONFIGS_DIR/$NAME" ]; then
    sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="no"/' "$CONFIGS_DIR/$NAME"
    add_name "$CONF_D"
    exit 0
fi

if [ -e "$SNAPSHOTS" ]; then
    write_root_config
    exit 0
fi

if [ ! -x "$SNAPPER" ]; then
    printf 'snapper missing\n' >&2
    exit 1
fi

"$SNAPPER" --no-dbus -c "$NAME" create-config /
"$SNAPPER" --no-dbus -c "$NAME" set-config TIMELINE_CREATE=no ALLOW_GROUPS=wheel
