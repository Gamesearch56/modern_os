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
        │     └─▶ Colors.qml FileView            (Quickshell live)
        ├─▶ hypr/modules/colors.lua               (Hyprland borders)
        ├─▶ kitty/colors.conf
        ├─▶ gtk-3.0/gtk.css, gtk-4.0/gtk.css
        ├─▶ qt6ct/colors/modern.conf              (QPalette; Fusion / Dolphin)
        ├─▶ kdeglobals                            (Dolphin, other KDE apps)
        ├─▶ qt6ct/qss/modern.qss                  (Fusion stylesheet)
        ├─▶ hypr/application-style.conf           (hyprland-qt-support radii)
        ├─▶ hypr/hyprtoolkit.conf                 (hyprpolkitagent chrome)
        └─▶ vivaldi/custom_css/00-modern.css
            + 01-chrome.css (fonts/radii)
```

Do **not** mix `design.transparency` into Vivaldi `#browser` — glass is
for the island bar. Enable CSS mods once at `vivaldi://experiments`.


Every *color* output in that list is written by **one** `matugen`
invocation from **one** seed color, so nothing can drift out of sync the
way hand-rolled per-app Wallust templates could. Radii, fonts, and
motion for toolkit chrome (`01-chrome.css`, QSS placeholders,
`application-style.conf`, `hyprtoolkit.conf`) are patched afterwards from `config.json`.
`tokens.json` is also readable directly
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
  (`hyprctl reload`, `kitty @ load-config`). Quickshell watches
`tokens.json` and restyles the bar/overlays immediately. GTK apps pick
up `gtk.css` on restart. Vivaldi's CSS overlay is already on disk
(reload the tab); the native theme object is merged only while Vivaldi
is not running. Nautilus and Dolphin must be fully quit after `theme-apply.sh`.

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

`matugen image <path>` is called with `--prefer saturation` so a
wallpaper's most chromatic candidate becomes the seed (dark skies and
walls are often the *dominant* color and made every image look the same).
`--prefer` still picks non-interactively — without it matugen prompts
"which of these N colors?" on stdin, which hangs forever from a keybind
or Settings with no attached terminal.

Settings → Design shows one card per matugen scheme (`scripts/theme-previews.sh`
dry-runs the wallpaper's `--prefer saturation` seed through each type,
in the current light or dark mode). Choosing a card applies that
variant. A new wallpaper, or a light/dark switch, regenerates the
cards. Apply uses `--extract` so the chrome follows the image until a
card locks a seed.

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
Do not commit generated output from a theme-apply run. GTK/Qt live-reload (re-reading `settings.ini`/`qt6ct.conf` in
already-running apps) and the Vivaldi `Preferences` merge are out of
scope of a running-app live-reload: CSS overlay + `01-chrome.css` are
always rewritten; the native theme object is merged only while Vivaldi is
**not** running (so we do not fight its Preferences writer). Dolphin does
not reload QSS live — fully quit it after `theme-apply.sh` and reopen with
Super+E (`scripts/modern-launch` so `qt6ct` is in the environment even
when Hyprland was only reloaded). qt6ct must **not** load `modern.qss`:
an application stylesheet makes Fusion ignore the custom **Active**
palette. Colors come from `qt6ct/colors/modern.conf` (`#AARRGGBB`) plus
kdeglobals. KF6 apps (Dolphin) ignore that QPalette: KColorSchemeManager
treats qt6ct's `ColorScheme::Unknown` as light, so a focused window goes
white. `kdeglobals` `[UiSettings] ColorScheme=modern` pins
`~/.local/share/color-schemes/modern.colors`. Widget style is
`qt6ct-style`. Dolphin is an opaque overlay card (`dolphin-opaque`);
Nautilus is the same (`nautilus-opaque`). Nautilus Space preview is
GNOME Sushi (`nautilus-previewer`: float, center, `dim_around`, no
hyprbars), colored from the same `gtk.css` GTK3 Adwaita aliases. GTK icon theme is
Papirus-Dark so Nautilus keeps emblem folders; KDE/Dolphin use
`modern-folders` (token-colored folder SVGs). Fully quit Nautilus or
Dolphin after `theme-apply.sh`. Wallpaper stays in the
compositor gaps around the window. `hyprctl reload` picks up the rule.
`theme-apply.sh` writes absolute paths into `qt6ct.conf` because qt6ct
does not expand `~`.

**hyprpolkitagent** is hyprtoolkit (not Qt Quick / QSS). Colors, Inter,
and `Tokens.radius.medium`/`small` are written to
`~/.config/hypr/hyprtoolkit.conf` from `tokens.json` + `config.json`.
The compositor applies `design.transparency` and `dim_around` via the
`polkit-auth-dialog` window rule so the prompt reads as glass over a
scrim, like Super+W. The next dialog picks up toolkit colors without a
restart. `theme-apply.sh` starts the user unit if it is down; it does
not `try-restart` on every chrome patch (that hits systemd StartLimit
and leaves `pkexec` with no password window). The agent's error string is hardcoded `"red"` upstream and cannot
follow `error`. The files these
templates write are always correct on disk, so a restarted app always
picks up the current theme.

**Vivaldi CSS modifications** must be enabled once in the browser:
open `vivaldi://experiments` and turn on “Allow CSS modifications”, then
point Custom UI Modifications at `~/.config/vivaldi/custom_css`. That
toggle cannot be flipped from `config.json`. When
`design.bootScreen.wallpaperOnVivaldi` is true, `theme-apply.sh` copies
the current wallpaper to `custom_css/wallpaper` and `01-chrome.css` sets
`--md-wallpaper` (plus `--md-font-*`, `--md-radius-*`, `--md-space-*`,
`--md-blur`, `--md-transparency` from `config.json`).

`--no-reload` skips all of the above — used by CI/lint checks and the M0
verification script, where no Hyprland/kitty session exists to reload.

`--chrome-only` skips matugen and rewrites GTK/Qt/KDE/Vivaldi radii,
fonts, cursor, and motion from the current `config.json`. Settings uses
this after Design knobs that are not a palette swap (rounding, type
scale, animations, transparency, cursor).

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
