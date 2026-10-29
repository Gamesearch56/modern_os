# Threat model: modern-usersd

Settings → Users mutates accounts through one `pkexec` of
`scripts/usersd.sh` after **admin** authentication (`auth_admin`). JSON
on stdin; names as argv arrays; passwords never on argv. The session
account, uid 0, and the last administrator cannot be deleted. System
groups (gid < 1000) cannot be renamed or removed.

`install/system/modern-usersd` is a gated copy of that helper for
`/usr/local/bin`. `install.sh` never copies it to `/usr`. Applying it is
an explicit, separate step (see `docs/ISOLATION.md`).

## Assets

- `/etc/passwd`, `/etc/shadow`, `/etc/group`, and home directories
- The invoking user's own account (lockout / privilege loss)

## Actors

| Actor | Access |
|---|---|
| Session user in an active seat | Can `pkexec modern-usersd` only after **admin** authentication (`auth_admin`). Inactive and any-user polkit subjects are denied. |
| Unprivileged process without a seat | Cannot obtain the polkit action (`allow_any=no`). |
| Already-root process | Can call the helper directly; the helper still refuses to modify uid 0 and the invoking user. |

## Trust boundaries

1. **JSON stdin, not argv strings.** The helper parses one object with
   `jq` and passes `username` / group names as **array elements** to
   `useradd` / `userdel` / `usermod` / `chpasswd` / `groupadd`. Names
   are never concatenated into a shell command line, so metacharacters
   cannot run code even if validation were bypassed. The password is
   piped to `chpasswd` and is never in `ps`.
2. **Username grammar.** Only `^[a-z_][a-z0-9_-]{0,31}$` is accepted,
   minus a reserved set (`root`, `nobody`, `greeter`, …). Groups use
   the same pattern. Login shells must appear verbatim in `/etc/shells`.
3. **Self-protection.** Delete / rename / passwd refuse the invoking
   identity (`SUDO_USER`, `PKEXEC_UID`, and `id -un`) and uid 0. The
   last `wheel`/`sudo` human account cannot be deleted or demoted.
4. **Polkit.** Settings uses `org.freedesktop.policykit.exec`
   (`auth_admin`) on `scripts/usersd.sh`, same as autologin and UFW.
   `install/system/polkit/link.modern.usermanager.policy` still
   documents a pinned `/usr/local/bin/modern-usersd` if you copy the
   staged files yourself.

## Non-goals

- Remote / networked account management
- Directory (LDAP/FreeIPA) users
- Password-quality policy (callers should enforce that before `passwd`)

## KDE Connect ports (staged, not applied)

Phone pairing uses TCP and UDP **1714–1764**. Rules live in
`install/system/ufw/kdeconnect.rules` and are **not** applied by
`install.sh`. Open them on a trusted LAN only:

```bash
sudo ufw allow 1714:1764/tcp comment kdeconnect
sudo ufw allow 1714:1764/udp comment kdeconnect
```

## Residual risk

A user who can already authenticate as admin can create extra local
accounts. Create also copies this desktop into the new home (`install.sh
--dotfiles-only`). That is equivalent to `useradd` plus stow via sudo.
Rollback: remove the binary and the `.policy` file; existing accounts
are untouched.

## Settings → Firewall (UFW)

Settings talks to UFW through `pkexec` after admin authentication
(`org.freedesktop.policykit.exec`, `auth_admin` — a prompt per call,
not a session keep) for enable, disable, add, and delete, the same
way Backup talks to snapper for create/delete. Enable/disable is one
`pkexec` of `scripts/ufw-apply.sh` (as root it sets deny incoming /
allow outgoing / deny routed, then `--force enable`). Add/delete
build argv onto `/usr/bin/ufw` itself: no shell, no `reset`, no
`default allow incoming`. Listing on open is unprivileged
(`scripts/ufw-status.sh` reads `/etc/ufw/ufw.conf` and `user*.rules`).
A second `pkexec` while another prompt is live is dropped by Phylax
(one cookie). Add requires a port (or a range of at most 512 ports);
From is IP/CIDR only. Rules live in `/etc/ufw` and survive reboot.
KDE Connect ports stay staged and are not opened from this page.
