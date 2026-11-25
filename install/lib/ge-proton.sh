#!/usr/bin/env bash
# Private GE-Proton for scripts/battlenet. Not Steam's compatibilitytools.d:
# Steam GPU-probes every tool registered there. Source, never execute.

GE_PROTON_VERSION="${GE_PROTON_VERSION:-11-12}"
GE_PROTON_ID="${GE_PROTON_ID:-GE-Proton${GE_PROTON_VERSION}-x86_64}"
GE_PROTON_URL="${GE_PROTON_URL:-https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${GE_PROTON_VERSION}/${GE_PROTON_ID}.tar.gz}"
# Published sha512 of GE-Proton11-12-x86_64.tar.gz. Override only in tests.
GE_PROTON_SHA512="${GE_PROTON_SHA512:-2e37447902529c9fc39138dc0b3f24aed3513b59a190b825e6b4a668e49e2033bdf6b8a7998e8686e067bbb3f61f3a6633e2408f0cc96f6dad983bd18e2db31e}"

# $1 is the account home. Always under that home's .local/share, not
# $XDG_DATA_HOME, so --target and a later login look at the same tree.
ge_proton_dir() {
    printf '%s/.local/share/modern/proton/%s\n' "$1" "$GE_PROTON_ID"
}

ge_proton_ready() {
    local dest="$1"
    [ -x "$dest/proton" ] && [ -f "$dest/version" ] && grep -Fq "GE-Proton${GE_PROTON_VERSION}" "$dest/version"
}

ge_proton_ensure() {
    local home="$1"
    local dest cache tar stage
    dest="$(ge_proton_dir "$home")"
    if ge_proton_ready "$dest"; then
        log_ok "GE-Proton${GE_PROTON_VERSION} already installed"
        return 0
    fi
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        log_info "would install GE-Proton${GE_PROTON_VERSION} into $dest"
        return 0
    fi
    cache="$home/.cache/modern"
    tar="$cache/${GE_PROTON_ID}.tar.gz"
    mkdir -p "$cache" "$(dirname "$dest")"
    if [ ! -f "$tar" ] || ! (
        cd "$cache" || exit 1
        printf '%s  %s\n' "$GE_PROTON_SHA512" "$(basename "$tar")" | sha512sum -c -
    ) >/dev/null 2>&1; then
        log_info "downloading GE-Proton${GE_PROTON_VERSION}"
        # Live Calamares often has no resolver yet (or no network). Battle.net
        # falls back to Steam's Proton, so a failed fetch must not abort the
        # desktop install. Checksum and extract failures below stay fatal.
        if ! curl -fL --retry 2 --retry-max-time 20 --connect-timeout 10 \
            -o "$tar.part" "$GE_PROTON_URL"; then
            rm -f "$tar.part"
            log_warn "could not download GE-Proton${GE_PROTON_VERSION} from ${GE_PROTON_URL}; continuing without it"
            return 0
        fi
        mv -f "$tar.part" "$tar"
        (
            cd "$cache" || exit 1
            printf '%s  %s\n' "$GE_PROTON_SHA512" "$(basename "$tar")" | sha512sum -c -
        )
    fi
    stage="$(mktemp -d)"
    tar -C "$stage" -xzf "$tar"
    if ! ge_proton_ready "$stage/$GE_PROTON_ID"; then
        rm -rf "$stage"
        log_error "GE-Proton${GE_PROTON_VERSION} archive has no proton runner"
        return 1
    fi
    rm -rf "$dest"
    mv "$stage/$GE_PROTON_ID" "$dest"
    rm -rf "$stage"
    log_ok "installed GE-Proton${GE_PROTON_VERSION} into $dest"
}
