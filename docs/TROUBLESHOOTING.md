# Troubleshooting

Start with `scripts/doctor.sh` — it never mutates the machine. Critical
missing repo files exit 1; everything else is a warning and exit 0.

## Isolation / wrong account

Symptoms: `~/.config` on the daily-driver account changed; unexpected
symlinks.

```bash
scripts/check-isolation.sh
```

See `docs/ISOLATION.md` and `README.md` (second TTY). Stow only as
`devuser`, or with `--target /home/devuser`. `install.sh` refuses
`/home/bastianweigand` unless `--allow-live-home` is passed.

To return to the main session without reboot: `Ctrl+Alt+F1` or `F2`.
Do not enable greetd while testing. Shell `Logger.error` toasts appear
only on the session that is running Quickshell (`devuser`), not on the
daily-driver desktop.

## Stow aborted on `.bashrc`

`useradd -m` copies `/etc/skel/.bashrc` into the new home. GNU Stow
refuses to replace that regular file. `install/lib/stow.sh` moves those
files to `$TARGET/.local/state/modern/stow-backups/` before stowing.
Re-run `./install/install.sh --profile full` as `devuser` (idempotent).

If a re-run logged hundreds of "backing up" lines under `.config/hypr`
or `quickshell`, an older walker treated Stow folded directories as
conflicts and may have moved files out of the git clone. Restore with
`git checkout -- stow/` in `~/modern_dotfile`, then re-run install.
Current stow.sh skips paths that already resolve inside the package and
uses `--no-folding`.

## `theme-apply.sh` unknown argument `--initial`

That flag never existed. Phase 5 now runs
`theme-apply.sh --profile fixed-brand --no-reload` when no wallpaper is
set, and does not abort the install if matugen fails.

```bash
cd ~/modern_dotfile
git pull
./install/install.sh --profile full
# or only the missing step:
scripts/theme-apply.sh --profile fixed-brand --no-reload
```

Then pick a wallpaper: `scripts/theme-apply.sh --wallpaper /path/to/image.jpg`

## Shell does not start / no top bar

Wallpaper plus `SUPER+T` / `SUPER+B` / `SUPER+Q` means Hyprland loaded
this repo's Lua. The bar and `SUPER+M` / `SUPER+K` need Quickshell.

- **One Hyprland per user.** A second TTY's `start-hyprland` does not get
  the shell if an older instance still owns `modern-shell.service`.
  Exit every leftover compositor before starting a new one.
- End a session: `SUPER+T`, then `hyprctl dispatch "hl.dsp.exit()"`. You return to
  the TTY prompt; `exit` or Ctrl+D logs out of that TTY. Switch back to
  the daily driver with `Ctrl+Alt+F1` or `F2`.
- Extra `devuser` sessions: `loginctl list-sessions`, then
  `loginctl terminate-session <id>` from the daily-driver account, or as
  `devuser` on a TTY: `pkill -x Hyprland`.
- After restow, autostart runs `qs -c modern` as a child of *this*
  compositor and **stops** `modern-shell.service` so a leftover TTY
  cannot steal `WAYLAND_DISPLAY`. Leave that user unit disabled on
  TTY-started Hyprland; `scripts/doctor.sh` treats "not enabled" as
  expected in that setup. Bare `qs ipc` talks to a `default` config that
  does not exist — keybinds use `qs -c modern ipc call …`. QML errors:
  `qs -c modern log -t 80` or `~/.local/state/modern/quickshell.log`.
- `TypeError: … is not a function` on a singleton: missing `qmldir`
  entry. See `docs/DECISIONS.md` #19.
- Broken-image / purple-black checkerboard icons: Papirus-Dark must be
  the active Qt/Quickshell theme, not only installed. Hyprland
  `modules/env.lua` sets `QS_ICON_THEME` and `QT_QPA_PLATFORMTHEME=qt6ct`.
  Confirm `//@ pragma IconTheme Papirus-Dark` in `shell.qml`. Restart
  `qs` after restow (`modern shell reload` or kill the `qs -c modern`
  process). Packages: `papirus-icon-theme`, `qt6-svg`, `bibata-cursor-theme`.

## `unknown config key 'misc.vfr'` / `'dwindle.pseudotile'`

Those keys were removed in Hyprland 0.55. Current `modules/general.lua`
does not set them. Restow `stow/hypr` (or re-run `install.sh`) and
reload / restart the session.

## Wallpaper too bright / saturated on an HDR panel

Catch-all monitors use `cm = "srgb"` and `render.cm_auto_hdr = 0` so
SDR wallpapers are not mapped as HDR. Restow `stow/hypr` and restart.
Turn HDR on later from Settings → Displays (`monitors.profiles` `hdr`).
The shipped default image is still a high-chroma still; pick another
wallpaper with `scripts/theme-apply.sh --wallpaper PATH` if you want
something calmer.

## No colors / ugly defaults

`tokens.json` is optional until the first successful matugen run.
`install.sh` seeds it from the shipped default wallpaper
(`~/.config/modern/wallpapers/default.jpg`). To use another image:

```bash
scripts/theme-apply.sh --wallpaper /path/to/image
```

`scripts/doctor.sh` warns when `~/.config/modern/tokens.json` is absent.

## `secrets.json` missing

Expected until you create gitignored
`~/.config/modern/secrets.json`. Weather/AI keys do not belong in
`config.default.json`. Doctor warns; it is not fatal.

## Portal file picker / screenshot broken

Confirm `~/.config/xdg-desktop-portal/hyprland-portals.conf` is stowed
and `xdg-desktop-portal-hyprland` plus `xdg-desktop-portal-gtk` /
kde are installed. Restart: `systemctl --user restart xdg-desktop-portal`.

## KDE Connect phone does not see the PC

Ports 1714–1764 TCP/UDP. Staged rules:
`install/system/ufw/kdeconnect.rules`. Not applied by `install.sh`.

## Games stutter / Proton fails to start

See `docs/GAMING.md`: `vm.max_map_count`, file-descriptor limits,
`split_lock_mitigate`. Sysctls are gated. OptiScaler: never delete the
game `dxgi.dll` — use `scripts/optiscaler.sh remove` to restore
`.modern-optiscaler-backup/`.

## First-run wizard loops

Onboarding runs while `~/.config/modern/config.json` is missing.
`FirstRun.complete()` copies `config.default.json`. If that file was not
stowed, copy it by hand then restart the shell.

## Overview (`SUPER + TAB`) empty

Needs Hyprland toplevels over IPC. Confirm `Hypr.toplevels` in a running
session; the overlay binds `Services/Overview.open`.

## Layer lint / i18n

```bash
scripts/lint-layers.sh
```

Fails on Commons←Services imports, Modules spawning `Process`/`FileView`,
hardcoded `#hex` in QML, or keys present in only one of `en.json` /
`de.json`.
