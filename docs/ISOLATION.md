# Isolation: initramfs stays out of `install.sh`

For developers and admins: which system-wide changes `install.sh` makes,
which ones stay gated under `install/system/` and why, and how to test
on a separate account without touching your own session.

`install.sh` installs packages, stows this repo into `--target`
(default `$HOME`), and enables the greetd login screen on a **real user
home**. `--dry-run` and `--target /tmp/...` skip greetd.

Plymouth, NVIDIA mkinitcpio, polkit `modern-usersd`, snapper, gaming
sysctls, and the ESP backup hook stay under `install/system/` and are
applied only by an explicit ISO provision command.

Optional extra-user testing: `sudo install/system/create-devuser.sh
[username]` (default name `devuser`), then clone and install as that
user. `install.sh` on that home still enables greetd for the machine.
Session switch: log in from the greeter. Install flags: `docs/INSTALL.md`.
Putting this desktop on an existing account: `docs/CUTOVER.md`.

## Safe by construction

- Stow writes only under `--target`. Conflict backups land in
  `$TARGET/.local/state/modern/stow-backups`.
- Set `MODERN_PROTECT_HOME` to a directory `install.sh` must never stow
  into (optional; unset means the guard is idle). Override with
  `--allow-live-home` only when that home *is* the intended target.
- Runtime state lives under the target user's home or, after tmpfiles,
  `/var/lib/modern/`.
- An extra test account is optional. Isolation check treats that account as
  OK, not as a leak. greetd enabled by `install.sh` is expected.

## Extra-user testing (optional)

1. Leave the other graphical session running.
2. `Ctrl+Alt+F3`, log in as the test user, run `start-hyprland`
   (not the `Hyprland` binary). One Hyprland per user — exit the old
   one before starting another TTY.
3. Return with `Ctrl+Alt+F1` or `F2`. End the test compositor with
   `SUPER+SHIFT+M`, or from another TTY `loginctl terminate-session <id>`.
   If a terminal is available: `hyprctl dispatch "hl.dsp.exit()"`, then
   `exit` on the TTY.

Removing the test account (`sudo userdel -r <username>`) deletes that
home only. Greetd stays the machine login.

## Gated: initramfs and extra `/etc`

These affect the whole machine and can brick a boot, so they stay
**staged under `install/system/`** and are applied only by ISO late
(`provision-iso.sh`).

| Change | Why it's gated | Rollback |
|---|---|---|
| Plymouth theme + `mkinitcpio` hooks | Rewrites the initramfs. A bad rebuild can leave the machine unable to boot. A system update (`scripts/update-apply.sh`) and `provision-iso.sh` enable it, and rebuild only when the theme or the hook changed. `sudo install/system/plymouth/apply.sh` does the same. A wallpaper or palette change does not. | `sudo mkinitcpio -P` after reverting `/etc/mkinitcpio.conf`; the previous initramfs stays as a fallback boot entry — never delete it. |
| ISO late extras (`nvidia_apply`, keyboard/locale seed) | NVIDIA modeset/initramfs; Calamares keyboard/locale into `config.json`. Greetd itself is already applied by `install.sh`. | Revert the drop-ins; `provision-iso.sh` still refuses when `MODERN_PROTECT_HOME` is set. |
| `sysctl.d`, `polkit` actions, udev rules, gaming perf sysctls | System-wide kernel/session policy. | Remove the dropped-in file under `/etc/{sysctl.d,polkit-1,udev/rules.d}/modern-*` and reload. |
| zram config, `99-modern-zram.conf`, rotational bfq | Compressed swap (half of RAM, max 4 GiB) and fair IO on spinning disks. Next boot. SSDs are unchanged. | Delete `/etc/systemd/zram-generator.conf`, `/etc/sysctl.d/99-modern-zram.conf`, and `/etc/udev/rules.d/60-modern-rotational-bfq.rules`, then reboot. |
| `modern-usersd` + its polkit action | Privileged account/group mutation. | Remove `/usr/local/bin/modern-usersd` and the `.policy` file; nothing else depends on it. |
| Extra-user creation (`install/system/create-devuser.sh`) | Creates a system account. | `sudo userdel -r <username>` if you want to remove it entirely. |
| Backup: snapper configs, the ESP-copy pacman hook | Touches `/etc/snapper`, `/etc/pacman.d/hooks`. | Delete the config/hook files; existing snapshots are untouched. |

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

`iso-build.sh --mkarchiso` may write `iso/out/` on your build machine (needs root).
Do not run `provision-iso.sh` or Calamares on a machine you live on
unless you intend the ISO late extras (NVIDIA initramfs). Existing-account
stow + greetd: `docs/CUTOVER.md`.
