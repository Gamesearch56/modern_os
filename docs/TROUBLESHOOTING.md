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
`/home/bastianweigand` unless `--allow-live-home` is passed. Live-account
cutover (rewind, then clean cut): `docs/CUTOVER.md`.

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

Wallpaper plus `SUPER+B` / `SUPER+Q` means Hyprland loaded this repo's
Lua. The bar and `SUPER+M` / `SUPER+K` need Quickshell. `SUPER+T` /
`SUPER+RETURN` always open kitty; if they do nothing, see
`~/.config/kitty/colors.conf` and `docs/THEMING.md`.

If you cannot open a terminal **inside** the session, diagnose from
another TTY (`docs/BOOT.md`):

```bash
loginctl list-sessions
# optional, from the daily-driver account:
# loginctl terminate-session <devuser-tty3-id>
```

On a text login as `devuser` (`Ctrl+Alt+F4`):

```bash
pgrep -a qs; pgrep -a quickshell; pgrep -a Hyprland
echo "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR-unset}"
ls -ld /run/user/$(id -u)
# only if /run/user/$(id -u) exists:
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
systemctl --user status modern-shell.service
tail -n 80 ~/.local/state/modern/quickshell.log
qs -c modern log -t 80
ls -l ~/.config/kitty/colors.conf
python -c "import json; print(json.load(open('$HOME/.config/modern/config.json'))['keybinds'])"
```

`systemctl --user` without those two variables fails with
`$DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR not defined`. Skip
`enable` / `daemon-reload` on that TTY and run `start-hyprland`; enable
from kitty after the bar is up.

- **One Hyprland per user.** A second TTY's `start-hyprland` does not get
  the shell if an older instance still owns `modern-shell.service`.
  Exit every leftover compositor before starting a new one.
- End a session: `SUPER+SHIFT+M`, or `loginctl terminate-session <id>`
  from another TTY. If the bar is up: `hyprctl dispatch "hl.dsp.exit()"`.
  You return to the TTY prompt; `exit` or Ctrl+D logs out. Switch back
  to the daily driver with `Ctrl+Alt+F1` or `F2`.
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
  Confirm `//@ pragma IconTheme Papirus-Dark` in `shell.qml`. After restow,
  `reload_ui` / `modern ui reload` reloads Hyprland, hyprbars, hypridle,
  Quickshell, and kitty colors. Quickshell only: `modern shell reload`.
  Or kill the `qs -c modern` process. Packages: `papirus-icon-theme`,
  `qt6-svg`, `bibata-cursor-theme`.

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

## Emergency overlay: `module 'modules.colors' not found`

`stow/hypr/.config/hypr/modules/colors.lua` is generated by matugen and
gitignored. Merging a commit that stopped tracking it (`git rm`) deletes
the working copy on checkout, and Hyprland used to abort the whole Lua
config. `modules/theme_colors.lua` now loads `colors.lua` when present
and otherwise applies the same border roles from `tokens.json`.

To restore the generated file after a checkout:

```bash
scripts/theme-apply.sh --skip-wallpaper
hyprctl reload
```

If matugen stops on another template, `tokens.json` plus `hyprctl reload`
is enough to leave emergency mode.

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

## hyprbars titlebars missing / "plugin loaded failed"

Hyprland has no built-in SSD. Titlebars come from the official hyprbars
plugin, loaded with `hyprpm` so the build matches the running compositor.
`scripts/doctor.sh` warns when `hyprctl plugin list` does not mention
hyprbars.

Two separate failures look similar on a fresh session:

1. **Unknown config key `plugin hyprbars.*`** — `modules/titlebar.lua`
   (and generated `colors.lua`) used to call `hl.config({ plugin = {
   hyprbars = … }})` at parse time. Those keys do not exist until the
   plugin is loaded, so Hyprland puts them on the error overlay. Config
   is now applied only when `hl.plugin.hyprbars` is present. hyprbars
   reloads config from `PLUGIN_INIT`, so a later `hyprpm reload` picks
   the options up without a second hand reload.
2. **`plugin loaded failed` / `ensureStateStoreExists: Failed to run a
   superuser cmd`** — hyprpm keeps plugins under `/var/cache/hyprpm/$USER`
   and uses pkexec to create that tree. Autostart cannot type a password,
   so `hyprpm reload -n` is skipped until that directory exists. Run the
   following **in a terminal** (polkit prompt) once per account:

```bash
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm enable hyprbars
hyprpm reload
```

`modules/permissions.lua` allows `/usr/(bin|local/bin)/hyprpm` to load
`.so` plugins. Permission rules apply only at compositor start — restart
Hyprland after the first `hyprpm add`, then the session autostart reload
will succeed.

Settings → Windows (`windows.titlebar`) also gates the plugin options in
`modules/titlebar.lua`. Fullscreen and overlay windows set
`hyprbars:no_bar` only when the plugin is loaded — that effect is not a
built-in `hl.window_rule` field, so applying it with no plugins loaded
fills the error overlay (`unknown field 'hyprbars:no_bar'`). The dim
effect is `dim_around`, not `dimaround`. Qt apps set
`QT_WAYLAND_DISABLE_WINDOWDECORATION=1` so they do not draw a second
CSD under the SSD.

