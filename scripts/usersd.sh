#!/usr/bin/env bash
# Privileged local-account helper. Settings pkexecs this. JSON stdin
# {action,...}; names go in argv arrays, never interpolated into a
# shell string. Passwords never appear on argv. See docs/SECURITY.md.
set -euo pipefail

fail() {
    jq -n --arg error "$1" '{ok:false, error:$error}' >&2
    exit 1
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && {
    cat <<'EOF'
Usage: usersd.sh < json
  {"action":"create","username":"x","password":"...","gecos":"","groups":["wheel"]}
  {"action":"delete","username":"x","removeHome":true}
  {"action":"rename","username":"x","newUsername":"y"}
  {"action":"passwd","username":"x","password":"..."}
  {"action":"gecos","username":"x","gecos":"Name"}
  {"action":"groups","username":"x","groups":["wheel","audio"]}
  {"action":"group-create","group":"x"}
  {"action":"group-delete","group":"x"}
  {"action":"group-rename","group":"x","newGroup":"y"}
  {"action":"group-members","group":"x","members":["a","b"]}
  {"action":"update","username":"x","newUsername":"y","gecos":"","password":"","groups":[]}
  {"action":"group-update","group":"x","newGroup":"y","members":["a"]}
EOF
    exit 0
}
if [ $# -ne 0 ]; then
    printf '%s\n' "Usage: usersd.sh < json" >&2
    exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
    echo '{"ok":false,"error":"jq is required"}' >&2
    exit 1
fi

DRY=0
[ "${MODERN_TEST_FIXTURE:-}" = "1" ] && DRY=1
if [ "$DRY" -eq 0 ]; then
    [ "$(id -u)" -eq 0 ] || fail "must run as root (pkexec)"
fi

json="$(cat)"
[ -n "$json" ] || fail "empty stdin"
jq -e . >/dev/null 2>&1 <<<"$json" || fail "stdin is not JSON"

action="$(jq -r '.action // empty' <<<"$json")"
username="$(jq -r '.username // empty' <<<"$json")"
groupname="$(jq -r '.group // empty' <<<"$json")"

valid_name() {
    [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || return 1
    case "$1" in
        root|nobody|greeter|daemon|bin|sys|sync|shutdown|halt|mail|ftp|nologin)
            return 1 ;;
    esac
    return 0
}

ok() {
    jq -n --arg action "$1" --arg username "$username" --arg group "$groupname" \
        '{ok:true, action:$action, username:$username, group:$group}'
}

run() {
    if [ "$DRY" -eq 1 ]; then
        printf '%s\n' "$@" | jq -R . | jq -s --arg action "$action" \
            '{ok:true, dry:true, action:$action, argv:.}'
        return 0
    fi
    "$@"
}

is_admin_name() {
    if [ "$DRY" -eq 1 ]; then
        printf '%s\n' "${MODERN_USERSD_ADMINS:-}" | tr ',' '\n' | grep -qx -- "$1"
        return
    fi
    id -nG -- "$1" 2>/dev/null | tr ' ' '\n' | grep -Eqx 'wheel|sudo'
}

primary_group() {
    if [ "$DRY" -eq 1 ]; then
        printf '%s\n' "${MODERN_USERSD_PRIMARY:-$username}"
        return
    fi
    local gid name
    gid="$(id -g -- "$username" 2>/dev/null)" || return 0
    name="$(getent group "$gid" | cut -d: -f1)" || true
    printf '%s\n' "${name:-}"
}

list_has() {
    local needle="$1" x
    for x in "${_list[@]+"${_list[@]}"}"; do
        [ "$x" = "$needle" ] && return 0
    done
    return 1
}

list_add() {
    list_has "$1" && return 0
    _list+=("$1")
}

human_admin_names() {
    if [ "$DRY" -eq 1 ]; then
        printf '%s\n' "${MODERN_USERSD_ADMINS:-}" | tr ',' '\n' | grep -v '^$' || true
        return
    fi
    local u uid
    while IFS=: read -r u _ uid _; do
        [ "${uid:-0}" -ge 1000 ] && [ "$uid" -lt 60000 ] || continue
        is_admin_name "$u" && printf '%s\n' "$u"
    done < <(getent passwd)
}

refuse_last_admin() {
    local target="$1"
    is_admin_name "$target" || return 0
    local n
    n="$(human_admin_names | grep -c . || true)"
    [ "${n:-0}" -gt 1 ] || fail "last administrator"
}

invoker_names() {
    if [ "$DRY" -eq 1 ]; then
        printf '%s\n' "${MODERN_USERSD_INVOKER:-}"
        return
    fi
    printf '%s\n' "$(id -un)"
    [ -n "${SUDO_USER:-}" ] && printf '%s\n' "$SUDO_USER"
    if [ -n "${PKEXEC_UID:-}" ]; then
        getent passwd "$PKEXEC_UID" | cut -d: -f1 || true
    fi
}

user_exists() {
    if [ "$DRY" -eq 1 ]; then
        printf '%s\n' "${MODERN_USERSD_USERS:-}" | tr ',' '\n' | grep -qx -- "$1"
        return
    fi
    id -- "$1" >/dev/null 2>&1
}

group_exists() {
    if [ "$DRY" -eq 1 ]; then
        printf '%s\n' "${MODERN_USERSD_GROUP_NAMES:-}" | tr ',' '\n' | grep -qx -- "$1"
        return
    fi
    getent group "$1" >/dev/null 2>&1
}

group_gid() {
    if [ "$DRY" -eq 1 ]; then
        local v="${MODERN_USERSD_GID:-}"
        printf '%s\n' "${v:-1000}"
        return
    fi
    getent group "$1" | cut -d: -f3
}

user_uid() {
    if [ "$DRY" -eq 1 ]; then
        [ "$1" = "root" ] && { printf '0\n'; return; }
        printf '1000\n'
        return
    fi
    id -u -- "$1" 2>/dev/null || true
}

require_username() {
    [ -n "$username" ] || fail "username required"
    valid_name "$username" || fail "invalid username"
}

require_existing() {
    require_username
    user_exists "$username" || fail "no such user"
}

require_group() {
    [ -n "$groupname" ] || fail "group required"
    valid_name "$groupname" || fail "invalid group"
}

require_existing_group() {
    require_group
    group_exists "$groupname" || fail "no such group"
}

refuse_if_self_or_root() {
    local target="$1" target_uid inv
    target_uid="$(user_uid "$target")"
    [ -n "$target_uid" ] || return 0
    [ "$target_uid" != "0" ] || fail "refusing to modify uid 0"
    while IFS= read -r inv; do
        if [ -n "$inv" ] && [ "$target" = "$inv" ]; then
            fail "refusing to modify the invoking user"
        fi
    done < <(invoker_names)
}

read_list() {
    local key="$1"
    _list=()
    mapfile -t _list < <(jq -r --arg k "$key" '.[$k][]? // empty' <<<"$json")
    local n
    for n in "${_list[@]+"${_list[@]}"}"; do
        valid_name "$n" || fail "invalid name"
    done
}

create_user() {
    require_username
    user_exists "$username" && fail "user exists"
    local gecos password shell
    gecos="$(jq -r '.gecos // empty' <<<"$json")"
    [[ "$gecos" != *$'\n'* && "$gecos" != *:* ]] || fail "invalid display name"
    password="$(jq -r '.password // empty' <<<"$json")"
    [ -n "$password" ] || fail "password required"
    [[ "$password" != *$'\n'* ]] || fail "invalid password"
    shell="$(jq -r '.shell // "/bin/bash"' <<<"$json")"
    if [ "$DRY" -eq 0 ]; then
        grep -qxF -- "$shell" /etc/shells || fail "shell is not in /etc/shells"
    fi
    read_list groups
    local -a cmd=(useradd -m -s "$shell")
    [ -n "$gecos" ] && cmd+=(-c "$gecos")
    if [ "${#_list[@]}" -gt 0 ]; then
        local IFS=,
        cmd+=(-G "${_list[*]}")
        unset IFS
    fi
    cmd+=(-- "$username")
    run "${cmd[@]}"
    if [ "$DRY" -eq 1 ]; then
        return
    fi
    { printf '%s:' "$username"; printf '%s\n' "$password"; } | chpasswd
    ok create
}

delete_user() {
    require_existing
    refuse_if_self_or_root "$username"
    refuse_last_admin "$username"
    local -a cmd=(userdel)
    [ "$(jq -r '.removeHome // true' <<<"$json")" = "true" ] && cmd+=(-r)
    cmd+=(-- "$username")
    run "${cmd[@]}"
    [ "$DRY" -eq 1 ] || ok delete
}

rename_user() {
    require_existing
    refuse_if_self_or_root "$username"
    local new
    new="$(jq -r '.newUsername // empty' <<<"$json")"
    valid_name "$new" || fail "invalid username"
    [ "$new" = "$username" ] && { [ "$DRY" -eq 1 ] && run usermod -l "$new" -- "$username"; [ "$DRY" -eq 1 ] || ok rename; return; }
    user_exists "$new" && fail "user exists"
    run usermod -l "$new" -- "$username"
    [ "$DRY" -eq 1 ] && return
    local home
    home="$(getent passwd "$new" | cut -d: -f6)"
    if [ "$home" = "/home/$username" ] && [ ! -e "/home/$new" ]; then
        usermod -d "/home/$new" -m -- "$new"
    fi
    username="$new"
    ok rename
}

passwd_user() {
    require_existing
    refuse_if_self_or_root "$username"
    local password
    password="$(jq -r '.password // empty' <<<"$json")"
    [ -n "$password" ] || fail "password required"
    [[ "$password" != *$'\n'* ]] || fail "invalid password"
    if [ "$DRY" -eq 1 ]; then
        run chpasswd
        return
    fi
    { printf '%s:' "$username"; printf '%s\n' "$password"; } | chpasswd
    ok passwd
}

gecos_user() {
    require_existing
    local gecos
    gecos="$(jq -r '.gecos // empty' <<<"$json")"
    [[ "$gecos" != *$'\n'* && "$gecos" != *:* ]] || fail "invalid display name"
    [ -n "$gecos" ] || fail "display name required"
    run chfn -f "$gecos" -- "$username"
    [ "$DRY" -eq 1 ] || ok gecos
}

set_groups() {
    require_existing
    read_list groups
    local g keep_admin=0 prim filtered=()
    prim="$(primary_group)"
    for g in "${_list[@]+"${_list[@]}"}"; do
        if user_exists "$g" && [ "$g" != "$username" ] && [ "$g" != "$prim" ]; then
            continue
        fi
        filtered+=("$g")
    done
    _list=("${filtered[@]+"${filtered[@]}"}")
    [ -n "$prim" ] && list_add "$prim"
    for g in "${_list[@]+"${_list[@]}"}"; do
        if [ "$g" = "wheel" ] || [ "$g" = "sudo" ]; then
            keep_admin=1
        fi
        if [ "$DRY" -eq 0 ]; then
            getent group "$g" >/dev/null 2>&1 || fail "unknown group"
        fi
    done
    if [ "$keep_admin" -eq 0 ] && is_admin_name "$username"; then
        refuse_if_self_or_root "$username"
        refuse_last_admin "$username"
    fi
    local IFS=,
    local joined="${_list[*]}"
    unset IFS
    run usermod -G "$joined" -- "$username"
    [ "$DRY" -eq 1 ] || ok groups
}

create_group() {
    require_group
    group_exists "$groupname" && fail "group exists"
    run groupadd -- "$groupname"
    [ "$DRY" -eq 1 ] && return 0
    if jq -e '.members | type == "array"' >/dev/null 2>&1 <<<"$json"; then
        set_members
        return 0
    fi
    ok group-create
}

delete_group() {
    require_existing_group
    local gid
    gid="$(group_gid "$groupname")"
    [ "${gid:-0}" -ge 1000 ] || fail "protected group"
    user_exists "$groupname" && fail "protected group"
    run groupdel -- "$groupname"
    [ "$DRY" -eq 1 ] || ok group-delete
}

rename_group() {
    require_existing_group
    local gid new
    gid="$(group_gid "$groupname")"
    [ "${gid:-0}" -ge 1000 ] || fail "protected group"
    user_exists "$groupname" && fail "protected group"
    new="$(jq -r '.newGroup // empty' <<<"$json")"
    valid_name "$new" || fail "invalid group"
    group_exists "$new" && fail "group exists"
    run groupmod -n "$new" -- "$groupname"
    [ "$DRY" -eq 1 ] || ok group-rename
}

set_members() {
    require_existing_group
    read_list members
    local u
    if user_exists "$groupname"; then
        _list=("$groupname")
    fi
    if [ "$groupname" = "wheel" ] || [ "$groupname" = "sudo" ]; then
        while IFS= read -r u; do
            [ -n "$u" ] && list_add "$u"
        done < <(human_admin_names)
    fi
    local IFS=,
    local joined="${_list[*]}"
    unset IFS
    run gpasswd -M "$joined" -- "$groupname"
    [ "$DRY" -eq 1 ] || ok group-members
}

update_user() {
    require_existing
    local new gecos password
    new="$(jq -r '.newUsername // empty' <<<"$json")"
    gecos="$(jq -r '.gecos // empty' <<<"$json")"
    password="$(jq -r '.password // empty' <<<"$json")"
    if [ -n "$new" ] && [ "$new" != "$username" ]; then
        rename_user
        username="$new"
    fi
    if [ -n "$gecos" ]; then
        [[ "$gecos" != *$'\n'* && "$gecos" != *:* ]] || fail "invalid display name"
        run chfn -f "$gecos" -- "$username"
    fi
    if [ -n "$password" ]; then
        refuse_if_self_or_root "$username"
        [[ "$password" != *$'\n'* ]] || fail "invalid password"
        if [ "$DRY" -eq 1 ]; then
            run chpasswd
        else
            { printf '%s:' "$username"; printf '%s\n' "$password"; } | chpasswd
        fi
    fi
    if jq -e '.groups | type == "array"' >/dev/null 2>&1 <<<"$json"; then
        set_groups
        [ "$DRY" -eq 1 ] && return 0
    fi
    [ "$DRY" -eq 1 ] || ok update
}

update_group() {
    require_existing_group
    local new
    new="$(jq -r '.newGroup // empty' <<<"$json")"
    if [ -n "$new" ] && [ "$new" != "$groupname" ]; then
        rename_group
        groupname="$new"
    fi
    if jq -e '.members | type == "array"' >/dev/null 2>&1 <<<"$json"; then
        set_members
        [ "$DRY" -eq 1 ] && return 0
    fi
    [ "$DRY" -eq 1 ] || ok group-update
}

case "$action" in
    create) create_user ;;
    delete) delete_user ;;
    rename) rename_user ;;
    passwd) passwd_user ;;
    gecos) gecos_user ;;
    groups) set_groups ;;
    group-create) create_group ;;
    group-delete) delete_group ;;
    group-rename) rename_group ;;
    group-members) set_members ;;
    update) update_user ;;
    group-update) update_group ;;
    *) fail "unknown action" ;;
esac
