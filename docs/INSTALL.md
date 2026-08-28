# Install

Two paths: packages + stow onto an Arch user (`install.sh`), or a live-ISO
bootstrap that **prints** partitioning (`scripts/bootstrap.sh`). System-wide
files under `install/system/` are **never** applied by either default run —
`docs/ISOLATION.md`. Session switch (this machine): `README.md`.

## Prerequisites

- Arch Linux (or an Arch live ISO for bootstrap)
- This repo cloned where the **target** user can read it (a `700` home
  means clone a copy as that user — do not expect `devuser` to read
  `/home/bastianweigand/...`)
- Isolation: `install.sh` refuses `/home/bastianweigand` unless you pass
  `--allow-live-home` (cutover only, not testing)

## This machine — `devuser` (testing)

```bash
# as bastianweigand
scripts/check-isolation.sh
sudo install/system/create-devuser.sh

# as devuser (sudo -iu devuser)
git clone <repo-url> ~/modern_dotfile
cd ~/modern_dotfile
./install/install.sh --profile m0 --dry-run
./install/install.sh --profile m0
```

Start Hyprland on **another TTY** (`Ctrl+Alt+F3`) so the daily-driver
session stays up. Return with `Ctrl+Alt+F1` or `F2`. Full steps:
`README.md`.

## `install.sh` (existing user)

```bash
./install/install.sh --profile m0 --dry-run
./install/install.sh --profile m0 --target /home/devuser
```

Profiles: `m0` (bar/launcher/session), `dev` (+ Cursor/toolchain),
`gaming` (+ Proton/MangoHud), `full`. Manifests:
`install/manifests/README.md`.

`install.sh` only installs packages and stows `stow/` into `--target`
(default `$HOME`). It does not enable greetd, sysctls, ufw, snapper, or
the ESP hook. Stow conflict backups go under
`$TARGET/.local/state/modern/stow-backups`.

`--allow-live-home` disables the daily-driver home guard. Use it only
when this account *is* the one you want to own (new PC cutover).

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

## After stow (on the **target** user)

1. `scripts/theme-apply.sh --wallpaper PATH` (writes `tokens.json`)
2. `systemctl --user enable --now modern-shell.service`
3. `scripts/doctor.sh`
4. Optional gated: sysctl, ufw KDE Connect, ESP hook, snapper — each
   file's header comment has the copy command

Firewall reminder if a later mobile/LAN API is involved: listen on
`0.0.0.0` and `sudo ufw allow <port>/tcp` — not needed for this desktop
shell itself.

## Verify (from the daily-driver account)

```bash
scripts/lint-layers.sh
scripts/check-isolation.sh
./install/install.sh --dry-run --profile m0 --target /tmp/modern-install-dryrun
scripts/doctor.sh
```

Do **not** run `./install/install.sh --dry-run --profile m0` as
`bastianweigand` without `--target` — the live-home guard will fail, which
is the point.
