# Bar widgets

The bar is three id lists in `config.json` (`bar.left`, `bar.center`,
`bar.right`). Each id maps to `Modules/Bar/widgets/<id>/` with
`Widget.qml` and a `widget.json` descriptor (`id`, translation `key`,
`defaultEnabled`, required `services`). Adding a widget is a new
directory plus an id in those arrays — no central switch.

| id | i18n key | services | role |
|---|---|---|---|
| `launcher` | `bar.launcher` | Launcher | Opens the application launcher |
| `workspaces` | `bar.workspaces` | Hypr | Per-monitor strip (`Hypr.workspaceIdsFor`); `monitors.workspaceMode` `dynamic` or `fixed` (1–5 / 6–10 by x-position) |
| `tray` | `bar.tray` | — | Status notifier / system tray |
| `taskbar` | `bar.taskbar` | Hypr | Open windows (`Hypr.toplevelList`; refreshes when the popup opens) |
| `clock` | `bar.clock` | Calendar | Date/time; click opens Calendar / Events tabs (month grid + today's ICS events) |
| `media` | `bar.media` | Media | Capsule (art, title, transport); playing app wins, then Spotify if it is open |
| `audio` | `bar.volume` | Audio | Sink volume / mute; click opens Settings → Audio |
| `weather` | `bar.weather` | Weather | Location-based conditions |
| `network` | `bar.network` | Network | Wi-Fi / ethernet indicator |
| `microphone` | `bar.microphone` | Audio | Source volume / mute |
| `performance` | `bar.performance` | SystemStats | CPU / RAM / GPU / temp poll (timer off when hidden) |
| `vpn` | `bar.vpn` | Vpn | VPN connection state |
| `bluetooth` | `bar.bluetooth` | Bluetooth | Adapter + connected devices |
| `notifications` | `bar.notifications` | Notifications | Unread / DND affordance |
| `settings` | `bar.settings` | Notifications | Opens the control center (`Notifications.toggle`), not the Settings app |
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
`vpn`, `kdeconnect`, `notifications`.

A **bubble** is a widget (or small cluster) with its own background
pill. `widget.json` `"bubble": true` marks a standalone pill. Wi-Fi and
Bluetooth share a pill; battery + control-center gear + power share
another. `bar.position` is `top` / `bottom` / `left` / `right`. Default
height is 36. Wi-Fi and Bluetooth on the bar open Settings, not a popup.
AI, weather, and clock use `MPopup`. Reorder and per-widget forms in
Settings → Bar (`docs/SETTINGS.md`).

