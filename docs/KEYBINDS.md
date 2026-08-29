# Keybinds

Combos are strings in `config.json` → `keybinds`, in Hyprland Lua
`hl.bind()` form (`SUPER + SHIFT + T`). The Settings keyboard editor
and `Modules/Cheatsheet` read that object; Hyprland's Lua reader binds
them. The Settings app never rewrites Lua.

Defaults (also in `stow/modern/.config/modern/config.default.json`):

| Combo | Action | IPC |
|-------|--------|-----|
| `SUPER + SPACE` | Launcher | `qs -c modern ipc call launcher toggle` |
| `SUPER + M` | Power menu | `qs -c modern ipc call powermenu toggle` |
| `SUPER + L` | Control panel | `qs -c modern ipc call notifications toggle` |
| `SUPER + SHIFT + M` | Exit compositor | `hyprctl dispatch "hl.dsp.exit()"` |
| `SUPER + K` | Cheatsheet | `qs -c modern ipc call cheatsheet toggle` |
| `SUPER + I` | Settings (Hyprland window) | `qs -c modern ipc call settings open` |
| `SUPER + W` | Wallpaper picker | `qs -c modern ipc call wallpaper toggle` |
| `SUPER + TAB` | Overview | `qs -c modern ipc call overview toggle` |
| `SUPER + T` | Terminal | kitty |
| `SUPER + B` | Browser | Vivaldi |
| `SUPER + SHIFT + B` | Browser incognito | `vivaldi-stable --incognito` (from `apps.defaults.browser`) |
| `SUPER + E` | File manager | Dolphin |
| `SPACE` | Quick Look (Dolphin selection; else types Space) | `modern filepreview` |
| `SUPER + R` | Spotify | `spotify-launcher` |
| `SUPER + Q` | Close HUD/popup/control panel, else focused window | `modern window close` |
| `SUPER + F` | Fullscreen | |
| `SUPER + G` | Game mode | |
| `PRINT` | Screenshot region | `modern screenshot region` → `~/Pictures/Screenshots` |
| `SHIFT + PRINT` | Screenshot window | `modern screenshot window` |
| `SUPER + PRINT` | Screenshot full | `modern screenshot full` |
| `SUPER + mouse 272 / 273` | Drag / resize window | |
| `SUPER + scroll` | Next/prev workspace on this monitor | `workspace m±1` |
| `SUPER + SHIFT + C` | Color picker | |
| `SUPER + SHIFT + V` | Clipboard history | |

Workspace `SUPER + 1`…`0` and `SUPER + SHIFT + 1`…`0` (move), plus
focus/move arrows, match the cheatsheet categories.

Live list: press `SUPER + K`. CLI: `scripts/modern <target> <function>`
(`qs -c modern ipc` wrapper).
