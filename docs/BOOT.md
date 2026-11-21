# Boot and session

For admins and developers debugging startup: how a ModernOS session
starts from boot to desktop, where the lock and login screens live, and
which log to read at each stage.

How a graphical session starts, where the lock/login surfaces live, and
what is shared with an unprivileged greeter. Plymouth stays gated
(`install/system/`, `docs/ISOLATION.md`). Greetd is applied by
`install.sh` on a real user home.

## Session graph

```
install.sh (or Calamares late install.sh + provision-iso.sh):
  greetd (greeter kiosk)  →  start-hyprland  →  Hyprland (stow/hypr)
Getty fallback if greetd is down:
  TTY login → .bash_profile on tty1 execs start-hyprland
                              →  Hyprland (stow/hypr)
                              ├─ autostart.lua
                              │     exec scripts/shell-run.sh → qs -c modern  (compositor child)
                              ├─ modern-shell.service  (optional UWSM watchdog)
                              └─ portals (xdg-desktop-portal-hyprland + gtk/kde)
```

Greetd files live under `install/system/greetd/` and are applied by
`install/lib/greetd.sh` (called from `install.sh` and from
`provision-iso.sh`). tty1 `.bash_profile` is the fallback if greetd fails.

Autostart in Hyprland already starts Quickshell as a child of this
compositor. Enable `modern-shell.service` on the **target** user if you
want a systemd watchdog. Do not enable it on an account that should keep
a different session.

From a TTY, always run **`start-hyprland`**, not the `Hyprland` binary.
Hyprland ≥ 0.53’s wrapper sets up crash recovery and the user session;
without it, systemd units (the bar) start with no `WAYLAND_DISPLAY`.
Optional: `uwsm start hyprland-uwsm.desktop`.

**Anything meant for Hyprland goes after `--`.** `start-hyprland` is a
watchdog binary that understands only `--path`, `--no-nixgl` and
`--force-nixgl`; everything else reaches Hyprland only past the separator.
`start-hyprland --config X` silently drops the flag, so Hyprland falls back
to `$HOME/.config/hypr/hyprland.lua`, finds nothing, and autogenerates a
stock session — which is what a broken `greetd` `default_session` looks
like from the outside: plain Hyprland, no greeter, no shell, and a
`config file: //.config/hypr/hyprland.lua` warning. The double slash is the
tell that `$HOME` was `/`. The greetd command is therefore `/etc/greetd/kiosk.sh`, which re-exports
`GREETD_SOCK` (Quickshell will not connect without it) and execs
`start-hyprland --no-nixgl -- --config /etc/greetd/hyprland.lua`.
`tests/test-calamares-late.sh` asserts both. Greetd sets
`source_profile = false` so `~/.bashrc` (fastfetch) does not run on the
seat before Hyprland. The kiosk sets `ulimit -c 0` so a crash dump cannot
block reaping. Greeter wallpaper is the Quickshell Image — no `awww`
client — and `Greetd.launch` then `hyprctl dispatch "hl.dsp.exit()"` so greetd is
not left waiting on a compositor that will not die.

The `greeter` account is not ours to create. `greetd`'s own `sysusers.d`
entry leaves the home field unset, so the user already exists with `/` as
its home before `provision-iso.sh` runs and its `useradd` is skipped.
Provisioning relocates it to `/var/lib/greeter` — never with
`usermod --move-home`, which would move the whole root filesystem — and
fails loudly if the home is still `/`, because `qs -c greeter` cannot
create `/.cache` there.

The shell unit is `stow/systemd/.config/systemd/user/modern-shell.service`:
`Restart=always` / `RestartSec=1`, `After=graphical-session.target`,
`ConditionEnvironment=WAYLAND_DISPLAY`. It is **not** `PartOf=` that
target — a TTY start without UWSM never reaches it, and `PartOf` would
stop the shell immediately. TTY testing does **not** need this unit
enabled.

`modules/autostart.lua` **exec**s `scripts/shell-run.sh`, which runs
`qs -c modern` as a child of this compositor (logs: `~/.local/state/modern/quickshell.log`) **before**
wallpaper and any `systemctl --user` call. After greetd the user bus is
often still coming up; waiting on it delayed the first shell frame. Do not
wrap qs in a `while` loop: Hyprland then tracks `sh` instead of Quickshell,
and the bar never appears. systemd calls (stop a leftover unit,
import-environment, polkit) run in the background with `timeout 2`. Session
wallpaper is `awww img … --transition-type none` from the already-cropped
`/var/lib/modern/session/wallpaper.jpg` — not Lanczos3. The kiosk and
desktop set `misc.disable_hyprland_guiutils_check`: the greeter PATH is
too thin to find `hyprland-dialog`, and that overlay stays up for 15s.

Enable the unit only from **inside** a running session if you want a
UWSM/greetd watchdog — not from a text TTY, and not as a requirement
to get a bar:

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

Do not enable the unit on an account that should keep a different session.

## Shared session state

