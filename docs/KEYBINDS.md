# Keybinds

Combos are strings in `config.json` → `keybinds`, in Hyprland Lua
`hl.bind()` form (`SUPER + SHIFT + T`). The Settings keyboard editor
and `Modules/Cheatsheet` read that object; Hyprland's Lua reader binds
them. The Settings app never rewrites Lua.

Defaults (also in `stow/modern/.config/modern/config.default.json`):

| Combo | Action | IPC |
|-------|--------|-----|
| `SUPER + SPACE` | Launcher | `qs ipc call launcher toggle` |
| `SUPER + M` | Power menu | `qs ipc call powermenu toggle` |
| `SUPER + SHIFT + M` | Exit compositor | `hyprctl dispatch exit` (no shell needed) |
| `SUPER + K` | Cheatsheet | `qs ipc call cheatsheet toggle` |
| `SUPER + I` | Settings | `qs ipc call settings open` |
| `SUPER + W` | Wallpaper picker | `qs ipc call wallpaper pick` |
| `SUPER + TAB` | Overview | `qs ipc call overview toggle` |
| `SUPER + T` | Terminal | kitty |
| `SUPER + B` | Browser | Vivaldi |
| `SUPER + E` | File manager | Dolphin |
| `SUPER + Q` | Close window | |
| `SUPER + F` | Fullscreen | |
| `SUPER + G` | Game mode | |
| `PRINT` | Screenshot region | |
| `ALT + PRINT` | Screenshot window | |
| `SUPER + PRINT` | Screenshot full | |
| `SUPER + SHIFT + C` | Color picker | |
| `SUPER + SHIFT + V` | Clipboard history | |

Workspace `SUPER + 1`…`0` and `SUPER + SHIFT + 1`…`0` (move), plus
focus/move arrows, match the cheatsheet categories.

Live list: press `SUPER + K`. CLI: `scripts/modern <target> <function>`
(`qs ipc` wrapper).
