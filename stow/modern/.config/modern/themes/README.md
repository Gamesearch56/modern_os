# Theme profiles

Each file here is a switchable color template — "create one file and use
this instead of the other template", per the original request. Selecting
a profile name in `config.json`'s `design.activeProfile` (or via Settings
→ Design) re-runs `scripts/theme-apply.sh` with that profile; nothing else
changes.

Schema:

```json
{
  "variant": "tonal-spot | content | expressive | fidelity | fruit-salad | monochrome | neutral | rainbow",
  "mode": "auto | light | dark",
  "contrast": "standard | medium | high",
  "sourceMode": "wallpaper | fixed",
  "fixedSeed": "#6750A4"
}
```

`sourceMode: "wallpaper"` derives the seed color from the current
wallpaper (matugen's default behaviour). `sourceMode: "fixed"` ignores
the wallpaper and always uses `fixedSeed` — useful for a stable brand
color regardless of what's on screen.

`variant` maps 1:1 onto one of matugen's `scheme-*` types (`scripts/theme-apply.sh`
just prepends `scheme-`). `mode: "auto"` maps onto matugen's own `smart`
mode — it picks light/dark per-run from the source color/image rather
than a fixed value, which is a better "auto" than a day/night clock
heuristic would be. `contrast` maps onto matugen's numeric `--contrast`
flag (`-1`..`1`): `standard` → `0` (omitted, matugen's default),
`medium` → `0.5`, `high` → `1`.
