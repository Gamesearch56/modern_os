#!/usr/bin/env bash
# Log file for a ModernOS app launcher (Texteditor, Imageviewer,
# Mediaplayer). Source, never execute. The window's own qs output goes
# here too, so a QML error in an app reaches the bug report
# (lib/bug-report-collect.sh) instead of /dev/null.

APP_LOG_CAP_BYTES="${APP_LOG_CAP_BYTES:-1048576}"

# app_log_open <log>: make the directory and keep one previous file, so
# a window that warns on every frame cannot fill the disk.
app_log_open() {
    local log="$1"
    mkdir -p "$(dirname "$log")" 2>/dev/null || return 1
    if [ "$(wc -c 2>/dev/null <"$log" || printf 0)" -gt "$APP_LOG_CAP_BYTES" ]; then
        mv -f "$log" "$log.1" 2>/dev/null || true
    fi
    return 0
}
