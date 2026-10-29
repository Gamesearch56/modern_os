#!/usr/bin/env bash
# Unprivileged coverage for usersd.sh. Never mutates /etc/passwd.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-usersd: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-usersd: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/usersd.sh"
[ -x "$SCRIPT" ] || err "usersd.sh must be executable"

run_json() {
    printf '%s\n' "$1" | env -u MODERN_TEST_FIXTURE "$SCRIPT" 2>/dev/null
}

dry() {
    printf '%s\n' "$1" | env MODERN_TEST_FIXTURE=1 \
        MODERN_USERSD_INVOKER="${MODERN_USERSD_INVOKER:-alice}" \
        MODERN_USERSD_USERS="${MODERN_USERSD_USERS:-alice,bob,root}" \
        MODERN_USERSD_ADMINS="${MODERN_USERSD_ADMINS:-alice,bob}" \
        MODERN_USERSD_GROUP_NAMES="${MODERN_USERSD_GROUP_NAMES:-wheel,docker,staff}" \
        MODERN_USERSD_GID="${MODERN_USERSD_GID:-1000}" \
        "$SCRIPT" 2>/dev/null
}

dry_err() {
    printf '%s\n' "$1" | env MODERN_TEST_FIXTURE=1 \
        MODERN_USERSD_INVOKER="${MODERN_USERSD_INVOKER:-alice}" \
        MODERN_USERSD_USERS="${MODERN_USERSD_USERS:-alice,bob,root}" \
        MODERN_USERSD_ADMINS="${MODERN_USERSD_ADMINS:-alice}" \
        MODERN_USERSD_GROUP_NAMES="${MODERN_USERSD_GROUP_NAMES:-wheel,docker,staff}" \
        MODERN_USERSD_GID="${MODERN_USERSD_GID:-10}" \
        "$SCRIPT" 2>/dev/null
}

if "$SCRIPT" extra >/dev/null 2>&1; then
    err "rejected extra argv"
else
    ok "rejects extra argv"
fi

if [ "$(id -u)" -ne 0 ]; then
    if printf '%s\n' '{"action":"create","username":"x"}' | "$SCRIPT" >/dev/null 2>&1; then
        err "unprivileged run must fail"
    else
        ok "refuses to run without root"
    fi
fi

out="$(dry '{"action":"create","username":"carol","password":"secret","groups":["wheel"]}')"
if printf '%s\n' "$out" | grep -Fq '"useradd"' \
    && printf '%s\n' "$out" | grep -Fq '"carol"' \
    && printf '%s\n' "$out" | grep -Fq -- '--dotfiles-only' \
    && ! printf '%s\n' "$out" | grep -Fq 'secret'; then
    ok "create dry-run uses argv arrays, stows the desktop, and hides the password"
else
    err "create dry-run: $out"
fi

out="$(dry '{"action":"delete","username":"bob"}' || true)"
if printf '%s\n' "$out" | grep -Fq '"userdel"' && printf '%s\n' "$out" | grep -Fq '"bob"'; then
    ok "delete other user"
else
    err "delete: $out"
fi

if dry '{"action":"delete","username":"alice"}' >/dev/null 2>&1; then
    err "invoking user was deletable"
else
    ok "refuses to delete the invoking user"
fi

if dry '{"action":"delete","username":"root"}' >/dev/null 2>&1; then
    err "root was deletable"
else
    ok "refuses to modify uid 0"
fi

if printf '%s\n' '{"action":"delete","username":"bob"}' | env MODERN_TEST_FIXTURE=1 \
    MODERN_USERSD_INVOKER=alice MODERN_USERSD_USERS=alice,bob \
    MODERN_USERSD_ADMINS=bob MODERN_USERSD_GROUP_NAMES=wheel \
    MODERN_USERSD_GID=1000 "$SCRIPT" >/dev/null 2>&1; then
    err "last administrator was deletable"
else
    ok "refuses to delete the last administrator"
fi

out="$(dry '{"action":"update","username":"alice","gecos":"Alice Example"}')"
if printf '%s\n' "$out" | grep -Fq '"chfn"' \
    && printf '%s\n' "$out" | grep -Fq 'Alice Example'; then
    ok "session user can set a display name"
