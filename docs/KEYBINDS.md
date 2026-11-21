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
| `SUPER + #` | Report a problem | `modern report` |
| `SUPER + I` | System Settings (Hyprland window) | `qs -c modern ipc call settings toggle` |
| `SUPER + W` | Wallpaper picker | `qs -c modern ipc call wallpaper toggle` |
| `SUPER + DELETE` | Applications (taskbar) | `qs -c modern ipc call taskbar toggle` |
| `SUPER + TAB` | Overview | `qs -c modern ipc call overview toggle` |
| `SUPER + T` | Terminal | Configured `apps.defaults.terminal` via `modern-launch` |
| `SUPER + RETURN` | Emergency terminal | `/usr/bin/kitty` (always bound; not in `config.json`) |
| `SUPER + B` | Browser | Configured `apps.defaults.browser` via `modern-launch` |
| `SUPER + SHIFT + B` | Browser private window | Same desktop id, with `--incognito` or `--private-window` |
| `SUPER + E` | File manager | ModernOS File Manager (`modern.files`) via `apps.defaults.fileManager` |
| `SPACE` | File preview. If Nautilus is installed, its own preview owns Space there | `modern filepreview` |
| `SUPER + R` | Spotify | `modern-launch --on-active spotify-launcher` (moves an open window here) |
| `SUPER + Q` | Close HUD/popup/control panel, else focused window | `modern window close` |
| `SUPER + F` | Fullscreen | |
| `PRINT` | Screenshot region (HUD: still or video) | `modern screenshot region` → stills `~/Pictures/Screenshots`, recordings `~/Videos/Recordings` |
| `SHIFT + PRINT` | Screenshot window | `modern screenshot window` |
| `SUPER + PRINT` | Screenshot full; stops an active recording | `modern screenshot full` |
| `SUPER + LEFT` / `RIGHT` / `UP` / `DOWN` | Move focus | `hl.dsp.focus({ direction })` |
| `SUPER + SHIFT + LEFT` / `RIGHT` / `UP` / `DOWN` | Move the focused window in that direction | `hl.dsp.window.move({ direction })` |
| `SUPER + mouse 272 / 273` | Drag / resize window | |
| Hold back side button (MB4), then move | Move window | `modules/mouse_windows.lua` |
| Hold forward side button (MB5), then move | Resize window | |
| Back + forward side button | Close window (same as `SUPER + Q`) | `modern window close` |
| Back side button + middle click | Toggle floating | |
| Forward side button + middle click | Toggle fullscreen, also in games | |
| Side button click | Back / forward in the app, as before | `scripts/mouse-replay` |
| Middle click / middle drag | Unchanged in every app | |
| Middle click on an Applications entry | Close that window | |
| Window edge + drag | Resize window | |
| Volume, mute, microphone, play, pause, next, previous | Those hardware keys | `modern volume` / `modern media` |
| Brightness up / down | Those hardware keys | `modern brightness` |
| Applications right-click | Float, fullscreen, togglesplit, close | |
| `SUPER + SHIFT + C` | Color picker | |

Gaming mode is a switch in Settings, not a shortcut. Scroll on Super no longer changes workspace.

A side press shorter than 250 ms is always a click, even while the mouse is moving; only a held side button starts a move or resize. The middle button is only taken while a side button is held. The side buttons stay plain back/forward in games and fullscreen windows; forward + middle still toggles fullscreen there. Settings → Keyboard → "Mouse control" turns the side-button controls off (`input.mouseSideButtons`). `scripts/test-mouse-windows-live.py` checks them against the running session with a virtual mouse.

Workspace `SUPER + 1`…`0` and `SUPER + SHIFT + 1`…`0` (move window to
that workspace) match the cheatsheet categories. Three fingers up or
down on the trackpad fade the overview with the swipe; two fingers
then move between the windows. Three fingers sideways still change
workspace.

## Texteditor

Inside a Texteditor window (`docs/EDITOR.md`); the menus show the same keys.

| Combo | Action |
|---|---|
| `CTRL + N` / `CTRL + SHIFT + N` | New document / new window |
| `CTRL + O` / `CTRL + S` / `CTRL + SHIFT + S` | Open / save / save as |
| `CTRL + W` | Close the window (asks about unsaved changes) |
| `CTRL + Z` / `CTRL + Y` | Undo / redo |
| `CTRL + F` / `F3` / `SHIFT + F3` | Find / next / previous |
| `CTRL + H` / `CTRL + G` | Replace / go to line |
| `F5` | Insert time and date |
| `ALT + Z` | Word wrap |
| `CTRL + +` / `CTRL + -` / `CTRL + 0`, `CTRL + wheel` | Zoom in / out / reset |

Live list: press `SUPER + K`. Media lists the hardware keys. Mouse lists Super+mouse and the window edge. CLI: `scripts/modern <target> <function>`
(`qs -c modern ipc` wrapper).
