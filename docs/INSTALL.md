# Install

Two paths: packages + stow onto an existing Arch user (`install.sh`), or
a live-ISO bootstrap that prints (and only with extra flags, would run)
partitioning (`scripts/bootstrap.sh`). System-wide files under
`install/system/` are **never** applied by either default run —
`docs/ISOLATION.md`.

## Prerequisites

- Arch Linux (or an Arch live ISO for bootstrap)
- This repo cloned where the **target** user can read it
- Isolation: do not stow onto the daily-driver account

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
the ESP hook.

## Create `devuser` (gated)

```bash
sudo install/system/create-devuser.sh
```

Then clone/stow as that user. From the daily-driver account run
`scripts/check-isolation.sh` before and after.

## Bare metal (`bootstrap.sh`)

From the live ISO, copy `install/hardware.conf.example` to
`install/hardware.conf` and set `DISK=`. **Default is dry-run** (prints
partition → btrfs `@ @home @pkg @log @snapshots @swap` → pacstrap →
arch-chroot → chain `install.sh`). Disks are not wiped unless you pass
`--yes --disk /dev/X` together.

```bash
./scripts/bootstrap.sh --dry-run
./scripts/bootstrap.sh --vm          # QEMU recipe only
```

## After stow

1. `scripts/theme-apply.sh --wallpaper PATH` (writes `tokens.json`)
2. `systemctl --user enable --now modern-shell.service` (on the target user)
3. `scripts/doctor.sh`
4. Optional gated: sysctl, ufw KDE Connect, ESP hook, snapper — each
   file's header comment has the copy command

Firewall reminder if a later mobile/LAN API is involved: listen on
`0.0.0.0` and `sudo ufw allow <port>/tcp` — not needed for this desktop
shell itself.

## Verify

```bash
scripts/lint-layers.sh
scripts/check-isolation.sh
./install/install.sh --dry-run --profile m0
scripts/doctor.sh
```
