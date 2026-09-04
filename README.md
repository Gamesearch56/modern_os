# ModernOS

Material Design 3 desktop for [Arch Linux](https://archlinux.org/) +
[Hyprland](https://hypr.land/): a [Quickshell](https://quickshell.outfoxxed.me/)
(QML) shell, [`matugen`](https://github.com/InioX/matugen) for
wallpaper-derived color, and one JSON config for both the shell and
Hyprland. English and German are first-class.

This is a hobby project with one maintainer. The established desktop is
complete; further work is fixes and new features.

SPDX-License-Identifier: Apache-2.0

## Requirements

- Arch Linux, 64-bit (`x86_64`)
- A user you can log in as (ISO creates one; git install uses yours)

## Install from the ISO

1. Download the live image from
   [Releases](https://github.com/Gamesearch56/modern_dotfile/releases).
2. Boot it in a VM first (QEMU/VirtualBox). Calamares installs to disk.
3. First boot is greetd + password. Settings → Update tracks newer
   `vX.Y.Z` tags.

To rebuild the live image on this PC (writes `iso/out/` only):

```bash
sudo ./scripts/iso-build.sh --mkarchiso
./scripts/iso-qemu.sh
```

Never run `provision-iso.sh` or Calamares on the session you live in
(`docs/INSTALL.md`).

## Install from git

Clone the latest **release tag** (`vX.Y.Z` on the Releases page), not
`dev`:

```bash
git clone --branch vX.Y.Z https://github.com/Gamesearch56/modern_dotfile.git
cd modern_dotfile
./install/install.sh --profile m0 --dry-run
./install/install.sh --profile m0
```

Then start the session with `start-hyprland` (not the `Hyprland` binary).
Hyprland ≥ 0.53 needs the wrapper or the bar never appears.

`install.sh` enables greetd on a real user home. Plymouth, NVIDIA
initramfs, and the other extras under `install/system/` stay gated.

Profiles: `m0` (desktop), `dev` (+ toolchain), `gaming`, `full`.
`--target DIR` stows into another home. Optional
`MODERN_PROTECT_HOME` refuses that path unless you pass
`--allow-live-home`. Details: `docs/INSTALL.md`, `docs/ISOLATION.md`,
existing-account install: `docs/CUTOVER.md`.

`git clone` plus `install.sh` reproduces the **designed** desktop
(`config.default.json`, package manifests, stow). Displays, wallpaper,
calendar, API keys, browser profile, and SSH stay out of git. The
shipped UI is **English**; default keyboard layout is `us`.

## After install

Settings writes `config.json` only. It never rewrites Lua, QML, or
gated `/etc`. Plymouth, NVIDIA mkinitcpio, polkit `modern-usersd`, and
snapper stay under `install/system/` and are applied only by an explicit
ISO provision command.

```bash
scripts/ci-check.sh
scripts/doctor.sh
./install/install.sh --dry-run --profile m0 --target /tmp/modern-install-dryrun
```

`scripts/check-isolation.sh` is for local gated-file checks. Do not add
it to GitHub Actions.

## Docs

| | |
|---|---|
| Install paths | [`docs/INSTALL.md`](docs/INSTALL.md) |
| Git / releases | [`docs/GIT.md`](docs/GIT.md) |
| Architecture | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| Isolation | [`docs/ISOLATION.md`](docs/ISOLATION.md) |
| Keybinds | Super+K, [`docs/KEYBINDS.md`](docs/KEYBINDS.md) |
| Contributing | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| Security | [`SECURITY.md`](SECURITY.md) |

## Layout

```
modern_dotfile/
├── AGENTS.md, README.md, LICENSE, NOTICE
├── docs/           architecture, design, decisions, install & ops guides
├── install/        install.sh, manifests/, system/ (gated)
├── stow/           everything that becomes a dotfile on the target user
└── scripts/        theme-apply, doctor, isolation check, `modern` IPC CLI
```

## Keybinds (M0 defaults)

| Keys | Action |
|---|---|
| `SUPER` + `Space` | Application launcher |
| `SUPER` + `A` | AI chat |
| `SUPER` + `M` | Power menu |
| `SUPER` + `N` | Control center |
| `SUPER` + `L` | Lock (`WlSessionLock`) |
| `SUPER` + `SHIFT` + `M` | Exit compositor |
| `SUPER` + `K` | Keybind cheatsheet |
| `SUPER` + `I` | Settings |
| `SUPER` + `W` | Wallpaper picker |
| `SUPER` + `DELETE` | Applications (taskbar) |
| `SUPER` + `Tab` | Overview |
| `SUPER` + `T` | Terminal (kitty; always bound) |
| `SUPER` + `Return` | Terminal (always bound) |
| `SUPER` + `B` | Browser (Vivaldi) |
| `SUPER` + `E` | File manager (Nautilus) |
| `SUPER` + `Q` | Close window |

Full list: `SUPER`+`K`, `docs/KEYBINDS.md`, or
`stow/modern/.config/modern/config.default.json` → `keybinds`.

## License

Apache License 2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
