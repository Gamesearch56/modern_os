# Installing Cursor on `devuser`

Cursor is installed as `cursor-bin` from the AUR — this is what
`install/manifests/40-dev.aur.txt` lists.

## 1. Via the installer (recommended)

```bash
cd ~/modern_dotfile
./install/install.sh --profile dev
```

This bootstraps `yay` if needed, then installs `cursor-bin` along with the
rest of the `40-dev` layer. Skip to step 4.

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

On a fresh `devuser` with no display session yet, run this over SSH or a
TTY with `cursor --no-sandbox` if the Wayland/X11 session isn't up yet —
but normally you'll do this after Hyprland is running so the GUI launches
on the real desktop.

## 4. Sign in and open the repo

1. Sign in with your Cursor account (settings sync is optional).
2. `File > Open Folder` → `~/modern_dotfile`.
3. Cursor should pick up `.cursorrules` and `AGENTS.md` automatically —
   verify by asking it "what are the layer rules in this repo?" and
   checking the answer matches `AGENTS.md`.

## 5. Recommended settings for this project

- Enable "Format on Save" for `.qml`/`.lua`/`.sh` if you add formatters
  later (none are wired up yet — `scripts/lint-layers.sh` is the current
  enforcement mechanism, not a formatter).
- Terminal default shell: `bash` (matches `stow/bash/.bashrc`).
- If you use Cursor's own settings sync, check nothing there assumes
  paths from another machine's layout.

## 6. Live-verification checklist

This guide is marked "live-verified" in `docs/DECISIONS.md`'s milestone
tracking once each of these has actually been done on `devuser`, not just
read:

- [ ] `yay -S cursor-bin` completes without error on a real `devuser` session
- [ ] `cursor` launches a window under Hyprland
- [ ] Cursor opens `~/modern_dotfile` and its file tree matches this repo
- [ ] `.cursorrules` is detected (ask Cursor to summarize it)
- [ ] A trivial edit + save round-trips correctly (no permission issues on
      a freshly-created `$HOME`)

Until these boxes are checked by hand on real hardware, treat this guide
as "should work, not yet flown" — see `README.md`.

## Troubleshooting

- **AppImage/Electron sandbox errors on Wayland** — add
  `--ozone-platform=wayland` via a `cursor.desktop` override, or launch
  with `cursor --no-sandbox` as a fallback (less secure; prefer the
  Wayland flag first).
- **AUR build fails on `base-devel` missing a piece** — `sudo pacman -S
  base-devel` again; individual split packages sometimes get pruned from
  a minimal `base` install.
- **No `$DISPLAY`/`$WAYLAND_DISPLAY`** — you're on a bare TTY with no
  compositor running yet. Either finish Hyprland setup first, or
  install/verify Cursor headlessly and launch it once Hyprland is up.
