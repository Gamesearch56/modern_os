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

`config.json` → `backup.snapperEnabled` is the Settings flag. Enabling
it does not create `/etc/snapper/configs/`; that remains a gated copy.

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

Switching the live `bastianweigand` account onto this desktop, and the
later clean cut of `~/dotfiles`, is `docs/CUTOVER.md`. Phase 2 of that
guide starts with this restore kit.
