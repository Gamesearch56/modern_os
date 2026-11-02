#!/usr/bin/env bash
# pacman.conf edits the installer needs. Source only.
#
# Options only count under [options]. Appended to the end of the file
# they land in [extra] (or [multilib]); pacman then warns on every run
# and ignores them.

PACMAN_CONF_SANDBOX_NOTE="# Calamares chroot: pacman 7 landlock cannot download here."

# Puts LINE under [options] unless it is already there.
pacman_conf_set() {
    local conf="$1" line="$2" tmp
    awk -v want="$line" '
        /^\[/ { s = $0 }
        s ~ /^\[options\]/ && $0 == want { found = 1 }
        END { exit found ? 0 : 1 }
    ' "$conf" && return 0
    tmp="$(mktemp "$conf.XXXXXX")" || return 1
    awk -v want="$line" '
        { print }
        /^\[options\]/ && !done { print want; done = 1 }
    ' "$conf" >"$tmp" && chmod 0644 "$tmp" && mv -f "$tmp" "$conf"
}

# Installed-system cleanup of what an older installer left behind: moves
# NoExtract/IgnorePkg from a repo section to [options], and drops the
# chroot-only DisableSandbox and the DownloadUser it commented out.
pacman_conf_repair() {
    local conf="$1" tmp
    [ -f "$conf" ] || return 0
    tmp="$(mktemp "$conf.XXXXXX")" || return 1
    awk -v note="$PACMAN_CONF_SANDBOX_NOTE" '
        FNR == NR {
            if ($0 ~ /^\[/) s = $0
            else if (s !~ /^\[options\]/ && $0 ~ /^(NoExtract|IgnorePkg)[ \t]*=/) keep[++n] = $0
            next
        }
        /^\[/ { s = $0 }
        $0 == note { next }
        /^[ \t]*DisableSandbox[ \t]*$/ { next }
        $0 == "#DownloadUser = alpm" { print "DownloadUser = alpm"; next }
        s !~ /^\[options\]/ && /^(NoExtract|IgnorePkg)[ \t]*=/ { next }
        { print }
        /^\[options\]/ && !done { for (i = 1; i <= n; i++) print keep[i]; done = 1 }
    ' "$conf" "$conf" >"$tmp" || { rm -f "$tmp"; return 1; }
    if cmp -s "$tmp" "$conf"; then
        rm -f "$tmp"
        return 0
    fi
    chmod 0644 "$tmp" && mv -f "$tmp" "$conf"
}
