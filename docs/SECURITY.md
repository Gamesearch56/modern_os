# Threat model: modern-usersd

`install/system/modern-usersd` is a **gated** root helper for local
account CRUD. `install.sh` never copies it to `/usr`. Applying it is an
explicit, separate step (see `docs/ISOLATION.md`).

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
   `useradd` / `userdel` / `usermod` / `chpasswd`. Names are never
   concatenated into a shell command line, so metacharacters cannot run
   code even if validation were bypassed.
2. **Username grammar.** Only `^[a-z_][a-z0-9_-]*$` is accepted.
   Groups use the same pattern and must already exist (`getent group`).
   Login shells must appear verbatim in `/etc/shells`.
3. **Self-protection.** Delete / passwd / groups refuse the invoking
   identity (`SUDO_USER`, `PKEXEC_UID`, and `id -un`) and uid 0.
4. **Polkit.** `install/system/polkit/link.modern.usermanager.policy`
   documents `pkexec` of `/usr/local/bin/modern-usersd`. That path is
   not populated unless you copy the staged files yourself.

## Non-goals

- Remote / networked account management
- Directory (LDAP/FreeIPA) users
- Password-quality policy (callers should enforce that before `passwd`)
- Running from the Settings GUI without a future `Services/Users.qml`
  + polkit prompt; Settings > Users is informational until that lands

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
accounts. That is equivalent to `useradd` via sudo. Rollback: remove
the binary and the `.policy` file; existing accounts are untouched.

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
