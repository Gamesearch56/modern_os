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
    for g in video input audio render seat i2c; do
        if [ "$DRY" -eq 1 ] || getent group "$g" >/dev/null 2>&1; then
            list_add "$g"
        fi
    done
}

_usersd_clone_tree() {
    local src="$1" dest="$2"
    if [ -x "$dest/install/install.sh" ]; then
        return 0
    fi
    mkdir -p "$(dirname "$dest")" || return 1
    if [ -d "$src/.git" ]; then
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
            git -c core.hooksPath=/dev/null -c protocol.file.allow=always \
            clone -- "$src" "$dest" || return 1
    else
        mkdir -p "$dest" || return 1
        tar -C "$src" --exclude=iso/out -cf - . \
            | tar -C "$dest" --no-same-owner --no-overwrite-dir -xf - \
            || return 1
    fi
    if [ -d "$dest/.git" ]; then
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
            git -C "$dest" -c core.hooksPath=/dev/null config core.hooksPath /dev/null \
            || true
    fi
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
    runuser -u "$username" -- env HOME="$home" USER="$username" LOGNAME="$username" \
        XDG_CONFIG_HOME="$home/.config" \
        XDG_STATE_HOME="$home/.local/state" \
        XDG_DATA_HOME="$home/.local/share" \
        LANG="$lang" LC_MESSAGES="$lang" \
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
        bash "$dest/install/install.sh" --profile m0 --yes --dotfiles-only --target "$home" \
        || return 1
    if [ -x "${USERS_ROOT:-}/scripts/session-users-sync.sh" ]; then
        bash "$USERS_ROOT/scripts/session-users-sync.sh" || true
    fi
    return 0
}
