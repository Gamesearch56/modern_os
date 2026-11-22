# Bar widgets

For developers: which bar widgets exist, how a widget is declared and
placed, and how the dock next to the bar behaves. End users change the
same layout in Settings → Bar and Settings → Dock.

The bar is three id lists in `config.json` (`bar.left`, `bar.center`,
`bar.right`). Each id maps to `Modules/Bar/widgets/<id>/` with
`Widget.qml` and a `widget.json` descriptor (`id`, translation `key`,
`defaultEnabled`, required `services`). Adding a widget is a new
directory plus an id in those arrays — no central switch.

| id | i18n key | services | role |
|---|---|---|---|
| `launcher` | `bar.launcher` | Launcher | Opens the application launcher |
| `workspaces` | `bar.workspaces` | Hypr | Per-monitor strip (`Hypr.workspaceIdsFor`); `monitors.workspaceMode` `dynamic` (this output only, + always shown) or `fixed` (1–5 / 6–10 / 11–15 / … by x-position) |
| `tray` | `bar.tray` | — | Status notifier / system tray |
| `taskbar` | `bar.taskbar` | Hypr, Tray, RunningApps | Open windows (`Hypr.toplevelList`; refreshes when the popup opens) |
| `clock` | `bar.clock` | — | Date/time; click opens Calendar / Events tabs (month grid + today's ICS events) |
| `media` | `bar.media` | Media, Audio | Capsule (art, title, transport); playing app wins, then Spotify if it is open |
| `audio` | `bar.volume` | Audio | Master sink volume / mute (0% mutes every app stream); click opens Settings → Audio |
| `weather` | `bar.weather` | Weather | Location-based conditions |
| `network` | `bar.network` | Network | Wi-Fi / ethernet indicator |
| `microphone` | `bar.microphone` | Audio | Source volume / mute |
| `performance` | `bar.performance` | SystemStats | CPU / RAM / GPU / temp poll (timer off when hidden) |
| `bluetooth` | `bar.bluetooth` | Bluetooth | Adapter + connected devices |
| `notifications` | `bar.notifications` | Notifications | Unread / DND affordance |
| `battery` | `bar.battery` | Battery | Charge level and state |
| `settings` | `bar.controlPanel` | Notifications | Opens the control center (`Notifications.toggle`), not the Settings app |
| `power` | `bar.power` | PowerMenu | Session power menu |
| `ai` | `ai.title` | Ai | Assistant chip + chat popup (Ollama); empty state explains setup |
| `connectivity` | `bar.connectivity` | Network, Bluetooth | Combined wifi + BT; click opens Settings |
| `calendar` | `calendar.title` | Calendar | Month grid (optional bar chip) |
| `mail` | `bar.mail` | Apps, Hypr | Mail launcher |
| `kdeconnect` | `bar.kdeconnect` | KdeConnect | Phone pairing |

Default layout (bubbles) in `stow/modern/.config/modern/config.default.json`:

- `bar.left`: `launcher`, `ai`, `workspaces`, `media`
- `bar.center`: `clock` (calendar popup)
- `bar.right`: `weather`, `connectivity`, `audio`, `taskbar`, `battery`, `settings`, `power`

Settings → Bar can enable/disable and drag those ids across left/middle/right.
These still exist as directories but are **not** in the Settings catalog
(they render only if leftover `config.json` lists them): `tray`,
`calendar`, `mail`, `network`, `bluetooth`, `microphone`, `performance`,
`kdeconnect`, `notifications`, `notes`.

A **bubble** is a widget (or small cluster) with its own background
pill. `widget.json` `"bubble": true` marks a standalone pill. Wi-Fi and
Bluetooth share a pill; battery + control-center gear + power share
another. `bar.position` is `top` / `bottom` / `left` / `right`. Default
height is 36. Wi-Fi and Bluetooth on the bar open Settings, not a popup.
AI, weather, and clock use `MPopup`. Reorder and per-widget forms in
Settings → Bar (`docs/SETTINGS.md`).

## Dock

The dock is a centered row of pinned applications on the edge opposite
the bar: a top bar puts the dock on the bottom, a left bar puts it on
the right, and the reverse. A new installation turns `dock.enabled` on.
It stays hidden while that switch is off.
`dock.apps` starts as Vivaldi, WhatsApp, Spotify, Steam, Kitty, the file manager, the app store, and Settings.

Three styles, all from tokens: **edge dash** (`beam`, a short primary
mark on the outer edge of each icon), **plate** (`inventory`, each icon
in a surface slot), and **floating** (the icon alone). Hover plays the selected animation
(`dock.hover`): zoom, a primary color wash, a bounce, or a lift off the
screen edge. A click eases the icon in, then opens the application.
Names are drawn with the icon only when `dock.showNames` is on.
Hover does not add a label. Icon size and
auto-hide follow the same live preview as the bar. Auto-hide also
reveals the dock while a pin has keyboard focus.

A pin launches on click. The row can be rearranged, and a pin can be
dropped on the trash, only while the application launcher is open.
Settings → Dock rearranges the same list with the launcher closed.
Drag an application from the launcher results, the all-applications
grid, or the installed list on that page to add it. With the dock
off, the launcher does not start that drag, and it does not leave
the dock's edge clear.

A drag from the all-applications grid or the launcher's search results
also shows the trash, held still instead of wiggling, as an uninstall
target.
`AppUninstall` asks `scripts/app-package.sh` which pacman package owns
the desktop file and whether `pkg-mutate.sh` would remove it. Core and
protected packages, applications no package owns (ModernOS apps, web
apps, Flatpaks) and accounts that cannot manage software grey the trash
out; a drop there only shows a notification. Otherwise a drop opens the
App Store on that package with its own confirm dialog, progress and
"removed" notification.

