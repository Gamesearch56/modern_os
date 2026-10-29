# Stow this desktop into a newly created home. Sourced by usersd.sh
# (create already ran as root). Packages and greetd stay on the machine.
# shellcheck shell=bash
# username, DRY, run, list_add, invoker_names come from usersd.sh.
# shellcheck disable=SC2154

_usersd_canon() {
    readlink -f -- "$1" 2>/dev/null || true
}

_usersd_repo_ok() {
    local p inv home hp root
    p="$(_usersd_canon "$1")"
    [ -n "$p" ] && [ -x "$p/install/install.sh" ] || return 1
    root="$(_usersd_canon "${USERS_ROOT:-}")"
    [ -n "$root" ] && [ "$p" = "$root" ] && return 0
    while IFS= read -r inv; do
        [ -n "$inv" ] || continue
        home="$(getent passwd -- "$inv" 2>/dev/null | cut -d: -f6)"
        hp="$(_usersd_canon "$home")"
        [ -n "$hp" ] || continue
        case "$p" in
            "$hp"|"$hp"/*) return 0 ;;
        esac
    done < <(invoker_names)
    return 1
}

_usersd_invoker_repo() {
    local inv home f p
    while IFS= read -r inv; do
        [ -n "$inv" ] || continue
        home="$(getent passwd -- "$inv" 2>/dev/null | cut -d: -f6)"
        [ -n "$home" ] || continue
        f="$home/.config/modern/repo"
        if [ -f "$f" ] && [ ! -L "$f" ]; then
            p="$(tr -d '\n' <"$f")"
            if _usersd_repo_ok "$p"; then
                _usersd_canon "$p"
                return 0
            fi
        fi
        if _usersd_repo_ok "$home/modern_dotfile"; then
            _usersd_canon "$home/modern_dotfile"
            return 0
        fi
    done < <(invoker_names)
    if _usersd_repo_ok "${USERS_ROOT:-}"; then
        _usersd_canon "$USERS_ROOT"
        return 0
    fi
    return 1
}

_usersd_session_groups() {
    local g
    for g in video input audio render seat i2c modern; do
        if [ "$DRY" -eq 1 ] || getent group "$g" >/dev/null 2>&1; then
            list_add "$g"
        fi
    done
}

_usersd_clone_tree() {
    local src="$1" dest="$2"
    case "$dest" in
        */modern_dotfile) ;;
        *) return 1 ;;
    esac
    local d
    mkdir -p "$(dirname "$dest")" || return 1
    rm -rf "$dest"
    mkdir -p "$dest" || return 1
    # Live stow/install/scripts only — not `git clone` of HEAD (that
    # skipped uncommitted install.sh and reused a stale dest, then
    # Settings waited on sudo pacman) and not iso/out.
    for d in stow install scripts; do
        [ -d "$src/$d" ] || return 1
        tar -C "$src" --exclude=iso/out --exclude=.git -cf - "$d" \
            | tar -C "$dest" --no-same-owner --no-overwrite-dir -xf - \
            || return 1
    done
    [ -x "$dest/install/install.sh" ] || return 1
}

