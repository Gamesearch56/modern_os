#!/usr/bin/env bash
# The wallpaper provider window runs in its own qml6 process. A QML
# error there exits 2 without a message and the shell silently falls
# back to the browser, so load it here and check it stays up.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-wallpaper-provider: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-wallpaper-provider: ok %s\n' "$*"; }

QMLFILE="$ROOT/scripts/wallpaper-provider.qml"
SH="$ROOT/scripts/wallpaper-provider.sh"
WALL="$ROOT/stow/shell/.config/quickshell/modern/Services/Wallpaper.qml"
THEME="$ROOT/stow/shell/.config/quickshell/modern/Commons/ExternalTheme.qml"
QMLDIR="$ROOT/stow/shell/.config/quickshell/modern/Commons/qmldir"

# shellcheck disable=SC2016 # the script's literal argv, not an expansion
if grep -Fq 'ExternalTheme.json()' "$WALL" \
    && grep -Fq 'ExternalTheme.strings(labels)' "$WALL" \
    && grep -Fq 'singleton ExternalTheme 1.0 ExternalTheme.qml' "$QMLDIR" \
    && grep -Fq 'Typography.family.ui' "$THEME" \
    && grep -Fq '"$THEME" "$LABELS"' "$SH"; then
    ok "the shell hands its live tokens and labels to the provider window"
else
    err "Wallpaper.qml must pass ExternalTheme.json()/strings() through wallpaper-provider.sh"
fi

if grep -Fq 'cursorShape: Qt.PointingHandCursor' "$QMLFILE" \
    && grep -Fq 'win.hoverLayer' "$QMLFILE" \
    && grep -Fq 'go-previous-symbolic' "$QMLFILE" \
    && ! grep -Fq 'property color layer:' "$QMLFILE"; then
    ok "header buttons have a hand cursor, a state layer and theme icons"
else
    err "provider header buttons need the hand cursor, state layer and symbolic icons"
fi

QML="$(command -v qml6 || command -v qml || true)"
if [ -z "$QML" ] || [ ! -d /usr/lib/qt6/qml/QtWebEngine ]; then
    ok "load check skipped (no qml6 with QtWebEngine here)"
else
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    rc=0
    QT_QPA_PLATFORM=offscreen timeout 4 "$QML" -f "$QMLFILE" -- about:blank "$tmp" \
        >"$tmp/out" 2>&1 || rc=$?
    # 124 is timeout ending a window that loaded and kept running.
    if [ "$rc" -eq 124 ]; then
        ok "provider window loads in qml6"
    else
        err "wallpaper-provider.qml exited $rc: $(tr '\n' ' ' <"$tmp/out")"
    fi
fi

exit "$FAIL"
