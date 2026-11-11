#!/usr/bin/env bash
# Hyprland watches the git file behind the stow symlink. A release
# checkout unlinks that file, the reload runs while it is missing, and
# the error bar stays up. A later clean reload is supposed to fade it
# out; that fade often never finishes, so the bar is still there after
# the update. Pause the watch across the checkout, and dismiss the bar
# once the config has nothing to report.

hypr_config_eval() {
    local lua="$1"
    if [ "${MODERN_TEST_FIXTURE:-}" = "1" ] && [ "${MODERN_TEST_HYPR_WATCH:-}" != "1" ]; then
        return 0
    fi
    command -v hyprctl >/dev/null 2>&1 || return 0
    if [ "${MODERN_TEST_HYPR_WATCH:-}" != "1" ] && [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        return 0
    fi
    hyprctl version >/dev/null 2>&1 || return 0
    hyprctl eval "$lua" >/dev/null 2>&1 || true
}

pause_hypr_config_watch() {
    hypr_config_eval 'hl.config({ misc = { disable_autoreload = true } }); if hl.exec_scheduled_prop_refresh_immediately then hl.exec_scheduled_prop_refresh_immediately() end'
}

resume_hypr_config_watch() {
    hypr_config_eval 'hl.config({ misc = { disable_autoreload = false } }); if hl.exec_scheduled_prop_refresh_immediately then hl.exec_scheduled_prop_refresh_immediately() end'
}

# Drop the error bar a checkout left behind. A config that still has
# errors keeps the bar.
clear_hypr_reload_banner() {
    if [ "${MODERN_TEST_FIXTURE:-}" = "1" ] && [ "${MODERN_TEST_HYPR_WATCH:-}" != "1" ]; then
        return 0
    fi
    command -v hyprctl >/dev/null 2>&1 || return 0
    hyprctl version >/dev/null 2>&1 || return 0
    if hyprctl configerrors 2>/dev/null | grep -q '[^[:space:]]'; then
        return 0
    fi
    hyprctl seterror disable >/dev/null 2>&1 || true
}