_usersd_copy_prefs() {
    local dest_home="$1" dest inv home src tmp
    dest="$dest_home/.config/modern/config.json"
    [ -f "$dest" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    while IFS= read -r inv; do
        [ -n "$inv" ] || continue
        [ "$(id -u -- "$inv" 2>/dev/null || true)" != "0" ] || continue
        home="$(getent passwd -- "$inv" 2>/dev/null | cut -d: -f6)"
        src="$home/.config/modern/config.json"
        [ -f "$src" ] && [ ! -L "$src" ] || continue
        tmp="$(mktemp "${dest}.XXXXXX")"
        if jq --slurpfile src "$src" '
            .language.ui = ($src[0].language.ui // .language.ui)
            | .language.fallback = ($src[0].language.fallback // .language.fallback)
            | .language.dateFormat = ($src[0].language.dateFormat // .language.dateFormat)
            | .language.timeFormat = ($src[0].language.timeFormat // .language.timeFormat)
            | .language.firstDayOfWeek = ($src[0].language.firstDayOfWeek // .language.firstDayOfWeek)
            | .input.kbLayout = ($src[0].input.kbLayout // .input.kbLayout)
            | .input.kbVariant = ($src[0].input.kbVariant // .input.kbVariant)
            | .monitors = ($src[0].monitors // .monitors)
            | .design.activeProfile = ($src[0].design.activeProfile // .design.activeProfile)
        ' "$dest" >"$tmp"; then
            mv -f "$tmp" "$dest"
            return 0
        fi
        rm -f "$tmp"
    done < <(invoker_names)
}

_usersd_publish_session() {
    local home="$1" script
    for script in session-chrome-sync.sh session-keyboard-sync.sh session-monitors-sync.sh; do
        [ -x "${USERS_ROOT}/scripts/$script" ] || continue
        HOME="$home" USER="$username" LOGNAME="$username" \
            XDG_CONFIG_HOME="$home/.config" \
            XDG_STATE_HOME="$home/.local/state" \
            bash "${USERS_ROOT}/scripts/$script" || true
    done
}

_usersd_seed_vivaldi() {
    local home="$1"
    local tokens="$home/.config/modern/tokens.json"
    [ -f "$tokens" ] || return 0
    [ -f "${USERS_ROOT}/scripts/lib/vivaldi-prefs.sh" ] || return 0
    # $1 and $2 are the child shell's arguments.
    # shellcheck disable=SC2016
    runuser -u "$username" -- env \
        HOME="$home" USER="$username" LOGNAME="$username" \
        XDG_CONFIG_HOME="$home/.config" \
        bash -c 'source "$1" && merge_vivaldi_prefs "$2"' \
        _ "${USERS_ROOT}/scripts/lib/vivaldi-prefs.sh" "$tokens" \
        || true
}

_usersd_refresh_greeter() {
    local src="${USERS_ROOT}/stow/greeter/.config/quickshell/greeter"
    local dest="/var/lib/greeter/.config/quickshell/greeter"
    [ -d "$src" ] || return 0
    [ -d /var/lib/greeter ] || return 0
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
    chown -R greeter:modern "$dest" 2>/dev/null || true
}

_usersd_seed_keyring() {
    local dest_home="$1" dir
    dir="$dest_home/.local/share/keyrings"
    mkdir -p "$dir" || return 0
    chmod 0700 "$dir" || true
    printf 'login\n' >"$dir/default"
    chmod 0600 "$dir/default" || true
}

_usersd_install_greetd_pam() {
    local src="${USERS_ROOT:-}/install/system/greetd/greetd.pam"
    [ "${DRY:-0}" -eq 1 ] && return 0
    [ -f "$src" ] || return 0
    [ "$(id -u)" -eq 0 ] || return 0
    install -m 0644 "$src" /etc/pam.d/greetd || true
}

_usersd_copy_deploy_key() {
    local dest_home="$1" inv home src dest
    while IFS= read -r inv; do
        [ -n "$inv" ] || continue
        home="$(getent passwd -- "$inv" 2>/dev/null | cut -d: -f6)"
        src="$home/.config/modern/deploy_key"
        [ -f "$src" ] && [ ! -L "$src" ] || continue
        dest="$dest_home/.config/modern/deploy_key"
        install -d -m 0700 "$dest_home/.config/modern"
        install -m 0600 "$src" "$dest"
        return 0
    done < <(invoker_names)
}

provision_new_user_desktop() {
    local home src dest lang grp
    if [ "$DRY" -eq 1 ]; then
        run bash "${USERS_ROOT:-.}/install/install.sh" --profile m0 --yes \
            --dotfiles-only --target "/home/$username"
        return 0
    fi
    home="$(getent passwd -- "$username" | cut -d: -f6)"
    [ -n "$home" ] && [ -d "$home" ] || return 1
    src="$(_usersd_invoker_repo)" || return 1
    dest="$home/modern_dotfile"
    _usersd_clone_tree "$src" "$dest" || return 1
    _usersd_copy_deploy_key "$home" || true
    grp="$(id -gn -- "$username")"
    chown -hR "$username:$grp" "$home"
    lang="$(awk -F= '/^LANG=/{ gsub(/"/, "", $2); print $2; exit }' /etc/locale.conf 2>/dev/null || true)"
    lang="${lang:-C.UTF-8}"
    command -v runuser >/dev/null 2>&1 || return 1
    [ -x "$dest/install/install.sh" ] || return 1
    # env -i: a leaked D-Bus/sudo from the admin pkexec made install.sh
    # wait on pacman. timeout: Settings must not spin forever.
    timeout 120 runuser -u "$username" -- env -i \
        HOME="$home" USER="$username" LOGNAME="$username" \
        PATH="/usr/bin:/bin" \
        XDG_CONFIG_HOME="$home/.config" \
        XDG_STATE_HOME="$home/.local/state" \
        XDG_DATA_HOME="$home/.local/share" \
        LANG="$lang" LC_MESSAGES="$lang" LC_ALL="$lang" \
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
        bash "$dest/install/install.sh" --profile m0 --yes --dotfiles-only --target "$home" \
        || return 1
    _usersd_copy_prefs "$home" || true
    _usersd_publish_session "$home" || true
    _usersd_seed_vivaldi "$home" || true
    _usersd_refresh_greeter || true
    _usersd_seed_keyring "$home" || true
    _usersd_install_greetd_pam || true
    chown -h -- "$username:$grp" "$home/.config/modern/config.json" 2>/dev/null || true
    chown -hR -- "$username:$grp" "$home/.local/share/keyrings" 2>/dev/null || true
    if [ -x "${USERS_ROOT:-}/scripts/session-users-sync.sh" ]; then
        bash "$USERS_ROOT/scripts/session-users-sync.sh" || true
    fi
    return 0
}