## App Store hangs on “Waiting for confirmation” with no password window

`pkexec` talks to Phylax (`phylax.service`). Phylax needs `XDG_SESSION_ID`
in the user manager (autostart imports it; the unit falls back to
`loginctl show-user Display`). If the unit is down or a leftover
`hyprpolkitagent` is still registered, no dialog maps and the store
overlay waits forever. Clear it:

```bash
systemctl --user stop hyprpolkitagent.service
systemctl --user reset-failed phylax.service
systemctl --user start phylax.service
pkexec true
```

`scripts/doctor.sh` warns when Phylax is not active. Install/remove
from the store starts the agent first; Cancel is safe only while still
waiting for the prompt (not after pacman has started writing).

## Polkit prompt is light / unthemed / tiled

Phylax is GTK4. Colors, type, and radii live in
`~/.config/phylax/style.css` (written by `theme-apply.sh`). CSS
hot-reloads when the next dialog maps. Hyprland floats
`class:io.github.jakebgrant.phylax` with `dim_around`. By hand:

```bash
scripts/theme-apply.sh
pkexec true
# preview chrome without a real auth:
PHYLAX_DEMO=1 phylax
```

A missing `style.css` falls back to unstyled GTK defaults. Wrong-password
text uses the `error` token. If the window tiles, the `polkit-auth-dialog`
rule did not match — check `hyprctl clients` for the app_id. Confirm
looking unfilled next to an outlined Cancel is Adwaita `background-image`
winning; re-run `scripts/theme-apply.sh --chrome-only`. The dialog always
authenticates as the logged-in user — if Confirm still names a different
admin, `~/.local/bin/phylax` is missing (`scripts/build-phylax.sh`).
Tab and arrows cycle password → Cancel → Confirm; they only reach Phylax
after the window takes the keyboard (the rule sets `focus_on_activate`
and `stay_focused` so Settings does not keep the keys while the cursor
stays over it). Rebuild the agent after changing that keyboard handling.

## Firewall page does not ask for a password

Settings → Firewall reads `/etc/ufw` as the user (`scripts/ufw-status.sh`).
A password prompt should appear only for enable, disable, add, or delete.
Enable/disable is one `pkexec` of `scripts/ufw-apply.sh`; add/delete use
`pkexec /usr/bin/ufw`. Those actions use `org.freedesktop.policykit.exec`
(`auth_admin`). Opening the page no longer calls `pkexec`. Four stacked
`pkexec` calls used to open a new Phylax window after every successful
password — that is a bug, not keep-alive.

Phylax only handles **one** auth cookie at a time: a second `pkexec`
(Firewall while the store prompt is still up) is ignored and the mutate
hangs with no window. Check with `pkexec /usr/bin/ufw status numbered`
in a terminal.

## Dolphin is light / has a File menu / ignores the wallpaper palette

`hl.env` only applies when Hyprland *starts*. After a reload, SUPER+E
was launching Dolphin without `qt6ct`, so Fusion fell back to a light
palette. SUPER+E now goes through `scripts/modern-launch`. Fully quit
Dolphin (not only the window) and open it again. `theme-apply.sh` writes
absolute paths into `qt6ct.conf` (qt6ct does not expand `~`). The menu
bar is hidden from `[MainWindow] MenuBar=Disabled` in `dolphinrc`.

The file view fills from **QPalette Base**. KF6's KColorSchemeManager
does not use qt6ct's palette: off Plasma, `ColorScheme::Unknown` (qt6ct)
maps to the built-in **light** scheme, so a focused Dolphin goes white
while the unfocused window still shows our dark Inactive colors. Set
`[UiSettings] ColorScheme=modern` in kdeglobals (and
`style=qt6ct-style`), leave `stylesheets=` empty, keep `#AARRGGBB` in
`modern.conf`. Fully quit Dolphin after `theme-apply.sh`. Super+E uses
`scripts/modern-launch`.

## Tiny crunchy UI on 1440p HDR

Settings → Displays: pick the monitor **by description**, set scale to
**1.25** (typical 27″ 1440p). Do not set `QT_SCALE_FACTOR`. Default
theme is `tonal-spot-dark`; HDR toggle also writes `sdrsaturation` ~0.9.
Fontconfig (`stow/fontconfig`) uses antialias + hintslight. Monitor OSD
game/DCI-P3/HDR modes are out of repo.

## Super+Q closes the wrong thing

`modern window close` dismisses the screenshot HUD, bar popups, the
control panel, and Quick Look first. Settings, launcher, wallpaper, cheatsheet, power
menu, and overview are Hyprland windows — Super+Q then `killactive` on
the focused one.

## Vivaldi still looks stock

Enable CSS mods once at `vivaldi://experiments`. Chrome colors come from
`theme-apply.sh` (`00-modern.css`). Native Preferences merge is skipped
while Vivaldi is running.

## German layout: Super+Shift+1 does nothing

Shift+1 is `!` on `de`. Lua also binds physical keycodes `code:10`–`19`
when `input.kbLayout` is `de`.

## HDR wallpaper looks neon

Keep desktop `cm = srgb` unless Displays HDR is on. Default profile is
tonal-spot, not expressive. `design.surfaceTint` default is 0.7.

