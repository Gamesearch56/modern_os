# AGENTS.md — how to work in this repo

This file is for future you, or any agent, picking this project back up.
Read `docs/DECISIONS.md` for *why* each of these choices was made and what
was rejected; this file is the practical "how do I add X" reference.

## What this is

A from-scratch Material Design 3 desktop environment for Hyprland: a
Quickshell (QML) shell, matugen for wallpaper-derived color, and
everything behavioural in one JSON config file. Full plan:
`docs/ARCHITECTURE.md`.
Status: `README.md`. Settings is a Hyprland window (`modern.settings`);
it still writes `config.json` only.

## The layer contract

```
Commons/   Tokens, Typography, Motion, Config, I18n, Logger — depends on nothing
Services/  Hypr, Audio, Network, Bluetooth, ... — imports Commons only,
           owns ALL process/D-Bus/filesystem access, exposed as singletons
Widgets/   MD3 primitives (MButton, MCard, MSlider, ...) — stateless,
           token-driven, never import Services or Modules
Modules/   Features (Bar, Launcher, Settings, ...) — compose Widgets,
           read Services, never import another Module's internals
```

`scripts/lint-layers.sh` enforces the import direction. Run it before
committing QML changes.

**Every new file in `Commons/`, `Services/`, or `Widgets/` must be added to
that directory's `qmldir`**, e.g. `singleton Foo 1.0 Foo.qml` (singletons)
or `Foo 1.0 Foo.qml` (Widgets). This is not optional cleanup — Quickshell's
implicit directory-import auto-synthesis (what runs if no `qmldir` is
present) has been caught silently mis-registering a `pragma Singleton`
file as a plain type, which breaks every method on it with a confusing
`TypeError: ... is not a function` far from the real cause. See
`docs/DECISIONS.md` #19. A missing `qmldir` entry for a new file usually
still works (auto-synthesis is right most of the time) — which is exactly
why this is easy to forget and hard to notice until it silently isn't.

## How to add things

**A new Service.** Create `stow/shell/.config/quickshell/modern/Services/<Name>.qml`
as a `Singleton { }`. It owns one concern (one D-Bus interface, one IPC
socket, one class of files). Only `Services` may call `Quickshell.execDetached`,
open a socket, or touch the filesystem. Give it a header comment: purpose,
what it owns, what it emits. Add it to `Services/qmldir`.

**A new Widget primitive.** Add it to `Widgets/`, name it `M<Thing>.qml`,
keep it stateless (props in, signals out), style it only from
`Commons/Tokens.qml` and `Commons/Motion.qml`. Never reference a `Service`.
Add it to `Widgets/qmldir`.

**A new bar widget.** Create a directory under
`Modules/Bar/widgets/<id>/` with `Widget.qml` (the mini bar representation)
and optionally `Panel.qml` (the popup). Add a `widget.json` descriptor
(`id`, translation key, default enabled, required Services). Set
`"bubble": true` if the widget should be its own pill (launcher, media,
volume) instead of grouping with neighbours. Wi-Fi/Bluetooth and
battery/control/power are the grouped clusters. Add the id to
`bar.left` / `bar.center` / `bar.right` in `config.default.json`. Nothing
else changes — no central switch statement to edit.

**A new Settings section.** Create `Modules/Settings/sections/<id>/` with
`Section.qml`, `section.json` (id, icon, translation key, order, search
keywords) and `Model.qml` that reads only `config.<id>` from
`Commons/Config.qml`. Add the id to **`Modules/Settings/Catalog.qml`**
(`ids` and `_byId`; `groupOrder` if you add a nav group). Search uses
the catalog — a folder alone is not enough. See `docs/SETTINGS.md`.

**A new launcher provider.** Add a file under
`Modules/Launcher/providers/<name>.qml` implementing `query(text) -> results[]`
and register its prefix in `config.default.json` under `launcher.providers`.

**A new translation key.** Add it to both
`stow/modern/.config/modern/translations/en.json` and `de.json` in the same
change, in the same nested path. Reference it with `I18n.t("path.to.key")`.
Never leave a key in one file and not the other — `scripts/lint-layers.sh`
checks for this.

**A new theme profile (color template).** Drop a JSON file in
`stow/modern/.config/modern/themes/<name>.json` with `{ variant, mode,
contrast, sourceMode, fixedSeed }`. Selecting it in Settings → Design (or
setting `theme.activeProfile` in `config.json`) re-runs
`scripts/theme-apply.sh` with that profile — no other file changes.

## Two independent data flows — don't cross them

- **Colors**: wallpaper + active theme profile → matugen → `tokens.json`
  (single source of truth) → `Colors.qml`, GTK/Qt CSS, kitty, Hyprland
  borders, Vivaldi, Plymouth.
- **Behaviour**: `config.json`, written only by the Settings app, read by
  `hyprland.lua` and the shell. The Settings GUI never rewrites Lua or QML.

If you're tempted to have Settings generate a Lua snippet, or have a widget
hardcode a color — stop, that's the pattern this project exists to avoid.

## Things that must never be hardcoded

Monitor names (`DP-1`), device IDs (`alsa_output.pci-...`), colors, font
names, durations, usernames, absolute paths outside `$HOME`/`XDG_*`. See
`.cursorrules` for the enforced list.

## System-wide changes are gated

Anything touching `/etc`, systemd *system* units, polkit, mkinitcpio, or
creating accounts lives under `install/system/` and is applied only by an
explicit, separately-invoked command — never by `install.sh`'s default
run. See `docs/ISOLATION.md` before touching anything there.

## Verifying your work

```bash
scripts/lint-layers.sh        # layer direction + i18n key parity + perf lint
scripts/check-isolation.sh    # confirm the current account is untouched
scripts/test-settings-catalog.sh
scripts/test-desktop-sync.sh
./install/install.sh --dry-run --profile m0 --target /tmp/modern-iso-dryrun
```

`iso-build.sh --mkarchiso` may write `iso/out/` on this PC. Do not run
`provision-iso.sh`, Calamares, or a live `install.sh` on a machine you
live on.

## Directory map

See the tree in `docs/ARCHITECTURE.md`. Short version: `stow/` is
everything that becomes a dotfile on `devuser`; `install/` is the
installer, manifests and gated system files; `scripts/` is standalone
tooling; `docs/` is reference material.
