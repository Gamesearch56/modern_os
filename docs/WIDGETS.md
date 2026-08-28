# Bar widgets

The bar is three id lists in `config.json` (`bar.left`, `bar.center`,
`bar.right`). Each id maps to `Modules/Bar/widgets/<id>/` with
`Widget.qml` and a `widget.json` descriptor (`id`, translation `key`,
`defaultEnabled`, required `services`). Adding a widget is a new
directory plus an id in those arrays — no central switch.

| id | i18n key | services | role |
|---|---|---|---|
| `launcher` | `bar.launcher` | Launcher | Opens the application launcher |
| `workspaces` | `bar.workspaces` | Hypr | Per-monitor strip (`Hypr.workspacesFor`); `monitors.workspaceMode` `dynamic` or `fixed` (1–5 / 6–10 by x-position) |
| `tray` | `bar.tray` | — | Status notifier / system tray |
| `taskbar` | `bar.taskbar` | Hypr | Open windows on the active workspace |
| `clock` | `bar.clock` | — | Date/time from `language.*` formats; click launches `apps.defaults.calendar` |
| `media` | `bar.media` | Media | Capsule (art, title, transport); hidden with no MPRIS client; click raises the player |
| `audio` | `bar.volume` | Audio | Sink volume / mute; click opens Settings → Audio |
| `weather` | `bar.weather` | Weather | Location-based conditions |
| `network` | `bar.network` | Network | Wi-Fi / ethernet indicator |
| `microphone` | `bar.microphone` | Audio | Source volume / mute |
| `performance` | `bar.performance` | SystemStats | CPU / RAM / GPU poll (timer off when hidden) |
| `vpn` | `bar.vpn` | Vpn | VPN connection state |
| `bluetooth` | `bar.bluetooth` | Bluetooth | Adapter + connected devices |
| `notifications` | `bar.notifications` | Notifications | Unread / DND affordance |
| `settings` | `bar.settings` | Notifications | Opens the control center (`Notifications.toggle`), not the Settings app |
| `power` | `bar.power` | PowerMenu | Session power menu |

| `ai` | `ai.title` | Ai | Assistant chat popup |
| `connectivity` | `bar.connectivity` | Network, Bluetooth | Combined wifi + BT; click opens Settings |
| `battery` | `bar.battery` | Battery | Shown only on battery |

Default layout (islands) in `stow/modern/.config/modern/config.default.json`:

- `bar.left`: `launcher`, `ai`, `workspaces`, `media`, `tray`
- `bar.center`: `clock` (calendar popup)
- `bar.right`: `weather`, `connectivity`, `audio`, `battery`, `settings`, `power`

`bar.position` is `top` / `bottom` / `left` / `right`. Default height is 36.
Wi-Fi and Bluetooth on the bar open Settings, not a popup. AI, weather, and
clock use `MPopup`. Reorder in Settings → Widgets.

