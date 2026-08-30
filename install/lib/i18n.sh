#!/usr/bin/env bash
# Shell-side counterpart to Commons/I18n.qml. Reads the same
# translations/{en,de}.json files so install.sh and scripts/ speak the
# configured language without a second, duplicated string table.
# Source, never execute directly. Requires jq.

TRANSLATIONS_DIR="${TRANSLATIONS_DIR:-$REPO_ROOT/stow/modern/.config/modern/translations}"
I18N_LANG="${I18N_LANG:-${LANG%%_*}}"
[ "$I18N_LANG" = "de" ] || I18N_LANG="en"

# t "cli.usage" -> looks up translations/<lang>.json's nested "cli.usage"
# (dot-path), falling back to English, then to the key itself if neither
# file has it. There is no install.* tree — installer copy is English.
t() {
    local key="$1"; shift || true
    local jq_path=".$(echo "$key" | sed 's/\./\./g')"
    local value
    value="$(jq -r "$jq_path // empty" "$TRANSLATIONS_DIR/$I18N_LANG.json" 2>/dev/null)"
    if [ -z "$value" ] && [ "$I18N_LANG" != "en" ]; then
        value="$(jq -r "$jq_path // empty" "$TRANSLATIONS_DIR/en.json" 2>/dev/null)"
    fi
    [ -n "$value" ] || value="$key"
    if [ "$#" -gt 0 ]; then
        # shellcheck disable=SC2059
        printf "$value\n" "$@"
    else
        printf '%s\n' "$value"
    fi
}
