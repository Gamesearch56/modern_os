# Backups

For admins: the btrfs/Snapper layout ModernOS expects, how Settings →
Backup and `modern update` use snapshots, and what to copy by hand
after a reinstall.

Layout and restore notes. Snapper/restic and the ESP hook are **gated**
(`install/system/`, `docs/ISOLATION.md`) — nothing here runs from
`install.sh`.

## Snapper layout

Btrfs subvolumes created by `scripts/bootstrap.sh` (print-only until
`--yes --disk`):

| Subvolume    | Mount              | Snapper? |
|--------------|--------------------|----------|
| `@`          | `/`                | yes (root config) |
| `@home`      | `/home`            | yes (home config, optional) |
| `@pkg`       | `/var/cache/pacman/pkg` | no — cache |
| `@log`       | `/var/log`         | no — noisy |
| `@snapshots` | `/.snapshots`      | snapper's store |
| `@swap`      | swap file host     | **never** |

`config.json` → `backup.preUpdateSnapshot` is the Settings flag that
`modern update` honors. `backup.pruneEnabled` (default on) and
`backup.keepCount` (3–20, default 8) drop the oldest Snapper snapshots
when more than that exist — after a manual create, after changing the
keep setting, and after `modern update`. Snapshot 0 is never deleted.
`backup.snapperEnabled` and `backup.resticEnabled`
stay in config for compatibility; Settings no longer shows those
toggles (they did not install snapper or configure a restic repo).
Settings → Backup **Create config** writes the Snapper `root` config
through one `pkexec` of `scripts/snapper-setup.sh`. When `/.snapshots`
is already the `@snapshots` mount, that script writes the config files
and leaves the mount alone — `snapper create-config /` would fail
because it cannot create a nested `.snapshots`. Hourly Snapper
snapshots stay off. Settings then lists, creates, deletes, and restores
snapshots when the `root` config exists. Restore is one `pkexec` of
`scripts/snapper-restore.sh`: it clones the chosen snapshot over
subvolume `@` (fstab pins `subvol=/@`, so `snapper rollback` would not
change the next boot). `@home` is left alone. The previous `@` is kept
as `@rollback-<UTC>`. Settings reboots when that script succeeds.

## Swapfile lives on `@swap`

A swap *file* on a snapshotted subvolume is a classic footgun: snapper
(or a send/receive) can snapshot active swap, and the swapfile's
`chattr +C` / `nodatacow` flags do not survive a naive copy. Keep swap
on `@swap` (or a dedicated partition) and never add `@swap` to a snapper
config. If you must put swap on `@`, disable CoW on the file and exclude
it from snapshots explicitly.

## ESP copy hook

`modern update` already mirrors the ESP (minus `EFI/`) into
`/var/lib/modern/esp` right before its pre-update snapshot, so every
"ModernOS Update" snapshot carries the kernel that matches its modules.
`snapper-restore.sh` syncs that copy back to `/boot` after swapping `@`;
without it, a restored `@` would boot the newer kernel on the ESP with
no modules for it, and `/boot` itself would fail to mount.

`install/system/pacman/hooks/esp-backup.hook` is staged with
`Exec = /usr/bin/true` so an accidental install is a no-op. After
review, point Exec at a copy of `/efi` or `/boot` onto another
filesystem (`/var/lib/modern/esp-backup`) and enable `AbortOnFail` so a
failed copy blocks the kernel upgrade. **Do not enable until that dest
exists.**

## restic (not implemented)

`backup.resticEnabled` is reserved; ModernOS does not configure restic.
If it is added, the repository and password belong in the gitignored
`secrets.json` (owned by `Services/Secrets.qml`), never in
`config.default.json`; backups should exclude `.steam/steamapps`,
`~/.cache`, `@pkg` and `@swap`; and the timer would live under
`stow/systemd`.

`scripts/doctor.sh` warns when restic is missing or unconfigured.

## `modern update`

If `backup.preUpdateSnapshot` is true, `modern update` takes a Snapper
snapshot and runs `pacman -Syu` in **one** `pkexec` (`scripts/update-apply.sh`),
after `desktop-sync.sh apply` when a newer release tag is pending. It still
runs the desktop/package steps when snapper is missing — not Timeshift.

Nothing the desktop does can cut pacman off halfway:

- Settings starts `scripts/update-run.sh`, which runs `modern update` in
  its own session with output in `$XDG_STATE_HOME/modern/update.log`.
  Settings only follows that log and re-attaches after a shell reload or
  crash.
- `update-apply.sh` re-runs itself as the transient system service
  `modern-system-update` under `systemd-inhibit` (shutdown, sleep,
  idle). Logout, a dead shell or a closed pipe no longer kill it.
- If pacman fails after it started changing packages, the pre-update
  snapshot (with its ESP copy) is restored and Settings asks for a
  restart. A run cut off anyway (power loss) leaves
  `/var/lib/modern/update-snapshot`; the next update finishes the
  transaction and reinstalls the kernel so its hooks run.
- New installs load `vfat` from the initramfs
  (`iso/airootfs/etc/mkinitcpio.conf.d/50-modern-esp.conf`), so `/boot`
  mounts even when the modules on disk do not match the kernel.


## Restore kit

After a bare-metal reinstall, copy these onto the new `$HOME` **before**
expecting AI chat, the calendar, git, or SSH to work. None of them
belong in git:

| Item | Why |
|------|-----|
| `~/.config/modern/secrets.json` | AI keys, calendar credentials (`Services/Secrets.qml`) and the problem-report token; gitignored |
| `~/.ssh/` | keys and `known_hosts` |
| `~/.bashrc.local` | machine-local shell (gitignored) |
| `~/.gitconfig.local` | `user.name` / `user.email` |
| `~/.local/share/modern/` | OptiScaler cache, launcher frecency, other app data |

Then: `install/install.sh --profile …`, `scripts/theme-apply.sh`,
`scripts/doctor.sh`.

Putting this desktop on an existing account is `docs/CUTOVER.md`.
