#!/usr/bin/env bash
# Mark or clear the immutable flag on the installed ~/modern_os clone.
# A development checkout is left writable. May ask for the password
# once; the root run does the flag change and returns.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/repo-path.sh
source "$SCRIPT_DIR/lib/repo-path.sh"
# shellcheck source=lib/repo-protect.sh
source "$SCRIPT_DIR/lib/repo-protect.sh"

usage() { printf 'usage: repo-protect.sh lock|unlock|lock-if-release|release-clone\n' >&2; }

case "${1:-}" in
    lock) repo_protect_lock ;;
    unlock) repo_protect_unlock ;;
    lock-if-release) repo_protect_lock_if_release ;;
    release-clone) repo_protect_is_release >/dev/null ;;
    *) usage; exit 2 ;;
esac
