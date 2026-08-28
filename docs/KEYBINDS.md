# Keybinds

Combos are strings in `config.json` → `keybinds`, in Hyprland Lua
`hl.bind()` form (`SUPER + SHIFT + T`). The Settings keyboard editor
and `Modules/Cheatsheet` read that object; Hyprland's Lua reader binds
them. The Settings app never rewrites Lua.

Defaults (also in `stow/modern/.config/modern/config.default.json`):

| Combo | Action | IPC |
|-------|--------|-----|
| `SUPER + SPACE` | Launcher | `modern launcher toggle` |
| `SUPER + M` | Power menu | `modern powermenu toggle` |
| `SUPER + K` | Cheatsheet | `modern cheatsheet toggle` |
| `SUPER + I` | Settings | `modern settings open` |
| `SUPER + W` | Wallpaper picker | `modern wallpaper pick` |
| `SUPER + TAB` | Overview | `modern overview toggle` |
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
