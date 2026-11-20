#!/usr/bin/env bash
# The same OS line Settings → Overview shows. Kitty's fastfetch reads it.
set -euo pipefail

cfg="${XDG_CONFIG_HOME:-$HOME/.config}/modern"
lang="en"
if [ -f "$cfg/config.json" ]; then
    lang="$(jq -r '.language.ui // "en"' "$cfg/config.json" 2>/dev/null || printf 'en')"
fi
case "$lang" in
    de) ;;
    *) lang="en" ;;
esac

repo=""
if [ -f "$cfg/repo" ]; then
    repo="$(head -n 1 "$cfg/repo" | tr -d '\r')"
fi

version=""
base=""
commit=""
if [ -n "$repo" ] && [ -d "$repo/.git" ]; then
    version="$(git -C "$repo" describe --tags --exact-match 2>/dev/null || true)"
    base="$(git -C "$repo" tag -l 'v*' --sort=-v:refname --no-contains HEAD 2>/dev/null | head -1 || true)"
    commit="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || true)"
fi

# Wording matches settings.overview.osName / osNameVersion / osNameDev.
if [ -n "$version" ]; then
    printf 'ModernOS %s (Arch Linux)\n' "$version"
elif [ -n "$base" ] && [ -n "$commit" ]; then
    if [ "$lang" = "de" ]; then
        printf 'ModernOS %s, Entwicklungsstand %s (Arch Linux)\n' "$base" "$commit"
    else
        printf 'ModernOS %s, development build %s (Arch Linux)\n' "$base" "$commit"
    fi
else
    printf 'ModernOS (Arch Linux)\n'
fi
