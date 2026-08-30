# Keybinds

Combos are strings in `config.json` → `keybinds`, in Hyprland Lua
`hl.bind()` form (`SUPER + SHIFT + T`). The System Settings keyboard
page and `Modules/Cheatsheet` read that object; Hyprland's Lua reader
binds them. System Settings never rewrites Lua.

Defaults (also in `stow/modern/.config/modern/config.default.json`):

| Combo | Action | IPC |
|-------|--------|-----|
| `SUPER + SPACE` | Launcher | `qs -c modern ipc call launcher toggle` |
| `SUPER + M` | Power menu | `qs -c modern ipc call powermenu toggle` |
| `SUPER + O` | Control panel | `qs -c modern ipc call notifications toggle` |
| `SUPER + L` | Lock screen | `qs -c modern ipc call session lock` |
| `SUPER + SHIFT + M` | Exit compositor | `hyprctl dispatch "hl.dsp.exit()"` |
| `SUPER + K` | Cheatsheet | `qs -c modern ipc call cheatsheet toggle` |
| `SUPER + I` | System Settings (Hyprland window) | `qs -c modern ipc call settings toggle` |
| `SUPER + W` | Wallpaper picker | `qs -c modern ipc call wallpaper toggle` |
| `SUPER + DELETE` | Applications (taskbar) | `qs -c modern ipc call taskbar toggle` |
| `SUPER + TAB` | Overview | `qs -c modern ipc call overview toggle` |
| `SUPER + T` | Terminal | Configured `apps.defaults.terminal` via `modern-launch` |
| `SUPER + B` | Browser | Configured `apps.defaults.browser` via `modern-launch` |
| `SUPER + SHIFT + B` | Browser private window | Same desktop id, with `--incognito` or `--private-window` |
| `SUPER + E` | File manager | Configured `apps.defaults.fileManager` via `modern-launch` |
| `SPACE` | Quick Look (Dolphin selection; else types Space) | `modern filepreview` |
| `SUPER + R` | Spotify | `spotify-launcher` |
| `SUPER + Q` | Close HUD/popup/control panel, else focused window | `modern window close` |
| `SUPER + F` | Fullscreen | |
| `SUPER + G` | Game mode | |
| `PRINT` | Screenshot region (HUD: still or video) | `modern screenshot region` → stills `~/Pictures/Screenshots`, recordings `~/Videos/Recordings` |
| `SHIFT + PRINT` | Screenshot window | `modern screenshot window` |
| `SUPER + PRINT` | Screenshot full; stops an active recording | `modern screenshot full` |
| `SUPER + mouse 272 / 273` | Drag / resize window | |
| `SUPER + scroll` | Next/prev workspace on this monitor | `workspace m±1` |
| `SUPER + SHIFT + C` | Color picker | |

Workspace `SUPER + 1`…`0` and `SUPER + SHIFT + 1`…`0` (move), plus
focus/move arrows, match the cheatsheet categories.

Live list: press `SUPER + K`. CLI: `scripts/modern <target> <function>`
(`qs -c modern ipc` wrapper).