else
    err "gecos self: $out"
fi

out="$(dry '{"action":"group-create","group":"bookclub","members":["bob"]}')"
if printf '%s\n' "$out" | grep -Fq '"groupadd"' && printf '%s\n' "$out" | grep -Fq '"bookclub"'; then
    ok "group create"
else
    err "group-create: $out"
fi

out="$(dry '{"action":"group-update","group":"staff","newGroup":"bookclub"}')"
if printf '%s\n' "$out" | grep -Fq '"groupmod"' \
    && printf '%s\n' "$out" | grep -Fq '"bookclub"' \
    && printf '%s\n' "$out" | grep -Fq '"staff"'; then
    ok "group rename"
else
    err "group-update rename: $out"
fi

out="$(dry '{"action":"group-delete","group":"staff"}')"
if printf '%s\n' "$out" | grep -Fq '"groupdel"' && printf '%s\n' "$out" | grep -Fq '"staff"'; then
    ok "group delete"
else
    err "group-delete: $out"
fi

if dry_err '{"action":"group-delete","group":"wheel"}' >/dev/null 2>&1; then
    err "protected group was deletable"
else
    ok "refuses to delete a system group"
fi

if printf '%s\n' '{"action":"group-delete","group":"alice"}' | env MODERN_TEST_FIXTURE=1 \
    MODERN_USERSD_INVOKER=alice MODERN_USERSD_USERS=alice,bob \
    MODERN_USERSD_ADMINS=alice MODERN_USERSD_GROUP_NAMES=alice,wheel \
    MODERN_USERSD_GID=1000 "$SCRIPT" >/dev/null 2>&1; then
    err "private group was deletable"
else
    ok "refuses to delete a private group"
fi

if printf '%s\n' '{"action":"group-update","group":"alice","newGroup":"staff"}' \
    | env MODERN_TEST_FIXTURE=1 MODERN_USERSD_INVOKER=alice \
        MODERN_USERSD_USERS=alice,bob MODERN_USERSD_ADMINS=alice \
        MODERN_USERSD_GROUP_NAMES=alice,staff MODERN_USERSD_GID=1000 \
        "$SCRIPT" >/dev/null 2>&1; then
    err "private group was renamable"
else
    ok "refuses to rename a private group"
fi

if dry '{"action":"create","username":"Bad User","password":"x"}' >/dev/null 2>&1; then
    err "invalid username was accepted"
else
    ok "rejects an invalid username"
fi

PASSWD_QML="$ROOT/stow/shell/.config/quickshell/modern/Services/Passwd.qml"
USERS="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/users"
out="$(dry '{"action":"groups","username":"bob","groups":["docker","wheel"]}')"
if printf '%s\n' "$out" | grep -Fq usermod \
    && printf '%s\n' "$out" | grep -Fq docker \
    && printf '%s\n' "$out" | grep -Fq bob; then
    ok "keeps the private group when setting supplementary groups"
else
    err "primary group dropped: $out"
fi

if printf '%s\n' '{"action":"groups","username":"alice","groups":["docker"]}' \
    | env MODERN_TEST_FIXTURE=1 MODERN_USERSD_INVOKER=alice \
        MODERN_USERSD_USERS=alice,bob MODERN_USERSD_ADMINS=alice \
        MODERN_USERSD_GROUP_NAMES=wheel,docker MODERN_USERSD_PRIMARY=alice \
        "$SCRIPT" >/dev/null 2>&1; then
    err "invoking admin left wheel"
else
    ok "refuses to drop the invoking user from wheel"
fi

if printf '%s\n' '{"action":"group-members","group":"alice","members":["bob"]}' \
    | env MODERN_TEST_FIXTURE=1 MODERN_USERSD_INVOKER=alice \
        MODERN_USERSD_USERS=alice,bob MODERN_USERSD_ADMINS=alice \
        MODERN_USERSD_GROUP_NAMES=alice,wheel MODERN_USERSD_GID=1000 \
        "$SCRIPT" 2>/dev/null | grep -Fq '"alice"' \
    && ! printf '%s\n' '{"action":"group-members","group":"alice","members":["bob"]}' \
        | env MODERN_TEST_FIXTURE=1 MODERN_USERSD_INVOKER=alice \
            MODERN_USERSD_USERS=alice,bob MODERN_USERSD_ADMINS=alice \
            MODERN_USERSD_GROUP_NAMES=alice,wheel MODERN_USERSD_GID=1000 \
            "$SCRIPT" 2>/dev/null | grep -Fq '"bob"'; then
    ok "private group keeps its owner and rejects extra members"
