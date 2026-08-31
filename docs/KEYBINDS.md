# Keybinds

Combos are strings in `config.json` → `keybinds`, in Hyprland Lua
`hl.bind()` form (`SUPER + SHIFT + T`). Settings > Keyboard **lists**
that object; it does not write combos. `Modules/Cheatsheet` reads the
same table. Hyprland's Lua reader binds them. The Settings app never
rewrites Lua.

Defaults (also in `stow/modern/.config/modern/config.default.json`):

| Combo | Action | IPC |
|-------|--------|-----|
| `SUPER + SPACE` | Launcher | `qs -c modern ipc call launcher toggle` |
| `SUPER + A` | AI chat | `qs -c modern ipc call ai toggle` |
| `SUPER + M` | Power menu | `qs -c modern ipc call powermenu toggle` |
| `SUPER + N` | Control panel | `qs -c modern ipc call notifications toggle` |
| `SUPER + L` | Lock screen | `qs -c modern ipc call session lock` |
| `SUPER + SHIFT + M` | Exit compositor | `hyprctl dispatch "hl.dsp.exit()"` |
| `SUPER + K` | Cheatsheet | `qs -c modern ipc call cheatsheet toggle` |
| `SUPER + I` | System Settings (Hyprland window) | `qs -c modern ipc call settings toggle` |
| `SUPER + W` | Wallpaper picker | `qs -c modern ipc call wallpaper toggle` |
| `SUPER + DELETE` | Applications (taskbar) | `qs -c modern ipc call taskbar toggle` |
| `SUPER + TAB` | Overview | `qs -c modern ipc call overview toggle` |
| `SUPER + T` | Terminal | Configured `apps.defaults.terminal` via `modern-launch` |
| `SUPER + RETURN` | Emergency terminal | `/usr/bin/kitty` (always bound; not in `config.json`) |
| `SUPER + B` | Browser | Configured `apps.defaults.browser` via `modern-launch` |
| `SUPER + SHIFT + B` | Browser private window | Same desktop id, with `--incognito` or `--private-window` |
| `SUPER + E` | File manager | Configured `apps.defaults.fileManager` via `modern-launch` |
| `SPACE` | Nautilus: Sushi overlay (native). Dolphin: Quick Look (non-consuming bind; no-op in Nautilus) | `modern filepreview` (Dolphin only) |
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
