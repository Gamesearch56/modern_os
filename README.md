# modern_dotfile

A from-scratch Material Design 3 desktop environment for Arch Linux +
Hyprland: a [Quickshell](https://quickshell.outfoxxed.me/) (QML) shell
replaces Waybar, SwayNC and Rofi; [`matugen`](https://github.com/InioX/matugen)
replaces Wallust for dynamic, wallpaper-derived color; one JSON config file
drives both the shell and Hyprland's Lua config. German and English are
both first-class throughout.

Built to be daily-drivable on a fresh, empty `devuser` account and fully
reproducible from a bare Arch install via `install.sh`, or from bare metal
via `bootstrap.sh`.

> **Status.** This repo is under active construction against the plan in
> `docs/ARCHITECTURE.md`. It is developed entirely against a separate
> `devuser` account — see `docs/ISOLATION.md` — and has **not yet been
> installed or booted**. Package installation, account creation and any
> system-wide file (`install/system/`) are staged, reviewed, and applied
> manually; nothing in this repo runs itself against your machine. See
> "Current state" below for exactly what has been verified.

## Why

The previous setup (`~/dotfiles`, Wallust + Waybar + SwayNC + Rofi) hit a
ceiling: Wallust's 19 color slots can't express Material Design 3's ~30
semantic roles and tonal palette, three separate flat-CSS/rasi apps drift
out of sync with each other, and monitor names, audio sinks and a weather
city were hardcoded. Full audit and rationale in `docs/DECISIONS.md`.

## Architecture at a glance

```
Wallpaper + theme profile → matugen → tokens.json (single source of truth)
                                          │
                     ┌────────────────────┼─────────────────────┐
                     ▼                    ▼                     ▼
                Colors.qml         GTK3/4 + Qt CSS      kitty / Vivaldi / Plymouth

config.json (behaviour, written only by Settings) ──► hyprland.lua + Quickshell
```

QML is organized in four one-way layers — `Commons → Services → Widgets →
Modules` — enforced by `scripts/lint-layers.sh`. Full details:
`docs/ARCHITECTURE.md`, `AGENTS.md`.

## Repository layout

```
modern_dotfile/
├── AGENTS.md, README.md, LICENSE
├── docs/           architecture, design, decisions, install & ops guides
├── install/        install.sh, manifests/, baseline/, system/ (gated)
├── stow/           everything that becomes a dotfile on devuser
├── scripts/        standalone tooling (theme-apply, doctor, optiscaler, ...)
└── bin/            the `modern` IPC CLI
```

## Milestones

| # | Scope | Status |
|---|---|---|
| M0 | Bar, launcher, power menu, cheatsheet, Vivaldi, Cursor on a daily-drivable `devuser` | in progress |
| M1 | Lock/login/shutdown session, Plymouth boot theme, notifications, full GTK/Qt/Vivaldi theming | scaffolded |
| M2 | Wallpaper picker, media/performance/weather/VPN/notes widgets | scaffolded |
| M3 | Full Settings app (18 sections) | scaffolded |
| M4 | Gaming: OptiScaler manager, game profiles, perf tuning | scaffolded |
| M5 | Reliability: watchdog, portals, keyring, IPC CLI, KDE Connect, backups, bare-metal recovery, onboarding | scaffolded |
| M6 | Personal layer, plugin system, extras | scaffolded |

"Scaffolded" means the architecture, files and staged config exist and are
internally consistent, but the milestone has not been exercised on a live
`devuser` session yet — see `docs/TROUBLESHOOTING.md` and the milestone
checklists in `docs/DECISIONS.md` for what's left to verify by hand.

## Getting started

1. Read `docs/ISOLATION.md` — this explains what is and isn't safe to run
   on a machine with an existing daily-driver account.
2. Create `devuser` (staged, not automatic):
   `sudo install/system/create-devuser.sh`
3. As `devuser`: `git clone <this repo> ~/modern_dotfile && cd ~/modern_dotfile`
4. `./install/install.sh --profile m0` (add `--dry-run` first to preview).
5. Install Cursor on `devuser` following `docs/CURSOR-SETUP.md`.
6. Log in as `devuser`, then run `scripts/check-isolation.sh` from your own
   account to confirm nothing leaked across.

## Keybinds (M0 defaults)

| Keys | Action |
|---|---|
| `SUPER` + `Space` | Application launcher |
| `SUPER` + `M` | Power menu |
| `SUPER` + `K` | Keybind cheatsheet |
| `SUPER` + `I` | Settings |
| `SUPER` + `W` | Wallpaper picker |
| `SUPER` + `Tab` | Overview |
| `SUPER` + `T` | Terminal (kitty) |
| `SUPER` + `B` | Browser (Vivaldi) |
| `SUPER` + `E` | File manager (Dolphin) |
| `SUPER` + `Q` | Close window |

Full, always-current list: press `SUPER`+`K`, or see
`stow/modern/.config/modern/config.default.json` → `keybinds`.

## Troubleshooting

See `docs/TROUBLESHOOTING.md`. For a broken install, run `scripts/doctor.sh`
first — it diagnoses missing packages, missing secrets, low disk space and
unapplied gated phases before you go digging manually.

## License

MIT, see `LICENSE`.
