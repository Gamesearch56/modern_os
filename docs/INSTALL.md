# Install

Three paths: packages + stow onto an Arch user (`install.sh`), a live-ISO
bootstrap that **prints** partitioning (`scripts/bootstrap.sh`), or an
**ISO** (Calamares + late `install.sh --profile m0 --yes`).
System-wide files under `install/system/` are **never** applied by
`install.sh` — `docs/ISOLATION.md`. `provision-iso.sh` is Calamares-late
only and refuses when `MODERN_PROTECT_HOME` is set. Git / release tags:
`docs/GIT.md`. Existing account: `docs/CUTOVER.md`.

## Prerequisites

- Arch Linux (or an Arch live ISO for bootstrap)
- This repo cloned where the **target** user can read it (a `700` home
  means clone a copy as that user)
- Optional: set `MODERN_PROTECT_HOME` so `install.sh` refuses that path
  unless you pass `--allow-live-home`

## Extra-user testing (`devuser`)

```bash
scripts/check-isolation.sh
sudo install/system/create-devuser.sh

# as devuser (sudo -iu devuser)
git clone <repo-url> ~/modern_dotfile
cd ~/modern_dotfile
./install/install.sh --profile m0 --dry-run
./install/install.sh --profile m0
```

Start the session on **another TTY** (`Ctrl+Alt+F3`) with
`start-hyprland`. Do not run the `Hyprland` binary — Hyprland ≥ 0.53
needs the wrapper or the bar never appears. Return with `Ctrl+Alt+F1`
or `F2`.

## `install.sh` (existing user)

```bash
./install/install.sh --profile m0 --dry-run
./install/install.sh --profile m0 --target /home/devuser
```

Profiles: `m0` (bar/launcher/session), `dev` (+ Cursor/toolchain),
`gaming` (+ Proton/MangoHud), `full`. Manifests:
`install/manifests/README.md`.

`install.sh` only installs packages and stows listed packages into
`--target` (default `$HOME`): hypr, shell, theme, kitty, dolphin, gtk,
qt, bash, git, modern, systemd, xdg, fontconfig, fastfetch, mpv, imv. It does **not** stow
`greeter`. It never copies `install/system/` and never enables greetd.
Stow conflict backups go under `$TARGET/.local/state/modern/stow-backups`.

Calamares late on a new machine is `./install/install.sh --profile m0 --yes`
as the new user, then `MODERN_ISO_PROVISION=1 install/system/provision-iso.sh`.
That gated script is the only allowed applier of greetd / NetworkManager
enable. Do not run it on a machine you live on.

Clone + install is the **designed** desktop (`config.default.json`:
English UI, `kbLayout` `us`).

`--allow-live-home` disables the `MODERN_PROTECT_HOME` guard. Use it
only when that account *is* the one you want to own, following
`docs/CUTOVER.md`. Not for `devuser` testing.

Installer log: `install/install.log` (gitignored) and
`journalctl -t modern-install`.

## Create `devuser` (gated)

```bash
sudo install/system/create-devuser.sh
```

This does **not** change autologin. Rollback: `sudo userdel -r devuser`.

## Bare metal (`bootstrap.sh`)

From the live ISO, copy `install/hardware.conf.example` to
`install/hardware.conf` and set `DISK=`. **Default is dry-run** (prints
partition → btrfs `@ @home @pkg @log @snapshots @swap` → pacstrap →
arch-chroot → chain `install.sh`). Disks are not wiped unless you pass
`--yes --disk /dev/X` together, and this process still does not call
`mkfs` — you run the printed steps as root after review.

```bash
./scripts/bootstrap.sh --dry-run
./scripts/bootstrap.sh --vm          # QEMU recipe only
```

## ISO (Calamares)

Built with `scripts/iso-build.sh` on a spare box or CI. Branding lands
under gitignored `iso/out/` (throwaway `HOME` for matugen). `--mkarchiso`
is refused when `MODERN_PROTECT_HOME` is set and that directory exists.
The ISO clones the baked-in release tag (`vX.Y.Z`, `docs/GIT.md`), runs
`install.sh --profile m0 --yes`, then `provision-iso.sh`. First boot is
greetd + password; the installed user does not run extra `systemctl` or
`pacman`.

Settings → Update later tracks the latest GitHub **release tag**, not
`dev` or the tip of `main`.

## After stow (on the **target** user)

`install.sh` phase 5 applies `~/.config/modern/wallpapers/default.jpg`
(tokens, GTK/Qt/kitty). `wallpaper-sync.sh` writes lock assets to
`~/.local/state/modern/session` until gated `/var/lib/modern/session`
exists. First-hour UI is **English**. Power-menu lock is an overlay
preview, not a real lock. Titlebars need a one-time `hyprpm` + pkexec
in a graphical session (`docs/TROUBLESHOOTING.md`).

To use a different image later:

1. `scripts/theme-apply.sh --wallpaper PATH` (writes `tokens.json` and
   syncs lock/login assets)
2. `start-hyprland` on a TTY (not the `Hyprland` binary). Autostart
   starts `qs -c modern` as a child of Hyprland. Skip
   `systemctl --user enable` on a text TTY (`docs/BOOT.md`).
3. `scripts/doctor.sh`
4. Optional gated files that **exist**: Plymouth README, sysctl, ufw
   KDE Connect, tmpfiles, ESP hook, snapper, `create-devuser.sh` —
   each file's header comment has the copy command. Greetd drop-ins live
   under `install/system/greetd/` but stay gated — only `provision-iso.sh`
   in a Calamares chroot applies them.

Hand-edit reference is `config.default.json` (no `config.schema.json`).

Firewall reminder if a later mobile/LAN API is involved: listen on
`0.0.0.0` and `sudo ufw allow <port>/tcp` — not needed for this desktop
shell itself.

## Verify

```bash
scripts/lint-layers.sh
scripts/check-isolation.sh
./install/install.sh --dry-run --profile m0 --target /tmp/modern-install-dryrun
scripts/doctor.sh
```

If `MODERN_PROTECT_HOME` is your `$HOME`, do **not** run
`./install/install.sh --dry-run --profile m0` without `--target` — the
live-home guard will fail, which is the point.
