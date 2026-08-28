# Boot and session

How a graphical session starts, where the lock/login surfaces live, and
what is shared with an unprivileged greeter. Plymouth and greetd are
**gated** (`install/system/`, `docs/ISOLATION.md`).

## Session graph

```
TTY: start-hyprland   →  Hyprland (stow/hypr)
greetd (gated)        →  (same, via hyprland.desktop / UWSM)
                      │
                      ├─ modern-shell.service  (user unit)
                      │     ExecStart=quickshell -p %h/.config/quickshell/modern
                      └─ portals (xdg-desktop-portal-hyprland + gtk/kde)
```

From a TTY, always run **`start-hyprland`**, not the `Hyprland` binary.
Hyprland ≥ 0.53’s wrapper sets up crash recovery and the user session;
without it, systemd units (the bar) start with no `WAYLAND_DISPLAY`.
Optional: `uwsm start hyprland-uwsm.desktop`.

The watchdog unit is `stow/systemd/.config/systemd/user/modern-shell.service`:
`Restart=always` / `RestartSec=1`, `After=graphical-session.target`.
It is **not** `PartOf=` that target — a TTY start without UWSM never
reaches it, and `PartOf` would stop the shell immediately. Enable on
the **devuser** account only:

```bash
systemctl --user enable modern-shell.service
```

`modules/autostart.lua` starts the unit (or falls back to `quickshell -p`
in the compositor process) once the display is up.

Do not enable it on the daily-driver account while isolation is in
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

## Troubleshooting a black session

1. Confirm you launched with `start-hyprland`, not `Hyprland`
2. TTY login as the same user, `systemctl --user status modern-shell.service`
3. `quickshell -p ~/.config/quickshell/modern` in a terminal — QML errors
   print there
4. `scripts/doctor.sh` then `docs/TROUBLESHOOTING.md`
