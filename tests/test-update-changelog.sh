#!/usr/bin/env bash
# Changelog URLs for Settings → Update. No browser, no network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/scripts/update-changelog.sh"
FAIL=0
err() { printf 'test-update-changelog: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-update-changelog: ok %s\n' "$*"; }

[ -x "$TOOL" ] || err "update-changelog.sh must be executable"

web="https://github.com/Gamesearch56/modern_os"
got="$("$TOOL" --print desktop ModernOS v0.4.0 v0.5.0)"
if [ "$got" = "${web}/compare/v0.4.0...v0.5.0" ]; then
    ok "desktop compare uses this repo"
else
    err "desktop compare: $got"
fi

got="$("$TOOL" --print desktop ModernOS HEAD v0.5.0)"
if [ "$got" = "${web}/releases" ]; then
    ok "unknown desktop version opens the release list"
else
    err "desktop releases: $got"
fi

got="$("$TOOL" --print pkg hyprland 0.56.2-1 0.57.0-1)"
want="https://gitlab.archlinux.org/archlinux/packaging/packages/hyprland/-/compare/0.56.2-1...0.57.0-1"
if [ "$got" = "$want" ]; then
    ok "package compare uses Arch packaging tags"
else
    err "pkg compare: $got"
fi

if "$TOOL" --print pkg 'hyprland/../evil' 1 2 >/dev/null 2>&1; then
    err "path injection in the package name was accepted"
else
    ok "package name cannot leave the URL path"
fi
if "$TOOL" --print pkg hyprland '1?x=http://evil' 2 >/dev/null 2>&1; then
    err "query injection in the version was accepted"
else
    ok "version cannot add a query string"
fi
if "$TOOL" --print other hyprland 1 2 >/dev/null 2>&1; then
    err "unknown kind was accepted"
else
    ok "kind is desktop or pkg"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-update-changelog: all passed\n'
