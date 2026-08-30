# Boot and session

How a graphical session starts, where the lock/login surfaces live, and
what is shared with an unprivileged greeter. Plymouth and greetd are
**gated** (`install/system/`, `docs/ISOLATION.md`).

## Session graph

```
TTY: start-hyprland   →  Hyprland (stow/hypr)
                      │     (greetd is not shipped; future path only)
                      ├─ modern-shell.service  (user unit, watchdog)
                      │     ExecStart=quickshell -c modern
                      └─ portals (xdg-desktop-portal-hyprland + gtk/kde)
```

Autostart in Hyprland already starts Quickshell as a child of this
compositor. Enable `modern-shell.service` on the **target** user
(`devuser` while testing; the live account only after CUTOVER Phase 1).
Do not enable it on the daily-driver account while isolation is in force.

From a TTY, always run **`start-hyprland`**, not the `Hyprland` binary.
Hyprland ≥ 0.53’s wrapper sets up crash recovery and the user session;
without it, systemd units (the bar) start with no `WAYLAND_DISPLAY`.
Optional: `uwsm start hyprland-uwsm.desktop`.

The watchdog unit is `stow/systemd/.config/systemd/user/modern-shell.service`:
`Restart=always` / `RestartSec=1`, `After=graphical-session.target`.
It is **not** `PartOf=` that target — a TTY start without UWSM never
reaches it, and `PartOf` would stop the shell immediately.

```bash
systemctl --user enable modern-shell.service
```

`modules/autostart.lua` starts Quickshell as a child of this compositor
(logs: `~/.local/state/modern/quickshell.log`) so a second TTY cannot
steal the bar via the user unit.

## Shared session state

Runtime a future greeter must read without touching `$HOME` lives under
`/var/lib/modern/session/` (gated tmpfiles.d, not applied yet).
`wallpaper-sync.sh` currently writes to
`$XDG_STATE_HOME/modern/session/` when that directory is missing.
Per-user state stays in `$XDG_STATE_HOME/modern/` and
`$XDG_DATA_HOME/modern/`.

## Lock vs login vs splash

| Surface | Owner | Notes |
|---------|--------|------|
| Plymouth splash | gated theme + mkinitcpio hook | `plymouth-sync.sh`; never rewrite initramfs from `install.sh` |
| greetd greeter | `stow/greeter` stub | **Not installed.** No `install/system/greetd/`. Autologin/getty unchanged. |
| lock screen | `Modules/Session` overlay | Power menu preview. Any non-empty password unlocks. Idle/lid run `loginctl lock-session` and do **not** show the overlay. Not `WlSessionLock`. |

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
3. `qs -c modern log -t 80` or `quickshell -c modern` in a terminal — QML errors
   print there
4. `scripts/doctor.sh` then `docs/TROUBLESHOOTING.md`