else
    err "private group members"
fi

if grep -F 'Paths.script("usersd.sh")' "$PASSWD_QML" >/dev/null \
    && grep -Fq 'pkexec' "$PASSWD_QML" \
    && grep -Fq 'stdinEnabled' "$PASSWD_QML" \
    && [ -f "$USERS/SessionCard.qml" ] \
    && [ -f "$USERS/UserDialog.qml" ] \
    && [ -f "$USERS/GroupDialog.qml" ] \
    && grep -Fq 'canDelete' "$USERS/UserRow.qml" \
    && grep -Fq 'Settings.close' "$PASSWD_QML" \
    && grep -Fq 'canToggleMember' "$USERS/GroupDialog.qml" \
    && grep -Fq 'originName' "$USERS/GroupDialog.qml" \
    && grep -Fq 'newName: root.name' "$USERS/GroupDialog.qml" \
    && grep -Fq 'canDeleteGroup' "$USERS/GroupRow.qml" \
    && grep -Fq 'canManage' "$PASSWD_QML" \
    && grep -Fq 'canManage' "$USERS/UserList.qml" \
    && grep -Fq 'canManage' "$USERS/GroupList.qml" \
    && grep -Fq 'assignableGroups' "$USERS/UserDialog.qml" \
    && grep -Fq 'gecos: root.gecos' "$USERS/UserDialog.qml" \
    && grep -Fq 'setOwnGecos' "$PASSWD_QML" \
    && grep -Fq '_usersd_evict' "$SCRIPT" \
    && grep -Fq 'loginctl terminate-user' "$SCRIPT" \
    && grep -Fq 'currently used' "$ROOT/stow/shell/.config/quickshell/modern/Services/PasswdParse.qml" \
    && grep -Fq 'provision_new_user_desktop' "$SCRIPT" \
    && grep -Fq '_usersd_repo_ok' "$ROOT/scripts/lib/usersd-desktop.sh" \
    && grep -Fq 'USERS_ROOT/scripts/session-users-sync.sh' "$ROOT/scripts/lib/usersd-desktop.sh" \
    && grep -Fq '_usersd_sync_greeter' "$SCRIPT" \
    && grep -Fq 'session-users-sync.sh' "$SCRIPT" \
    && grep -Fq 'env -i' "$ROOT/scripts/lib/usersd-desktop.sh" \
    && grep -Fq -- '--exclude=.git' "$ROOT/scripts/lib/usersd-desktop.sh" \
    && grep -Fq -- '--dotfiles-only' "$ROOT/install/install.sh" \
    && grep -Fq 'skipping greetd (dotfiles-only)' "$ROOT/install/install.sh" \
    && ! grep -Fq 'skipping theme-apply' "$ROOT/install/install.sh" \
    && grep -Fq '_usersd_copy_prefs' "$ROOT/scripts/lib/usersd-desktop.sh" \
    && grep -Fq '.language.ui' "$ROOT/scripts/lib/usersd-desktop.sh" \
    && grep -Fq '.input.kbLayout' "$ROOT/scripts/lib/usersd-desktop.sh" \
    && grep -Fq 'setOwnGecos' "$PASSWD_QML" \
    && grep -Fq 'canSetOwnGecos' "$PASSWD_QML" \
    && [ -f "$ROOT/stow/shell/.config/quickshell/modern/Services/PasswdSelf.qml" ] \
    && grep -Fq 'DOTFILES_ONLY' "$ROOT/install/lib/pkg.sh" \
    && [ -f "$ROOT/scripts/lib/usersd-desktop.sh" ] \
    && ! grep -Fq 'sudo useradd' "$USERS/Section.qml"; then
    ok "Settings pkexecs usersd.sh and the main user cannot be deleted"
else
    err "Settings Users wiring"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-usersd: ok\n'
