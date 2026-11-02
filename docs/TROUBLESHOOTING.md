# Troubleshooting

Start with `scripts/doctor.sh` — it never mutates the machine. Critical
missing repo files exit 1; everything else is a warning and exit 0.

## Login screen: “Unable to send Message: Connection refused”

Quickshell’s greetd client only connects when `GREETD_SOCK` is set on
`qs -c greeter`. Hyprland’s `exec` of qs does not inherit that socket
unless `/etc/greetd/kiosk.sh` and `/etc/greetd/hyprland.lua` forward it
(`install/lib/greetd.sh`). Re-run `./install/install.sh` on this home,
then sign out — do not start `qs` by hand from a TTY; that process has
no socket.

If tty1 is a wallpaper-only greeter with no form, or the form has empty
fields (no clock, no user list, no Sign in label), Stow did not update
`/var/lib/greeter`. Copy the package and restart greetd from a session
or another VT (`Ctrl+Alt+F3`):

```bash
sudo rm -rf /var/lib/greeter/.config/quickshell/greeter
sudo cp -a stow/greeter/.config/quickshell/greeter \
    /var/lib/greeter/.config/quickshell/greeter
sudo chown -R greeter:modern /var/lib/greeter/.config
sudo install -D -m 0644 install/system/greetd/50-modern-greeter.rules \
    /etc/polkit-1/rules.d/50-modern-greeter.rules
sudo install -m 0644 install/system/greetd/hyprland.lua /etc/greetd/hyprland.lua
sudo install -m 0755 install/system/greetd/kiosk.sh /etc/greetd/kiosk.sh
sudo chmod 0664 /var/lib/modern/session/default-user
sudo systemctl restart greetd
```

Then `Ctrl+Alt+F1`. Stopping greetd lets `getty@tty1` come back
(`Conflicts=`). `./install/install.sh` does this copy as part of
`greetd_apply`.

## Isolation / wrong account

Symptoms: `~/.config` on an account you did not pass as `--target`
changed; unexpected symlinks.

```bash
scripts/check-isolation.sh
```

See `docs/ISOLATION.md`. Stow into `$HOME` or `--target`. If
`MODERN_PROTECT_HOME` is set, `install.sh` refuses that path unless
`--allow-live-home` is passed. Existing-account install: `docs/CUTOVER.md`.

To return to another session without reboot: `Ctrl+Alt+F1` or `F2`.
`install.sh --target` on a real home also enables greetd for this
machine. Shell `Logger.error` toasts appear only on the session that
is running Quickshell.

## Nautilus “No Home Directory” / “Kein Persönlicher Ordner”

The title is a mistranslation. Nautilus 50 checks that
`~/.config/nautilus` is a directory (`nautilus_get_user_directory`, then
`g_file_test (…, G_FILE_TEST_IS_DIR)`). A leftover GNU Stow symlink
into an old clone (`~/.config/nautilus -> ../dotfiles/nautilus/…`) that
no longer exists fails that check on every start. `$HOME` itself is
fine. `scripts/nautilus-prefs.sh` replaces a dangling link with a real
directory.

## Stow aborted on `.bashrc`

`useradd -m` copies `/etc/skel/.bashrc` into the new home. GNU Stow
refuses to replace that regular file. `install/lib/stow.sh` moves those
files to `$TARGET/.local/state/modern/stow-backups/` before stowing.
Re-run `./install/install.sh --profile full` as the target user (idempotent).

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
`SUPER+RETURN` open kitty through `~/.local/bin/kitty-open`. That tries
Wayland, then XWayland, then software GL. If nothing appears, see
`~/.local/state/modern/kitty-open.log`. A missing theme is not fatal
(`kitty.conf` globincludes `colors.conf`).

If you cannot open a terminal **inside** the session, diagnose from
another TTY (`docs/BOOT.md`):

```bash
loginctl list-sessions
# optional, from another account:
# loginctl terminate-session <id>
```

On a text login as the same user (`Ctrl+Alt+F4`):

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
  Exit every leftover compositor before starting a new one. Login from
  greetd while another graphical session is still on F2 also steals DRM
  and can look like a 20s hang plus an immediate lock screen.
- **Login to session feels slow.** The greeter compositor must die
  before yours starts. If `awww-daemon` dumps a core, that wait is
  seconds of black. Current `kiosk.sh` disables coredumps for that
  session. Restow `hypr` so session restore skips Lanczos3.
