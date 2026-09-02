# Install onto an existing Arch user

How to put this desktop on an account that already has a home directory
(not a Calamares ISO install). Stow only writes under `--target`.
System-wide files under `install/system/` stay gated (`docs/ISOLATION.md`).

## Before you start

1. Clone a **release tag**, not `dev` (`docs/GIT.md`).
2. Optional: archive `~/.config` and `~/.local` so you can unwind stow.
3. Dry-run first.

If `MODERN_PROTECT_HOME` is set to this home, pass `--allow-live-home`.
Unset, the guard is idle and `--target` defaults to `$HOME`.

```bash
git clone --branch v0.1.4 https://github.com/Gamesearch56/modern_dotfile.git
cd modern_dotfile
./install/install.sh --profile m0 --dry-run
./install/install.sh --profile m0
```

Then log out of the current graphical session and start this one with
`start-hyprland` (not the `Hyprland` binary). Hyprland ≥ 0.53 needs the
wrapper or the bar never appears.

## What this does not do

- It does not enable greetd, rewrite mkinitcpio, or copy polkit helpers.
  Those are `install/system/` and ISO late only.
- It does not uninstall other compositors or bars. Remove leftover
  session units yourself if they still start on login.
- It does not rewrite this repo's Lua/QML from Settings — Settings
  writes `config.json` only.

## Unstow

Conflict backups live under `$HOME/.local/state/modern/stow-backups`.
GNU Stow can also restore from that tree. To leave the desktop:

```bash
cd /path/to/modern_dotfile/stow
stow -D -t "$HOME" hypr shell theme kitty dolphin gtk qt bash git modern systemd xdg fontconfig fastfetch mpv imv
```

Then start whatever session you used before.