Runtime the greeter reads without touching `$HOME` lives under
`/var/lib/modern/session/` (`install/system/tmpfiles.d/modern-session.conf`,
applied by `install/lib/greetd.sh`).
`wallpaper-sync.sh` writes there when the directory exists, otherwise
`$XDG_STATE_HOME/modern/session/`.
Per-user state stays in `$XDG_STATE_HOME/modern/` and
`$XDG_DATA_HOME/modern/`.

## Lock vs login vs splash

| Surface | Owner | Notes |
|---------|--------|------|
| Plymouth splash | gated theme + mkinitcpio hook | Solid installer colors, a large ModernOS word, and a spinner under it. Quit keeps that frame (`--retain-splash`) so a laptop does not draw the seat terminal before the next Hyprland paints. Login, logout, and power actions start `modern-splash.service` first. Hyprland's banner goes to a log. A system update and `provision-iso.sh` enable it. The initramfs is rebuilt only when the theme or the hook changed. Palette generation and wallpaper changes do not. |
| greetd greeter | `stow/greeter` + `install/system/greetd/` | Applied by `install.sh` on a real user home (`install/lib/greetd.sh`). tty1 `.bash_profile` is the fallback if greetd is down. |
| lock screen | `Modules/Session` + `WlSessionLock` | Power menu, idle, and lid run `qs -c modern ipc call session lock`. One `WlSessionLockSurface` per output; `Session.password` is shared. Unlock is PAM (`system-auth`) for the session user, then `loginctl unlock-session`. Backdrop is the synced blur plus `design.transparency`. |

`config.json` → `design.bootScreen` chooses whether the current wallpaper
is shown on the lock screen and the login screen. The boot splash stays
the solid installer colors.

### Lock safeguards

- **Sleep waits for the lock.** hypridle runs with `inhibit_sleep = 3`,
  so suspend is held until Hyprland reports the session lock. `modern
  power suspend|hibernate` (power menu, lid, button) also locks first and
  waits up to three seconds for the `session secured` IPC. If the shell
  never confirms, it writes the locked marker, logs under `modern-power`
  and sleeps, so the next shell start comes up locked.
- **The shell is supervised.** `scripts/shell-run.sh` starts `qs -c
  modern` and restarts it after a crash. Hyprland keeps a crashed lock
  locked (`misc:allow_session_lock_restore`), and the new shell reads the
  marker and takes the lock over. A clean exit, a gone compositor or five
  crashes in two minutes stop the loop.
- **Failures are logged.** The shell logs lock requests, compositor
  confirmation (or its absence after three seconds), PAM error text
  (e.g. faillock) and unlocks to `quickshell.log`.

### Logs along the chain

| Stage | Where |
|-------|-------|
| Boot entry, splash, greetd | `journalctl -b -u plymouth-start -u modern-splash -u modern-boot-confirm -u greetd` |
| Login screen | `/var/lib/modern/session/greeter.log` (greeter shell), `auth-trace.json` (last 20 auth events, no password data) |
| Desktop session | `~/.local/state/modern/hyprland.log` (one `== desktop session` header per login) |
| Shell and lock | `~/.local/state/modern/quickshell.log` (moved to `.log.1` at login once past 5 MB), journal tag `modern-shell` |
| Idle and sleep | `~/.local/state/modern/hypridle.log`, journal tag `modern-power` |
| Logout, reboot, power off | journal tag `modern-session` (request and any refusal) |
| Last shutdown | `journalctl -b -1 -n 300` |

The bug report's "Startup, login, lock & shutdown" area collects all of
these into `session.txt` and `boot.txt`.

## Portals

Preferred backends are in both:

- `stow/xdg/.config/xdg-desktop-portal/hyprland-portals.conf` (user)
- `install/system/portals/hyprland-portals.conf` (staged system copy)

FileChooser is the KDE portal (Qt apps). Folders open in the
ModernOS File Manager (`docs/DECISIONS.md` #5).
Screenshot and ScreenCast are Hyprland.

## Troubleshooting a black session / no bar

If the graphical session is up (wallpaper, `SUPER+B`) but you have no
terminal, try `SUPER+RETURN` (emergency `/usr/bin/kitty`). Do **not**
wait only on `SUPER+T` if `modern-launch` is broken. From another
TTY:

1. `loginctl list-sessions` — note the session id for this user
2. Optional: `loginctl terminate-session <id>`
3. `Ctrl+Alt+F4`, text login as the same user (not Hyprland)

Then:

```bash
pgrep -a qs; pgrep -a quickshell; pgrep -a Hyprland; pgrep -af shell-run.sh
systemctl --user status modern-shell.service
tail -n 80 ~/.local/state/modern/quickshell.log   # shell-run: lines = restarts
qs -c modern log -t 80
ls -l ~/.config/kitty/colors.conf
```

Confirm you originally launched with `start-hyprland`, not `Hyprland`.
`scripts/doctor.sh` then `docs/TROUBLESHOOTING.md`.
