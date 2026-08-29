# Boot and session

How a graphical session starts, where the lock/login surfaces live, and
what is shared with an unprivileged greeter. Plymouth and greetd are
**gated** (`install/system/`, `docs/ISOLATION.md`).

## Session graph

```
TTY: start-hyprland   →  Hyprland (stow/hypr)
greetd (gated)        →  (same, via hyprland.desktop / UWSM)
                      │
                      ├─ autostart.lua
                      │     import WAYLAND_DISPLAY
                      │     systemctl --user restart modern-shell.service
                      │     (fallback: respawning qs -c modern child)
                      ├─ modern-shell.service  (user unit, Restart=always)
                      │     ExecStart=quickshell -c modern
                      └─ portals (xdg-desktop-portal-hyprland + gtk/kde)
```

From a TTY, always run **`start-hyprland`**, not the `Hyprland` binary.
Hyprland ≥ 0.53’s wrapper sets up crash recovery and the user session;
without it, systemd units (the bar) start with no `WAYLAND_DISPLAY`.
Optional: `uwsm start hyprland-uwsm.desktop`.

The shell unit is `stow/systemd/.config/systemd/user/modern-shell.service`:
`Restart=always` / `RestartSec=1`, `After=graphical-session.target`,
`ConditionEnvironment=WAYLAND_DISPLAY`. It is **not** `PartOf=` that
target — a TTY start without UWSM never reaches it, and `PartOf` would
stop the shell immediately.

`WantedBy=graphical-session.target` may fire before the compositor has
exported `WAYLAND_DISPLAY`; the condition makes that start a no-op
instead of a crash loop. `modules/autostart.lua` is the only owner that
starts Quickshell for a TTY session: it imports compositor env, then
`systemctl --user restart modern-shell.service` (works even if the unit
is not enabled). If the unit is not active after that, it falls back to
a respawning `qs -c modern` child
(logs: `~/.local/state/modern/quickshell.log`). Do not also `exec qs` as
a one-shot alongside the enabled unit — that was the reboot race that
left wallpaper with no bar.

Enable the unit from **inside** a running session (kitty after
`start-hyprland`), not from a text TTY that has no user bus:

```bash
systemctl --user enable modern-shell.service
```

A getty/`sudo -iu` prompt without `$XDG_RUNTIME_DIR` and
`$DBUS_SESSION_BUS_ADDRESS` cannot talk to `systemd --user`. Skip enable
and run `start-hyprland`; the wrapper starts the user session. If you
must enable from that TTY and `/run/user/$(id -u)` exists:

```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
systemctl --user enable modern-shell.service
```

Do not enable the unit on the daily-driver account while isolation is in
force.

## Shared session state

Runtime the greeter must read without touching `$HOME` lives under
`/var/lib/modern/session/` (world-readable, created by a gated
tmpfiles.d drop-in when that phase is applied). Per-user state stays in
`$XDG_STATE_HOME/modern/` and `$XDG_DATA_HOME/modern/`.

## Lock vs login vs splash

| Surface | Owner | Notes |
|---------|--------|------|
| Plymouth splash | gated theme + mkinitcpio hook | never rewrite initramfs from `install.sh` |
| greetd greeter | `stow/greeter` Quickshell | shares Session module with the shell |
| lock screen | `Modules/Session` + `WlSessionLock` | `Power.lock` → `loginctl lock-session` |

`config.json` → `design.bootScreen` chooses whether the current wallpaper
is shown on splash/lock/login.

## Portals

Preferred backends are in both:

- `stow/xdg/.config/xdg-desktop-portal/hyprland-portals.conf` (user)
- `install/system/portals/hyprland-portals.conf` (staged system copy)

FileChooser is KDE (Dolphin/Qt-first, `docs/DECISIONS.md` #5);
Screenshot and ScreenCast are Hyprland.

## Troubleshooting a black session / no bar

If the graphical session is up (wallpaper, `SUPER+B`) but you have no
terminal, do **not** wait on `SUPER+T`. From the daily-driver TTY:

1. `loginctl list-sessions` — note the `devuser` / `tty3` id
2. Optional: `loginctl terminate-session <id>`
3. `Ctrl+Alt+F4`, text login as `devuser` (not Hyprland)

Then:

```bash
pgrep -a qs; pgrep -a quickshell; pgrep -a Hyprland
systemctl --user status modern-shell.service
tail -n 80 ~/.local/state/modern/quickshell.log
qs -c modern log -t 80
ls -l ~/.config/kitty/colors.conf
```

Confirm you originally launched with `start-hyprland`, not `Hyprland`.
`scripts/doctor.sh` then `docs/TROUBLESHOOTING.md`.
