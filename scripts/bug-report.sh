#!/usr/bin/env bash
# Problem reports for this desktop. Services/BugReport drives the
# subcommands step by step; `quick` is the whole flow without the shell
# (Super+# while Quickshell is down). Reports live in
# $XDG_STATE_HOME/modern/reports/<id>/ until sent; one that could not be
# sent carries a `queued` marker and goes out with the next `outbox`.
#
# send exit codes: 0 sent (prints the issue number), 20 queued (offline
# or server unreachable), 21 not set up (no token), 22 token refused.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../install/lib/i18n.sh
source "$REPO_ROOT/install/lib/i18n.sh"
# shellcheck source=lib/bug-report-collect.sh
source "$SCRIPT_DIR/lib/bug-report-collect.sh"

MODERN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/modern"
CFG="$MODERN_DIR/config.json"
DEFAULTS="$REPO_ROOT/stow/modern/.config/modern/config.default.json"
REPORTS="${BUG_REPORT_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/modern/reports}"

if [ -f "$CFG" ]; then
    I18N_LANG="$(jq -r '.language.ui // "en"' "$CFG" 2>/dev/null || printf 'en')"
    [ "$I18N_LANG" = "de" ] || I18N_LANG="en"
fi

die() { printf 'bug-report: %s\n' "$*" >&2; exit 2; }

cfg() {
    local v=""
    [ -f "$CFG" ] && v="$(jq -r "$1 // empty" "$CFG" 2>/dev/null || true)"
    [ -n "$v" ] || v="$(jq -r "$1 // empty" "$DEFAULTS" 2>/dev/null || true)"
    printf '%s' "$v"
}

report_dir() {
    case "$1" in ''|*/*|.*) die "bad report id" ;; esac
    printf '%s/%s' "$REPORTS" "$1"
}

since_of() {
    case "$1" in
        today) printf 'today' ;;
        earlier) printf -- '-2d' ;;
        *) printf -- '-3h' ;;
    esac
}

cmd_new() {
    local id
    id="$(date +%Y%m%d-%H%M%S)-$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n')"
    mkdir -p "$REPORTS/$id/shots" "$REPORTS/$id/files"
    printf '%s\n' "$id"
}

# One JPEG per monitor; names come from Hyprland at capture time.
cmd_capture() {
    local dir name out stamp
    dir="$(report_dir "$1")/shots"
    stamp="$(date +%H%M%S)"
    mkdir -p "$dir"
    rm -f "$dir"/*.jpg
    # The capture time is in the name so a retake never shows a cached image.
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        out="$dir/${name//[^A-Za-z0-9._-]/_}-$stamp.jpg"
        if ! grim -o "$name" -t jpeg -q 80 "$out" 2>/dev/null; then
            rm -f "$out"
            printf 'bug-report: no screenshot of %s\n' "$name" >&2
        fi
    done < <(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)
    list_json "$dir"
}

list_json() {
    local f
    for f in "$1"/*; do
        [ -f "$f" ] || continue
        jq -cn --arg name "$(basename "$f")" --arg path "$f" --argjson size "$(wc -c <"$f")" \
            '{name: $name, path: $path, size: $size}'
    done | jq -cs .
}

cmd_collect() {
    local dir
    dir="$(report_dir "$1")"
    bug_report_collect "$dir/files" "$REPO_ROOT" "$(since_of "${2:-now}")"
    python3 "$SCRIPT_DIR/lib/report-redact.py" "$dir/files"
    list_json "$dir/files"
}

cmd_send() {
    local id="$1" dir rc=0 out
    dir="$(report_dir "$id")"
    [ -d "$dir" ] || die "no such report"
    if [ -n "${2:-}" ]; then
        printf '%s\n' "$2" | jq . >"$dir/request.json.tmp" && mv "$dir/request.json.tmp" "$dir/request.json"
    fi
    [ -f "$dir/request.json" ] || die "report has no request"
    out="$(python3 "$SCRIPT_DIR/lib/report-send.py" "$dir" "$(cfg .bugReport.repo)")" || rc=$?
    case "$rc" in
        0) rm -f "$dir/queued"; printf '%s\n' "$out" ;;
        20) touch "$dir/queued" ;;
    esac
    return "$rc"
}

cmd_export() {
    local dir dest
    dir="$(report_dir "$1")"
    dest="$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"
    [ -n "$dest" ] && [ "$dest" != "$HOME" ] || dest="$HOME/Downloads"
    mkdir -p "$dest"
    dest="$dest/modernos-report-$1.tar.xz"
    tar -cJf "$dest" -C "$dir" --exclude=queued --exclude=sent.json .
    printf '%s\n' "$dest"
}

cmd_outbox() {
    local q id rc
    for q in "$REPORTS"/*/queued; do
        [ -f "$q" ] || continue
        id="$(basename "$(dirname "$q")")"
        rc=0
        cmd_send "$id" >/dev/null || rc=$?
        if [ "$rc" -eq 0 ]; then
            printf 'sent %s %s\n' "$id" "$(jq -r '.number' "$REPORTS/$id/sent.json" 2>/dev/null || true)"
        elif [ "$rc" -ne 20 ]; then
            printf 'bug-report: outbox stopped at %s (send exit %s)\n' "$id" "$rc" >&2
            break
        fi
    done
    cmd_prune
}

