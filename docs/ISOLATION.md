# Isolation: installer never applies `/etc`

`install.sh` only installs packages and stows this repo into `--target`
(default `$HOME`). Anything that touches `/etc`, systemd *system* units,
polkit, mkinitcpio, or creates accounts lives under `install/system/`
and is applied only by an explicit, separately-invoked command.

Optional extra-user testing: `sudo install/system/create-devuser.sh`,
then clone and install as that user. Session switch: log in on another
TTY and run `start-hyprland`. Install flags: `docs/INSTALL.md`. Putting
this desktop on an existing account: `docs/CUTOVER.md`.

## Safe by construction

- Stow writes only under `--target`. Conflict backups land in
  `$TARGET/.local/state/modern/stow-backups`.
- Set `MODERN_PROTECT_HOME` to a directory `install.sh` must never stow
  into (optional; unset means the guard is idle). Override with
  `--allow-live-home` only when that home *is* the intended target.
- Runtime state lives under the target user's home or, after gated
  tmpfiles, `/var/lib/modern/`.
- Creating a `devuser` account is the intended extra-user test path. It
  does not change autologin, greetd, or `/etc`. Isolation check treats
  that account as OK, not as a leak.

## Switching sessions without replacing another user

1. Leave the other graphical session running.
2. `Ctrl+Alt+F3`, log in as the test user, run `start-hyprland`
   (not the `Hyprland` binary). One Hyprland per user — exit the old
   one before starting another TTY.
3. Return with `Ctrl+Alt+F1` or `F2`. End the test compositor with
   `SUPER+SHIFT+M`, or from another TTY `loginctl terminate-session <id>`.
   If a terminal is available: `hyprctl dispatch "hl.dsp.exit()"`, then
   `exit` on the TTY.

A reboot still uses whatever login path was already configured as long
as greetd was never enabled from this repo. Removing the test account
(`sudo userdel -r devuser`) deletes `/home/devuser` only.

## Gated: system-wide changes

These affect the whole machine, not one account, so they are **staged as
files under `install/system/` and never applied automatically**. Applying
them is a separate, explicit, human-invoked step — see each file's header
comment for the exact command.

| Change | Why it's gated | Rollback |
|---|---|---|
| `greetd` (staged, **gated**) | `install/system/greetd/` exists for the ISO. Only `install/system/provision-iso.sh` (Calamares late, `MODERN_ISO_PROVISION=1`) copies it and runs `systemctl enable greetd`. That script aborts if `MODERN_PROTECT_HOME` is set and exists. Do not enable greetd on a machine you did not intend to convert to greetd. | `sudo systemctl disable greetd`, restore the previous login path, reboot. |
| ISO late (`provision-iso.sh`, `calamares-late.sh`) | Enables NM/bluetooth/greetd and clones a release tag. Refused when `MODERN_PROTECT_HOME` is set. | Not applied; files stay under `install/system/` and `iso/`. |
| Plymouth theme + `mkinitcpio` hooks | Rewrites the initramfs. A bad rebuild can leave the machine unable to boot. | `sudo mkinitcpio -P` after reverting `/etc/mkinitcpio.conf`; the previous initramfs stays as a fallback boot entry — never delete it. |
| `sysctl.d`, `polkit` actions, `tmpfiles.d`, udev rules, gaming perf sysctls | System-wide kernel/session policy. | Remove the dropped-in file under `/etc/{sysctl.d,polkit-1,tmpfiles.d,udev/rules.d}/modern-*` and reload (`sysctl --system`, `systemctl restart polkit`, `systemd-tmpfiles --create`). |
| `modern-usersd` + its polkit action | Privileged account/group mutation. | Remove `/usr/local/bin/modern-usersd` and the `.policy` file; nothing else depends on it. |
| Devuser creation (`install/system/create-devuser.sh`) | Creates a system account. | `sudo userdel -r devuser` if you want to remove it entirely. Autologin is unchanged. |
| Backup: snapper configs, the ESP-copy pacman hook | Touches `/etc/snapper`, `/etc/pacman.d/hooks`. | Delete the config/hook files; existing snapshots are untouched. |

**None of the files above are referenced by `install.sh`'s default run.**
`install.sh` only ever touches packages and the target user's stowed
dotfiles. A second, explicitly named script or flag is required for
anything in the table — see each script's own `--help`.

## The one side effect that isn't gated: packages

Installing packages is inherently system-wide (pacman has no per-user
scope) and is additive, so it isn't gated.

This repo ships **no pacman hook**. Package manifests under
`install/manifests/` are hand-curated files, not auto-generated. Run
`scripts/snapshot-packages.sh` manually whenever you want to audit drift
between the machine and the manifests.

## Verification

Run before every commit and before/after any local test command that
might have written outside the clone:

```bash
scripts/check-isolation.sh
```

`iso-build.sh --mkarchiso` may write `iso/out/` on this PC (needs root).
Do not run `provision-iso.sh`, Calamares, or a live `install.sh` (use
`--dry-run --target /tmp/…`) on a machine you live on.

It asserts:

1. If `MODERN_PROTECT_HOME` is set, no symlink inside that home's
   `.config` points into this clone.
2. Gated files are absent (`greetd` enabled, `modern-usersd`,
   `tmpfiles.d/modern-session.conf`, `sysctl.d/99-modern-gaming.conf`,
   `esp-backup.hook`), unless `--allow-gated` is passed. Creating
   `devuser` is **not** a failure. Pre-existing Plymouth in mkinitcpio is
   not treated as a leak from this repo.
3. Home mtime under the protected path is **advisory** (WARN): a live
   account keeps writing caches. Real isolation is checks 1–2.

The script exits non-zero and prints exactly what changed if any check
fails, rather than a generic warning.

First-time baseline (once): `scripts/check-isolation.sh --init`.
Do not add this script to GitHub Actions.
