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

Build on this PC or CI. Output is gitignored `iso/out/` (throwaway
`HOME` for matugen). `--mkarchiso` needs **root**, `archiso`, and about
**8G free** on that directory — not `/tmp`. It does **not** run
`provision-iso.sh` or touch live `/etc` except a throwaway AUR builder
user that is deleted when the script exits.

```bash
sudo pacman -S --needed archiso qemu-desktop
sudo ./scripts/iso-build.sh --mkarchiso
./scripts/iso-qemu.sh          # live image + 64G qcow2 (Calamares needs ≥ 16 GiB)
```

The **live** ISO is this clone (kiosk, branding, Calamares). After
install, Calamares late clones the baked-in **release tag** (`--tag` or
the latest `vX.Y.Z`). First boot of the **installed** system is greetd
+ password.

The **live** image autologins `liveuser` into `cage`. Cage's client is
Xwayland; Calamares runs as root on X11 (`sudo` + `xhost`) so partitioning
works. Root cannot be a Wayland client of liveuser's compositor, and a
root compositor never painted in QEMU. `iso-qemu.sh` writes guest serial
to `iso/out/vm-serial.log`.

After **Install**, the exec page copies the squashfs (`unpackfs`), then
checks packages already on the image (`linux-zen` is shipped so this is
not a network download), then three named late jobs: clone the pin,
`install.sh --profile m0 --yes`, `provision-iso.sh`. The bar only moves
when a job reports; unpack in QEMU can sit still for many minutes. Late
git has a 180s timeout instead of hanging for two hours.
If you land on a TTY, this image never started greetd:

```bash
/usr/lib/modern/live-session.sh
```

Welcome **Support** / **Known issues** open GitHub in Firefox on the
same session. There is no Donate button. The VM needs virtio 3D.

Settings → Update later tracks the latest GitHub **release tag**, not
`dev` or the tip of `main`.

## After stow (on the **target** user)

`install.sh` phase 5 applies `~/.config/modern/wallpapers/default.jpg`
(tokens, GTK/Qt/kitty). `wallpaper-sync.sh` writes lock assets to
`~/.local/state/modern/session` until gated `/var/lib/modern/session`
exists. Nautilus sidebar starts with Downloads, Pictures, and Videos
(`nautilus-prefs.sh`, XDG dirs for the target user). First-hour UI is
**English**. Power-menu lock is an overlay
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
scripts/ci-check.sh
scripts/check-isolation.sh
./install/install.sh --dry-run --profile m0 --target /tmp/modern-install-dryrun
scripts/doctor.sh
```

If `MODERN_PROTECT_HOME` is your `$HOME`, do **not** run
`./install/install.sh --dry-run --profile m0` without `--target` — the
live-home guard will fail, which is the point.
