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

Hyprland ≥ 0.53 must be started with **`start-hyprland`**, not the
`Hyprland` binary. The binary skips the session wrapper: you get a
warning toast, `systemd --user` has no `WAYLAND_DISPLAY`, and
`modern-shell.service` has nowhere to draw.

- Exit the broken session (`SUPER+M` or `SUPER+Q` for a terminal), then
  from the TTY: `start-hyprland`
- `systemctl --user status modern-shell.service`
- Run `quickshell -p ~/.config/quickshell/modern` in kitty — QML errors
  go to that terminal. `Logger.error` also posts a notification toast
  on the **devuser** session (DND does not hide errors).
- Installer failures: `install/install.log` and
  `journalctl -t modern-install`
- `TypeError: … is not a function` on a singleton: the type is missing
  from `Services/qmldir` (or Commons/Widgets). See `docs/DECISIONS.md` #19
  and `AGENTS.md`

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
