#!/usr/bin/env bash
# Logging helpers shared by install.sh, bootstrap.sh and scripts/.
# Source, never execute directly.

LOG_FILE="${LOG_FILE:-$REPO_ROOT/install/install.log}"

_ts() { date '+%H:%M:%S'; }

log_info()  { printf '\033[36m[%s] INFO \033[0m %s\n'  "$(_ts)" "$*" | tee -a "$LOG_FILE"; }
log_ok()    { printf '\033[32m[%s] OK   \033[0m %s\n'  "$(_ts)" "$*" | tee -a "$LOG_FILE"; }
log_warn()  { printf '\033[33m[%s] WARN \033[0m %s\n'  "$(_ts)" "$*" | tee -a "$LOG_FILE" >&2; }
log_error() { printf '\033[31m[%s] ERROR\033[0m %s\n'  "$(_ts)" "$*" | tee -a "$LOG_FILE" >&2; }

log_phase() {
    printf '\n\033[1;35m== %s ==\033[0m\n' "$*" | tee -a "$LOG_FILE"
}

die() {
    log_error "$*"
    exit 1
}