- End a session: `SUPER+SHIFT+M`, or `loginctl terminate-session <id>`
  from another TTY. If the bar is up: `hyprctl dispatch "hl.dsp.exit()"`.
  You return to the TTY prompt; `exit` or Ctrl+D logs out. Switch back
  with `Ctrl+Alt+F1` or `F2`.
- Extra sessions for the same user: `loginctl list-sessions`, then
  `loginctl terminate-session <id>` from another account, or on a TTY:
  `pkill -x Hyprland`.
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
  `reload_ui` / `modern ui reload` reloads Hyprland, hypridle,
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
The greetd kiosk applies the same `monitors.profiles` snapshot
(`wallpaper-sync.sh` → `/var/lib/modern/session/monitors.json`) so login
matches the session on wide-gamut panels. Copy
`install/system/greetd/hyprland.lua` to `/etc/greetd/hyprland.lua` after
changing that file. The shipped default image is still a high-chroma
still; pick another wallpaper with `scripts/theme-apply.sh --wallpaper PATH`
if you want something calmer.

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

## Update says offline while the repo is still private

HTTPS cannot see a private repo. The laptop needs the read-only deploy
key at `~/.config/modern/deploy_key` (mode 600), and that public key
registered under GitHub → Settings → Deploy keys with write access off.
`scripts/deploy-key-init.sh` creates it; the ISO build embeds it.
Details: `docs/GIT.md`.

## `secrets.json` missing

Expected until you create gitignored
`~/.config/modern/secrets.json`. Weather/AI keys do not belong in
`config.default.json`. Doctor warns; it is not fatal.

## Portal file picker / screenshot broken

Confirm `~/.config/xdg-desktop-portal/hyprland-portals.conf` is stowed
and `xdg-desktop-portal-hyprland` plus `xdg-desktop-portal-gtk` /
kde are installed. Restart: `systemctl --user restart xdg-desktop-portal`.

Vivaldi does not use the desktop keyring. Sign-in starts the session
without a typed password, so that keyring stays locked and the browser
would ask for a new one, then refuse the profile. `scripts/vivaldi`
uses the basic store instead and drops the old keystore canary once.
Bookmarks and history stay. Saved passwords and site logins that were
sealed with the keyring are not opened.

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

## Browser covers the workspace after a video (Vivaldi / Chromium)

HTML5 video fullscreen, then exit (or click another workspace): Chromium
sends `set_maximized`, Hyprland treats that as `fullscreen: 1`, and the
browser fills the monitor over other tiles. Fixed by the default window
rule `suppress-client-maximize` in `modules/windowrules.lua` (Hyprland
discussion #13322). Reload Hyprland after updating. Immediate recovery:

```bash
hyprctl dispatch fullscreenstate 0 0
```

## hyprbars / compositor titlebars

This desktop does not ship hyprbars. Move with Super+left drag, resize
from the window edge, and use Applications (right-click) for float,
fullscreen, togglesplit, and close. Leftover `hyprbars:no_bar` keys in
`windowRules` are ignored so they do not fill the Hyprland error overlay.
The dim effect is `dim_around`, not `dimaround`.

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

## Qt apps are light / ignore the wallpaper palette

`hl.env` only applies when Hyprland *starts*. After a reload, launch
through `scripts/modern-launch` so `qt6ct` is in the environment.
`theme-apply.sh` writes absolute paths into `qt6ct.conf` (qt6ct does not
expand `~`). Fully quit the Qt app after `theme-apply.sh`.

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

`theme-apply.sh` writes `custom_css` and, when Vivaldi is not running,
seeds `Preferences` (`themes.current=modern`, CSS mods directory) plus
`Local State` (`vivaldi-css-mods@1`). Re-run it after quitting the
browser if the first launch created a stock profile. Chrome colors come
from `00-modern.css`. A leftover `custom_css/00-wallust.css` pins old
tab and URL-bar colors — `theme-apply.sh` deletes it. Fully quit Vivaldi
once after a wallpaper change so the native `modern` theme object can
be rewritten.

## German layout: Super+Shift+1 does nothing

Shift+1 is `!` on `de`. Lua also binds physical keycodes `code:10`–`19`
when `input.kbLayout` is `de`.

## HDR wallpaper looks neon

Keep desktop `cm = srgb` unless Displays HDR is on. Default profile is
tonal-spot, not expressive. `design.surfaceTint` default is 0.7.

