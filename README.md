# modern_dotfile

A from-scratch Material Design 3 desktop environment for Arch Linux +
Hyprland: a [Quickshell](https://quickshell.outfoxxed.me/) (QML) shell
replaces Waybar, SwayNC and Rofi; [`matugen`](https://github.com/InioX/matugen)
replaces Wallust for dynamic, wallpaper-derived color; one JSON config file
drives both the shell and Hyprland's Lua config. German and English are
both first-class throughout.

Two install paths exist:

- **This machine (now):** keep using `bastianweigand` as the daily driver.
  Create `devuser`, install *only* into that home, and start Hyprland on a
  **second TTY** so the current session is never replaced.
- **New PC / bare metal:** `scripts/bootstrap.sh` (print-only until you
  pass `--yes --disk`) then `install/install.sh` as the new user.

Full plan: `docs/ARCHITECTURE.md`. Isolation rules: `docs/ISOLATION.md`.

## Status

The shell, installer, token pipeline and Settings modules are in the
repo and internally consistent (`scripts/lint-layers.sh`). They have
**not** been lived as a daily session yet. Package installs are additive
(pacman has no per-user scope). Everything that would change boot, login,
or `/etc` lives under `install/system/` and is **never** applied by
`install.sh`.

| Milestone | Scope | Code |
|---|---|---|
| M0 | Bar, launcher, power menu, cheatsheet, Vivaldi, Cursor on `devuser` | present |
| M1 | Lock/login/shutdown, Plymouth (gated), notifications, GTK/Qt/Vivaldi | present |
| M2 | Wallpaper picker, media/performance/weather/VPN/notes widgets | present |
| M3 | Settings app | present |
| M4 | Gaming: OptiScaler, profiles, perf sysctls (gated) | present |
| M5 | Watchdog, portals, IPC CLI, KDE Connect, backups, bootstrap, onboarding | present |
| M6 | Personal layer, plugins, extras | present |

Hand-check remaining items: `docs/TROUBLESHOOTING.md` and the milestone
notes in `docs/DECISIONS.md`.

## Safety — testing will not replace your current session

If you follow the **this machine** path below and **do not** apply
`install/system/` (greetd, Plymouth/mkinitcpio, sysctl, polkit, ufw,
snapper, ESP hook):

- `install.sh` **refuses** to stow into `/home/bastianweigand` (even
  `--dry-run`). Override only with `--allow-live-home` for a deliberate
  cutover, not for testing.
- Stow backups go under the *target* home, never into the daily-driver
  `$HOME`.
- Creating `devuser` does **not** change autologin. Your existing
  graphical session stays on TTY1/TTY2.
- Coming back: `Ctrl+Alt+F1` or `F2` — the `bastianweigand` session is
  still running. Log out of the `devuser` Hyprland if you started one;
  that does not log you out of the main account.
- Optional rollback of the test account only:
  `sudo userdel -r devuser` (deletes `/home/devuser`; does not touch
  `/home/bastianweigand`).

The one machine-wide side effect of a real (non-dry-run) install is
**packages**: pacman/yay install is system-wide and additive. It will not
remove anything the daily driver uses. The existing
`/etc/pacman.d/hooks/package_list.hook` will rewrite lists in the *old*
`~/dotfiles` repo — leave that hook alone and ignore the diff. See
`docs/ISOLATION.md`.

**Do not run** while testing:

```text
sudo systemctl enable greetd
# anything that copies install/system/ into /etc
# install.sh without --target if you are logged in as bastianweigand
# install.sh --allow-live-home
```

Verify from this account before and after:

```bash
scripts/check-isolation.sh
```

## This machine — install and switch to `devuser`

Your home is mode `700`, so `devuser` cannot read this checkout. Clone a
**copy** as `devuser`. Prefer a second TTY so you never log out of
`bastianweigand`.

### 1. Create the test account (gated, once)

From `bastianweigand`:

```bash
cd /home/bastianweigand/CursorProjects/modern_dotfile
scripts/check-isolation.sh
sudo install/system/create-devuser.sh
```

Set a password when asked. Rollback: `sudo userdel -r devuser`.

### 2. Clone and install **as `devuser`**

```bash
sudo -iu devuser
git clone git@github.com:Gamesearch56/modern_dotfile.git ~/modern_dotfile
# or: git clone https://github.com/Gamesearch56/modern_dotfile.git ~/modern_dotfile
cd ~/modern_dotfile
./install/install.sh --profile m0 --dry-run
./install/install.sh --profile m0
```

Use `--profile dev` if you want Cursor on that account
(`docs/CURSOR-SETUP.md`).

If you must run the installer from `bastianweigand` instead, you still
cannot target your own home:

```bash
./install/install.sh --profile m0 --target /home/devuser --dry-run
```

That only works if `devuser`'s home is writable by you (it usually is
not). `sudo -iu devuser` is the supported path.

### 3. Start the new desktop without leaving the current one

Stay logged in as `bastianweigand`. On another virtual terminal:

1. `Ctrl+Alt+F3` (F4 also works if F3 is busy).
2. Log in as `devuser`.
3. Start the compositor with **`start-hyprland`** (Hyprland ≥ 0.53).
   Do **not** run the `Hyprland` binary — that skips the session wrapper,
   shows a warning, and leaves `systemd --user` without `WAYLAND_DISPLAY`
   (no bar, no shell). Optional UWSM:
   `uwsm start hyprland-uwsm.desktop`.
4. Once, as `devuser`: `systemctl --user enable modern-shell.service`
   so the unit is installed. Autostart **restarts** it after importing
   `WAYLAND_DISPLAY` (`docs/BOOT.md`). `--now` before a compositor is
   running is skipped (`ConditionEnvironment=WAYLAND_DISPLAY`).

You now have two sessions: the old desktop on TTY1/TTY2, the new one on
TTY3.

### 4. Switch back to your main user

- **Keep both sessions:** `Ctrl+Alt+F1` or `Ctrl+Alt+F2` until you see
  the `bastianweigand` desktop. Nothing in the main home was rewritten.
- **End the test session:** `SUPER+SHIFT+M`, or from another TTY
  `loginctl terminate-session <id>` (`docs/BOOT.md`). If the bar is
  up, `SUPER+T` then `hyprctl dispatch "hl.dsp.exit()"` also works.
  You land back on the TTY prompt — `exit` or Ctrl+D logs out of that
  TTY. Then `Ctrl+Alt+F1`/`F2`. Do not open a second `start-hyprland`
  while the first is still running; one user gets one graphical session.
- **After a reboot:** autologin is still the daily-driver account,
  because greetd was never enabled. Log in as usual.

### 5. Cursor on `devuser`

Follow `docs/CURSOR-SETUP.md` inside the `devuser` session (`--profile
dev` installs `cursor-bin`). Open `~/modern_dotfile` there — not the
copy under `/home/bastianweigand`.

## New PC — install from scratch

Gated `/etc` files are still **not** applied by default. You get a
working user session first; greetd/Plymouth are a later, explicit step
(`docs/BOOT.md`, `docs/ISOLATION.md`).

### Already running Arch (one empty user)

```bash
git clone git@github.com:Gamesearch56/modern_dotfile.git ~/modern_dotfile
cd ~/modern_dotfile
./install/install.sh --profile m0 --dry-run
./install/install.sh --profile m0
systemctl --user enable modern-shell.service
start-hyprland
```

`enable` installs the unit (`Restart=always`). Autostart imports
`WAYLAND_DISPLAY` and restarts it; it does not start a second one-shot
`qs` (`docs/BOOT.md`).

If that user is named `bastianweigand` **and** `/home/bastianweigand`
exists (this machine, or a restore of this username), the live-home
guard will refuse. That is intentional on the current PC. On a **new**
machine where this *is* the account you want to own, pass
`--allow-live-home` after reading `docs/ISOLATION.md`.

### Bare metal (live ISO)

Default is **print-only**. Disks are not wiped unless `--yes` and
`--disk /dev/X` are both passed, and even then this script prints the
plan rather than calling `mkfs` from the repo (see
`scripts/bootstrap.sh`).

```bash
cp install/hardware.conf.example install/hardware.conf
# set DISK=, HOSTNAME=, USERNAME=, TIMEZONE=, LOCALE=
./scripts/bootstrap.sh --dry-run
# review the plan, then on the ISO run the printed partition/pacstrap steps
# as root. After chroot + first boot, as the new user:
cd ~/modern_dotfile
./install/install.sh --profile m0
```

QEMU recipe only: `./scripts/bootstrap.sh --vm`.

## Logging and errors

| Layer | Where it goes | User-visible |
|---|---|---|
| Installer | terminal + `install/install.log` (gitignored) + `journalctl -t modern-install` | no toasts (would hit the wrong session) |
| Shell | Quickshell `log.qslog` + `Logger` ring (Settings → System) | **errors** become notification toasts; DND does not hide errors |
| Soft failures | `Logger.warn` (console + ring) | no toast unless `Logger.notifyOnWarn` is enabled |

Failed `config.json` writes, Hyprland dispatch, brightness, Drive sync,
and uncaught Service exceptions call `Logger.error` and surface in the
notification panel.

## Architecture at a glance

```
Wallpaper + theme profile → matugen → tokens.json (single source of truth)
                                          │
                     ┌────────────────────┼─────────────────────┐
                     ▼                    ▼                     ▼
                Colors.qml         GTK3/4 + Qt CSS      kitty / Vivaldi / Plymouth

config.json (behaviour, written only by Settings) ──► hyprland.lua + Quickshell
```

QML layers (enforced by `scripts/lint-layers.sh`):
`Commons → Services → Widgets → Modules`. See `AGENTS.md`.

## Repository layout

```
modern_dotfile/
├── AGENTS.md, README.md, LICENSE
├── docs/           architecture, design, decisions, install & ops guides
├── install/        install.sh, manifests/, baseline/, system/ (gated)
├── stow/           everything that becomes a dotfile on the target user
└── scripts/        theme-apply, doctor, isolation check, `modern` IPC CLI
```

## Keybinds (M0 defaults)

| Keys | Action |
|---|---|
| `SUPER` + `Space` | Application launcher |
| `SUPER` + `M` | Power menu |
| `SUPER` + `K` | Keybind cheatsheet |
| `SUPER` + `I` | Settings |
| `SUPER` + `W` | Wallpaper picker |
| `SUPER` + `Tab` | Overview |
| `SUPER` + `T` | Terminal (kitty; always bound) |
| `SUPER` + `Return` | Terminal (always bound) |
| `SUPER` + `B` | Browser (Vivaldi) |
| `SUPER` + `E` | File manager (Dolphin) |
| `SUPER` + `Q` | Close window |

Full list: `SUPER`+`K`, or `stow/modern/.config/modern/config.default.json`
→ `keybinds`.

## Verify (from the daily-driver account)

These commands do not stow onto your live home:

```bash
scripts/lint-layers.sh
scripts/check-isolation.sh
./install/install.sh --dry-run --profile m0 --target /tmp/modern-install-dryrun
scripts/doctor.sh
```

Troubleshooting: `docs/TROUBLESHOOTING.md`. `scripts/doctor.sh` never
mutates the machine.

## License

MIT, see `LICENSE`.
