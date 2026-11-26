#!/usr/bin/env bash
# Bake greeter chrome.json from language.ui + translations. Wallpaper
# pixels stay in wallpaper-sync.sh; this runs when Settings → Language
# changes without a wallpaper pick.
set -euo pipefail

SHARED="${MODERN_SESSION_DIR:-/var/lib/modern/session}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
TRANSLATIONS="${XDG_CONFIG_HOME:-$HOME/.config}/modern/translations"
[ -d "$SHARED" ] || exit 0
[ -f "$CFG" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

lang="$(jq -r '.language.ui // "en"' "$CFG")"
lang="${lang//[!a-z]/}"
trans="$TRANSLATIONS/$lang.json"
[ -f "$trans" ] || trans="$TRANSLATIONS/en.json"
[ -f "$trans" ] || exit 0

chrome_tmp="$(mktemp --suffix=.json -p "$SHARED" tmp.XXXXXX)"
if jq -n \
    --argjson cfg "$(jq '{
        typography,
        design: {cornerRounding, transparency},
        language,
        motion: {
            scale: (.motion.scale // 1),
            overlay: (.motion.overlay // "fadeZoom"),
            extraLong: 600
        }
    }' "$CFG")" \
    --argjson strings "$(jq '{
        unlock: (.session.unlock // "Unlock"),
        password: (.session.password // "Password"),
        user: (.session.user // "User"),
        signingIn: (.session.signingIn // "Signing in…"),
        authFailed: (.session.authFailed // "Could not unlock"),
        signIn: (.session.signIn // "Sign in"),
        welcome: (.session.welcome // "Welcome"),
        loginFailed: (.session.loginFailed // "Could not sign in"),
        unavailable: (.session.unavailable // "Sign-in is not available"),
        capsLock: (.session.capsLock // "Caps Lock is on"),
        admin: (.session.admin // "Admin"),
        restart: (.powerMenu.restart // "Restart"),
        poweroff: (.powerMenu.poweroff // "Shut down"),
        power: (.powerMenu.title // "Power"),
        weekday: (.time.weekday // {})
    }' "$trans")" \
    '$cfg + {strings: $strings}' \
    > "$chrome_tmp"
then
    chmod a+r "$chrome_tmp" || true
    mv -f "$chrome_tmp" "$SHARED/chrome.json"
else
    rm -f "$chrome_tmp"
    exit 1
fi
