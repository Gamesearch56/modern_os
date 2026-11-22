# Installing Cursor

Optional developer tooling: how to install the Cursor editor on a
ModernOS system and open this repository with its agent rules. End users
do not need it.

Cursor is installed as `cursor-bin` from the AUR. No install profile
ships it; add it yourself.

## 1. With yay (recommended)

`install.sh` already bootstraps `yay` for every profile:

```bash
yay -S --needed cursor-bin
```

Skip to step 4.

## 2. Manual install (if you want Cursor before anything else)

```bash
# yay must exist first — install.sh normally does this for you
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
cd /tmp/yay-bin && makepkg -si --noconfirm

# then Cursor itself
yay -S --needed cursor-bin
```

## 3. First launch

```bash
cursor
```

Launch it once Hyprland is running so the GUI opens on the desktop. On
a session without a working sandbox, `cursor --no-sandbox` is the
fallback (see Troubleshooting).

## 4. Sign in and open the repo

1. Sign in with your Cursor account (settings sync is optional).
2. `File > Open Folder` → your clone of this repository.
3. Cursor picks up `.cursorrules` and `AGENTS.md` automatically —
   verify by asking it "what are the layer rules in this repo?" and
   checking the answer matches `AGENTS.md`.

## 5. Recommended settings for this project

- Enable "Format on Save" for `.qml`/`.lua`/`.sh` if you add formatters
  later (none are wired up — `scripts/lint-layers.sh` is the
  enforcement mechanism, not a formatter).
- Terminal default shell: `bash` (matches `stow/bash/.bashrc`).
- If you use Cursor's own settings sync, check nothing there assumes
  paths from another machine's layout.

## 6. Quick check

- `yay -S cursor-bin` completes without error
- `cursor` opens a window under Hyprland
- Cursor opens your clone and shows the same file tree as the repo
- `.cursorrules` is detected (ask Cursor to summarize it)
- An edit and save round-trips with no permission errors in `$HOME`

## Troubleshooting

- **Electron sandbox errors on Wayland** — add
  `--ozone-platform=wayland` via a `cursor.desktop` override, or launch
  with `cursor --no-sandbox` as a fallback (less secure; prefer the
  Wayland flag first).
- **AUR build fails on `base-devel` missing a piece** — `sudo pacman -S
  base-devel` again; individual split packages sometimes get pruned from
  a minimal `base` install.
- **No `$DISPLAY`/`$WAYLAND_DISPLAY`** — you're on a bare TTY with no
  compositor running yet. Either finish Hyprland setup first, or
  install Cursor headlessly and launch it once Hyprland is up.
