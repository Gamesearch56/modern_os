#!/usr/bin/env bash
# App collector for scripts/bug-report.sh, sourced by bug-report-collect.sh.
# Texteditor, Imageviewer and Mediaplayer each run as their own qs
# process; their launcher and QML output lands in one log per app
# (lib/app-log.sh), which the shell log never sees.

_collect_apps() {
    local state="${XDG_STATE_HOME:-$HOME/.local/state}/modern" app
    for app in editor imageviewer mediaplayer; do
        _copy apps.txt "$state/$app.log.1" 300
        _copy apps.txt "$state/$app.log" 1000
    done
    # Launcher and theme repair. The settings file itself stays out.
    _copy apps.txt "$state/vivaldi.log" 200
    return 0
}
