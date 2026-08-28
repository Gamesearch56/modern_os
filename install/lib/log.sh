#!/usr/bin/env bash
# Logging helpers shared by install.sh, bootstrap.sh and scripts/.
# Source, never execute directly. Tees to $LOG_FILE and, when available,
# the systemd journal (logger -t modern-install). Never notify-send —
# that would toast on the daily-driver session if you ran this by mistake.

LOG_FILE="${LOG_FILE:-$REPO_ROOT/install/install.log}"

_ts() { date '+%H:%M:%S'; }

_journal() {
    command -v logger >/dev/null 2>&1 || return 0
    logger -t modern-install -- "$*" || true
}

log_info()  { printf '\033[36m[%s] INFO \033[0m %s\n'  "$(_ts)" "$*" | tee -a "$LOG_FILE"; _journal "INFO  $*"; }
log_ok()    { printf '\033[32m[%s] OK   \033[0m %s\n'  "$(_ts)" "$*" | tee -a "$LOG_FILE"; _journal "OK    $*"; }
log_warn()  { printf '\033[33m[%s] WARN \033[0m %s\n'  "$(_ts)" "$*" | tee -a "$LOG_FILE" >&2; _journal "WARN  $*"; }
log_error() { printf '\033[31m[%s] ERROR\033[0m %s\n'  "$(_ts)" "$*" | tee -a "$LOG_FILE" >&2; _journal "ERROR $*"; }

log_phase() {
    printf '\n\033[1;35m== %s ==\033[0m\n' "$*" | tee -a "$LOG_FILE"
    _journal "PHASE $*"
}

die() {
    log_error "$*"
    exit 1
}
