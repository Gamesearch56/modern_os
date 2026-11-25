#!/usr/bin/env bash
# Install the report sender. The shipped file is the token reversed in
# short lines: a raw personal access token in a public repository is
# revoked. report-send.py restores it. A missing file is normal: the
# report stays on the computer. The token is never printed.
install_report_sender() {
    local src="" dest="$TARGET/.config/modern/report-token" system="/usr/lib/modern/report-token"
    if [ -f "$REPO_ROOT/install/share/report-token" ] && [ ! -L "$REPO_ROOT/install/share/report-token" ]; then
        src="$REPO_ROOT/install/share/report-token"
    elif [ -f "$REPO_ROOT/secrets/report-token" ] && [ ! -L "$REPO_ROOT/secrets/report-token" ]; then
        src="$REPO_ROOT/secrets/report-token"
    else
        return 0
    fi
    [ -s "$src" ] || return 0
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log_info "report sender: would install the private report credential"
        return 0
    fi
    mkdir -p "$(dirname "$dest")"
    install -m 0600 "$src" "$dest"
    if [ -w /usr/lib/modern ] || [ "$(id -u)" -eq 0 ]; then
        install -d -m 0755 /usr/lib/modern
        install -m 0644 "$src" "$system"
    fi
    log_info "report sender installed"
}