# Sent reports stay a month for a resend; drafts that never got a
# request are abandoned windows.
cmd_prune() {
    [ -d "$REPORTS" ] || return 0
    find "$REPORTS" -mindepth 2 -maxdepth 2 -name sent.json -mtime +30 -printf '%h\0' 2>/dev/null | xargs -0r rm -rf
    find "$REPORTS" -mindepth 1 -maxdepth 1 -type d -mtime +2 2>/dev/null | while IFS= read -r d; do
        [ -f "$d/request.json" ] || rm -rf "$d"
    done
}

cmd_status() {
    local secrets="$MODERN_DIR/secrets.json" ready=false n=0 q
    if [ -f "$secrets" ] && jq -e '(.bugReport.githubToken // "") | length > 0' "$secrets" >/dev/null 2>&1; then
        ready=true
    elif [ "${MODERN_REPORT_GH:-}" = 1 ] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        ready=true
    fi
    for q in "$REPORTS"/*/queued; do [ -f "$q" ] && n=$((n + 1)); done
    jq -cn --argjson ready "$ready" --argjson queued "$n" '{ready: $ready, queued: $queued}'
}

notify() {
    notify-send --app-name="ModernOS" --icon=dialog-warning "$(t bugReport.title)" "$1" 2>/dev/null || true
    printf 'bug-report: %s\n' "$1" >&2
}

# The shell is down: capture, collect and send with no questions asked.
cmd_quick() {
    local id rc=0 req
    id="$(cmd_new)"
    cmd_capture "$id" >/dev/null
    cmd_collect "$id" now >/dev/null
    req="$(jq -cn --arg title "$(t bugReport.quickTitle)" --arg cat "${1:-other}" \
        --argjson files "$(list_json "$REPORTS/$id/files" | jq -c '[.[].name]')" \
        --argjson shots "$(list_json "$REPORTS/$id/shots" | jq -c '[.[].name]')" \
        '{title: $title, description: "", categories: [$cat], when: "now", repeat: "", files: $files, shots: $shots}')"
    cmd_send "$id" "$req" >/dev/null || rc=$?
    case "$rc" in
        0) notify "$(t bugReport.sentQuick)" ;;
        20) notify "$(t bugReport.queued)" ;;
        21) notify "$(t bugReport.notSetUp) $(cmd_export "$id")" ;;
        22) notify "$(t bugReport.refused) $(cmd_export "$id")" ;;
        *) notify "$(t bugReport.failed) $(cmd_export "$id")" ;;
    esac
}

case "${1:-}" in
    new) cmd_new ;;
    capture) [ -n "${2:-}" ] || die "usage: capture <id>"; cmd_capture "$2" ;;
    collect) [ -n "${2:-}" ] || die "usage: collect <id> [now|today|earlier]"; cmd_collect "$2" "${3:-now}" ;;
    send) [ -n "${2:-}" ] || die "usage: send <id> [request-json]"; cmd_send "$2" "${3:-}" ;;
    export) [ -n "${2:-}" ] || die "usage: export <id>"; cmd_export "$2" ;;
    outbox) cmd_outbox ;;
    prune) cmd_prune ;;
    status) cmd_status ;;
    quick) cmd_quick "${2:-}" ;;
    *) die "usage: bug-report.sh new|capture|collect|send|export|outbox|prune|status|quick" ;;
esac
