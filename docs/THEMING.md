# Theming pipeline

How a wallpaper (or a fixed brand color) becomes every color in the
system, and how to add a new consumer. See `docs/ARCHITECTURE.md`'s
"Theme layer" for the one-paragraph summary and `docs/DESIGN.md` for the
Material Design 3 color roles themselves.

## Overview

```
themes/<profile>.json  (variant, mode, contrast, sourceMode, fixedSeed)
        │
        ▼
scripts/theme-apply.sh  ── resolves the profile + wallpaper/seed,
        │                  runs `awww img` if sourceMode=wallpaper
        ▼
matugen -c ~/.config/matugen/config.toml ...
        │
        ├─▶ tokens.json                          (SINGLE SOURCE OF TRUTH)
        ├─▶ Colors.qml                           (Quickshell shell)
        ├─▶ hypr/modules/colors.lua               (Hyprland borders)
        ├─▶ kitty/colors.conf
        ├─▶ gtk-3.0/gtk.css, gtk-4.0/gtk.css
        ├─▶ qt6ct/colors/modern.conf
        ├─▶ kdeglobals                            (Dolphin, other KDE apps)
        └─▶ vivaldi/custom_css/00-modern.css
```

Every output in that list is written by **one** `matugen` invocation from
**one** seed color, so nothing can drift out of sync the way hand-rolled
per-app Wallust templates could. `tokens.json` is also readable directly
by anything that isn't a matugen template consumer (e.g. a shell script
via `jq`, or the future Settings > Diagnostics color preview).

## Files

- `stow/theme/.config/matugen/config.toml` — declares every
  `[templates.*]` input/output pair. Rarely needs hand-editing; add a new
  consumer here (see "Adding a new consumer" below).
- `stow/theme/.config/matugen/templates/*.template` — one Handlebars-ish
  template per output, using matugen's `{{colors.<role>.default.<format>}}`
  syntax (`hex`, `hex_stripped`, `red`/`green`/`blue`, `rgb`, `rgba`, ...).
  Verified against matugen v4.2.0 — see `docs/DECISIONS.md`.
- `stow/modern/.config/modern/themes/*.json` — switchable profiles, see
  `stow/modern/.config/modern/themes/README.md` for the schema. This is
  the "create one file and use it instead" mechanism from the original
  design brief.
- `scripts/theme-apply.sh` — the only thing that ever invokes `matugen`
  for the live system. Resolves which profile to use (from
  `config.json`'s `design.activeProfile`, or `--profile`), resolves the
  wallpaper/seed, runs matugen, then does what live-reload it can
  (`hyprctl reload`, `kitty @ load-config`).

## Profile resolution

`theme-apply.sh` reads `design.activeProfile` out of the merged
`config.json`/`config.default.json` (same deep-merge contract as
`stow/hypr/.config/hypr/modules/config.lua`) unless `--profile NAME` is
passed explicitly. The Settings app changes themes by writing that one
JSON key and calling `theme-apply.sh` — it never touches matugen directly.

## Wallpaper state

`sourceMode: "wallpaper"` profiles need an actual image. `theme-apply.sh`
remembers the last one used at `$XDG_STATE_HOME/modern/current-wallpaper`
(plain text, one absolute path). If that file is missing, it falls back
to the shipped `~/.config/modern/wallpapers/default.jpg`. Switching
*profiles* without picking a new image reuses the remembered path.

`matugen image <path>` is called with `--source-color-index 0` (most
dominant color, deterministic) rather than letting matugen prompt
interactively — it would otherwise ask "which of these N colors did you
mean?" on stdin, which hangs forever when invoked from a keybind, a
`hyprctl` dispatcher, or a future GUI button with no attached terminal.

## `mode` and `contrast` mapping

Theme profiles use human-readable values; `theme-apply.sh` maps them onto
matugen's actual flags:

| Profile field       | matugen flag                  |
|----------------------|-------------------------------|
| `mode: "auto"`       | `-m smart` (matugen's own per-run light/dark heuristic) |
| `mode: "light"/"dark"` | `-m light` / `-m dark`      |
| `contrast: "standard"` | *(omitted — matugen's default, `0`)* |
| `contrast: "medium"` | `--contrast 0.5`               |
| `contrast: "high"`  | `--contrast 1`                  |

## Live-reload scope

`theme-apply.sh` reloads what it can reload without extra machinery:
Hyprland (`hyprctl reload` picks up the freshly-written
`modules/colors.lua`) and kitty (`kitty @ load-config`, best-effort —
requires `allow_remote_control` in `stow/kitty/.config/kitty/kitty.conf`).
That file `globinclude`s `colors.conf` so a missing theme file does not
abort kitty. A shipped MD3 dark stub lives at
`stow/kitty/.config/kitty/colors.conf`; matugen overwrites the live copy.
Do not commit generated output from a theme-apply run. GTK/Qt live-reload
(re-reading `settings.ini`/`qt6ct.conf` in already-running apps) and the
Vivaldi `Preferences` merge are out of scope here — see the
`gtk-qt-theming` and `vivaldi-theme` plan entries in `docs/DECISIONS.md`.
The files these templates write are always correct on disk either way, so
a restarted app always picks up the current theme even before those
tasks land.

`--no-reload` skips all of the above — used by CI/lint checks and the M0
verification script, where no Hyprland/kitty session exists to reload.

## Adding a new consumer

1. Write `stow/theme/.config/matugen/templates/<name>.template` using
   `{{colors.<role>.default.<format>}}` placeholders. Check the color
   role names against `stow/theme/.config/matugen/templates/tokens.json.template`
   (it lists every MD3 role this pipeline exposes).
2. Add a `[templates.<name>]` block to `config.toml` with `input_path`/
   `output_path` (paths are `~`-relative, resolved against the user
   running `theme-apply.sh`, i.e. `devuser`).
3. Add a comment at the top of the template explaining what reads the
   output and why it needs its own file, matching the existing templates'
   style, plus a `GENERATED — do not hand-edit` header line.
4. If the consuming app needs a nudge to pick up the new file (a reload
   signal, a restart, a settings toggle), add it to `theme-apply.sh`'s
   "Live-reload" section, guarded so a missing/not-running app just
   prints a warning instead of failing the whole run.
