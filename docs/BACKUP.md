# Backups

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
`modern update` honors. `backup.snapperEnabled` and `backup.resticEnabled`
stay in config for compatibility; Settings no longer shows those
toggles (they did not install snapper or configure a restic repo).
Settings → Backup **Create config** writes the Snapper `root` config
through one `pkexec` of `scripts/snapper-setup.sh`. When `/.snapshots`
is already the `@snapshots` mount, that script writes the config files
and leaves the mount alone — `snapper create-config /` would fail
because it cannot create a nested `.snapshots`. Hourly Snapper
snapshots stay off. Restore/rollback stays gated. Settings then lists,
creates, and deletes snapshots when the `root` config exists.

## Swapfile lives on `@swap`

A swap *file* on a snapshotted subvolume is a classic footgun: snapper
(or a send/receive) can snapshot active swap, and the swapfile's
`chattr +C` / `nodatacow` flags do not survive a naive copy. Keep swap
on `@swap` (or a dedicated partition) and never add `@swap` to a snapper
config. If you must put swap on `@`, disable CoW on the file and exclude
it from snapshots explicitly.

## ESP copy hook

`install/system/pacman/hooks/esp-backup.hook` is staged with
`Exec = /usr/bin/true` so an accidental install is a no-op. After
review, point Exec at a copy of `/efi` or `/boot` onto another
filesystem (`/var/lib/modern/esp-backup`) and enable `AbortOnFail` so a
failed copy blocks the kernel upgrade. **Do not enable until that dest
exists.**

## restic (later)

`backup.resticEnabled` is reserved. When wired:

- repo and password live in gitignored `secrets.json`, never in
  `config.default.json`
- exclude `.steam/steamapps`, `~/.cache`, `@pkg`, `@swap`
- a timer under `stow/systemd` (not shipped in this milestone)

`scripts/doctor.sh` warns when restic is missing or unconfigured.

## `modern update`

If `backup.preUpdateSnapshot` is true, `modern update` runs `snapper
create`, then `desktop-sync.sh apply` when a newer release tag is
pending, then `pacman -Syu` if packages are pending. It still runs the
desktop/package steps when snapper is missing — not Timeshift.


## Restore kit

After a bare-metal reinstall, copy these onto the new `$HOME` **before**
expecting mail, git, or Proton to work. None of them belong in git:

| Item | Why |
|------|-----|
| `~/.config/modern/secrets.json` | API tokens; gitignored |
| `~/.ssh/` | keys and `known_hosts` |
| Proton / Bridge state | `~/.config/protonmail/` or the Bridge data dir |
| `~/.bashrc.local` | machine-local shell (gitignored) |
| `~/.gitconfig.local` | `user.name` / `user.email` |
| `~/.local/share/modern/` | notes, OptiScaler cache, launcher frecency |

Then: `install/install.sh --profile …`, `scripts/theme-apply.sh`,
`scripts/doctor.sh`.

Putting this desktop on an existing account is `docs/CUTOVER.md`.
