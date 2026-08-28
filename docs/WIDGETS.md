# Bar widgets

The bar is three id lists in `config.json` (`bar.left`, `bar.center`,
`bar.right`). Each id maps to `Modules/Bar/widgets/<id>/` with
`Widget.qml` and a `widget.json` descriptor (`id`, translation `key`,
`defaultEnabled`, required `services`). Adding a widget is a new
directory plus an id in those arrays — no central switch.

| id | i18n key | services | role |
|---|---|---|---|
| `launcher` | `bar.launcher` | Launcher | Opens the application launcher |
| `workspaces` | `bar.workspaces` | Hypr | Hyprland workspace strip |
| `tray` | `bar.tray` | — | Status notifier / system tray |
| `taskbar` | `bar.taskbar` | Hypr | Open windows on the active workspace |
| `clock` | `bar.clock` | — | Date/time from `widgets.clock` formats |
| `media` | `bar.media` | Media | MPRIS now-playing + transport |
| `audio` | `bar.volume` | Audio | Sink volume / mute |
| `weather` | `bar.weather` | Weather | Location-based conditions |
| `network` | `bar.network` | Network | Wi-Fi / ethernet indicator |
| `microphone` | `bar.microphone` | Audio | Source volume / mute |
| `performance` | `bar.performance` | SystemStats | CPU / RAM / GPU poll (timer off when hidden) |
| `vpn` | `bar.vpn` | Vpn | VPN connection state |
| `bluetooth` | `bar.bluetooth` | Bluetooth | Adapter + connected devices |
| `notifications` | `bar.notifications` | Notifications | Unread / DND affordance |
| `settings` | `bar.settings` | Settings | Opens Settings (`Services/Settings.openAt`) |
| `power` | `bar.power` | PowerMenu | Session power menu |

Default layout is shipped in `stow/modern/.config/modern/config.default.json`.
Reorder by editing those arrays in Settings > Widgets (or `config.json`);
the bar `Repeater`s consume them directly.
