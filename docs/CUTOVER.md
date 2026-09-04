# Install onto an existing Arch user

How to put this desktop on an account that already has a home directory
(not a Calamares ISO install). Stow only writes under `--target`.
System-wide files under `install/system/` stay gated (`docs/ISOLATION.md`).

## Before you start

1. Clone a **release tag**, not `dev` (`docs/GIT.md`), or use a local
   clone of this repo.
2. Archive `~/.config` and `~/.local` so you can unwind stow.
3. Dry-run first.

If `MODERN_PROTECT_HOME` is set to this home, pass `--allow-live-home`.
Unset, the guard is idle and `--target` defaults to `$HOME`.

```bash
git clone --branch v0.1.4 https://github.com/Gamesearch56/modern_dotfile.git
cd modern_dotfile
./install/install.sh --profile full --dry-run
./install/install.sh --profile full
```

`--profile m0` is enough for bar/launcher/session. `full` is what this
project's extra-user testing used.

Then disable leftover bar/notification user units (for example
`waybar.service`), uninstall packages this desktop replaced (see below),
log out of the current graphical session, and start this one with
`start-hyprland` (not the `Hyprland` binary). Hyprland ≥ 0.53 needs the
wrapper or the bar never appears. After a text login on VT1, the stowed
`.bash_profile` execs `start-hyprland`. Disable getty autologin if you
want a password prompt at boot (`scripts/autologin-apply.sh disable`
does not remove a pre-existing `getty@tty1` `override.conf`).

## Packages this desktop replaces

Do not `-Rns` anything listed in `install/manifests/`. Confirm with
`scripts/snapshot-packages.sh --diff`. Typical leftovers from a previous
Hyprland bar/launcher/notification stack:

```bash
sudo pacman -Rns \
  waybar swaync rofi \
  wallust \
  hyprlock hyprpaper hyprpolkitagent \
  woff2-font-awesome \
  qt5-graphicaleffects qt5-quickcontrols2
```

Panel applets Settings already covers (optional):

```bash
sudo pacman -Rns \
  network-manager-applet nm-connection-editor \
  blueman pavucontrol
```

If `-Rns` wants to drop a reverse dependency you still need, abort and
use `-R` without `-s`.

`install.sh` asks for `matugen-bin` and `bibata-cursor-theme-bin`. If
this machine already has the source AUR packages (`matugen`,
`bibata-cursor-theme`), they conflict — `install_aur` treats the source
names as already satisfying the manifest and skips the `-bin` packages.

## What this does not do

- It does not enable greetd, rewrite mkinitcpio, or copy polkit helpers.
  Those are `install/system/` and ISO late only.
- It does not uninstall other compositors. Remove leftover session units
  yourself if they still start on login (`systemctl --user disable --now
  waybar.service`).
- It does not rewrite this repo's Lua/QML from Settings — Settings
  writes `config.json` only.

## Unstow

Conflict backups live under `$HOME/.local/state/modern/stow-backups`.
GNU Stow can also restore from that tree. To leave the desktop:

```bash
cd /path/to/modern_dotfile/stow
stow -D -t "$HOME" hypr shell theme kitty dolphin gtk qt bash git modern systemd xdg fontconfig fastfetch mpv imv
```

Then start another session of your choice.
