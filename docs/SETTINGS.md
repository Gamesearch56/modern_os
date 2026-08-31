# System Settings

The desktop's control surface. It is a Hyprland `FloatingWindow` titled
`modern.settings` (Super+I opens it, Super+Q is `killactive`). The chrome
title is **System Settings**. It writes `config.json` only — never Lua,
QML, or shell scripts. Gated `/etc` work still lives under
`install/system/` and `docs/ISOLATION.md`.

Deep links: `Settings.openAt(section, subsection)` in
`Services/Settings.qml`. Aliases keep old ids working:

| Alias | Resolves to |
|-------|-------------|
| `general` | `overview` |
| `time` | `language` |
| `accounts` | `privacy` |
| `widgets` | `bar` |
| `windows` | `design` (subsection `windows`) |
| `display` | `displays` |
| `screenshot` | `screenshots` |
| `games` | `gaming` |

## Nav map

Six groups, 21 pages. Catalog lives in
`Modules/Settings/Catalog.qml` (`groupOrder` + `_byId`). Search uses
`section.json` keywords **and** that catalog.

| Group | Page | Id | Config / Services |
|-------|------|----|-------------------|
| General | Overview | `overview` | `Diagnostics`, `SystemStats`, `Battery` |
| General | Users | `users` | `general.autologin` preference plus a gated-boot hint (not applied from Settings). `Passwd`, `User`, `Apps.runInTerminal` for confirmed terminal login. Groups are read-only; no usersd edit overlays. |
| General | Privacy | `privacy` | Live `Notifications.dnd` (same as the control-panel tile) plus applied `general.dndSchedule` quiet hours; `general.notificationTimeoutMs`. `kdeconnect.enabled` starts/stops `kdeconnectd`. `accounts.calendarIcsUrl` feeds the clock popup. No Proton Drive UI. |
| General | Energy | `power` | Live `Battery` hero. Power button (`ask` = power menu) and lid actions via `modern power`. `hypridle` listeners from `general.idleTimings`. Fullscreen/media idle inhibit via `systemd-inhibit`. |
| Appearance | Design | `design` | Wallpaper gallery + four derived theme profiles (`Theme`, `Wallpaper`). `design.*`, `typography`, `motion`, `windows.*` (no title-bar toggle), `windowRules`. Animations and cursor theme are selects; cursor list comes from installed `cursors/` themes. Changing a knob writes `config.json` then applies live: shell chrome (transparency, rounding, type scale, motion), Hyprland (`hyprctl keyword` / reload for animations), cursor (`cursor-apply.sh` + GTK/Qt), and toolkit chrome (`theme-apply.sh --chrome-only` for GTK/Qt/KDE/Vivaldi radii and fonts). |
| Appearance | Bar | `bar` | `bar.position`, `bar.style`, `bar.height`, `bar.edgeGap`, `bar.endGap`, `bar.autoHide`, `bar.left\|center\|right`, `widgets.*`. Islands drag across left/middle/right (`MSlotBoard`); enabling a widget appends to `bar.left`. Auto-hide slides the bar to an edge strip. |
| Appearance | Launcher | `launcher` | `launcher.frecencyEnabled`, `launcher.showIcons`, `launcher.showDescriptions`, `launcher.resultCount`, `launcher.mostUsedGridSize`. Prefixes in `launcher.providers` stay in config for a future provider layer; Settings does not edit them. |
| Apps | Applications | `applications` | `apps.defaults` (browser Vivaldi, calendar/mail Proton Mail, messenger empty with WhatsApp fallback, file manager Nautilus with Dolphin selectable, video player mpv, image viewer imv, terminal kitty), `general.autostart`. Calendar/mail/messenger ids are locked on the autostart list. Shortcuts go through `scripts/modern-launch` and those defaults, not hardcoded binaries. Changing video player, image viewer, or file manager also updates `~/.config/mimeapps.list` via `scripts/mime-defaults.sh` so Nautilus/Dolphin/`xdg-open` (Steam “Browse files”, etc.) follow the same apps. |
| Apps | Recording | `screenshots` | Stills: `screenshots.format` (PNG/JPEG/WebP), `quality`, `directory`, `copyToClipboard`, `openEditorAfterCapture`, `includeCursor` via `scripts/screenshot.sh` (grim). Video: `screenshots.videoDirectory`, `videoFilenameTemplate`, `recordAudio` via `scripts/screencast.sh` (`wf-recorder`). |
| Apps | Gaming | `gaming` | `gaming.autoFullscreen` / `gaming.autoOptimize` for Steam, gamescope, and Wine windows. Per-window Hyprland rules only — see `docs/GAMING.md`. |
| Apps | AI | `ai` | `accounts.ai` (Ollama or Off). Model list comes from a running Ollama daemon. If Ollama is missing or stopped, Settings defaults the assistant to Off and shows the install steps. |
| Keyboard & Region | Language & Time | `language` | `language.ui`, `firstDayOfWeek`, `dateFormat`, `timeFormat`. Clock weekday/seconds live under Settings → Bar. |
| Keyboard & Region | Keyboard | `keyboard` | `input.kbLayout`, `repeatRate`, `repeatDelay`, `numlockOnBoot` (off by default) applied live (`hyprctl eval`). Cheat sheet button opens `Cheatsheet` (Super+K). |
| Devices | Display | `displays` | `monitors.workspaceMode` (default **dynamic**; two-monitor `fixed` keeps 1–5 / 6–10). Per-profile `scale`, `mode` (resolution + refresh), `cm`, `hdr`, `vrr` on the selected display (`desc:` + serial). Brightness via `Brightness` when DDC/backlight matches that panel. |
| Devices | Audio | `audio` | `audio.masterVolumeLimit`; `audio.autoSwitchBluetooth` (on/off, default on) trusts and connects paired Bluetooth audio, then sets the PipeWire default sink/source when a BlueZ endpoint appears. Per-app streams with icon and mute via `Audio`. |
| Devices | Network | `network` | Wi-Fi radio, nearby networks, ethernet status, curl speed test (`Network`). Mirror country stays on Update / `modern mirrors`; DNS override is not applied. |
| Devices | Bluetooth | `bluetooth` | Adapter power, nearby/connected lists, connect/disconnect/forget via `Bluetooth` (BlueZ). |
| System | Storage | `storage` | Internal and external drive cards via `Storage` (`lsblk`, sysfs link speed). Eject uses `udisksctl` unmount + power-off. |
| System | Backup | `backup` | Live Snapper status (`Snapshots`). `backup.preUpdateSnapshot` drives `modern update`. Create/delete via `pkexec snapper`. Restore is gated. |
| System | Firewall | `firewall` | Live UFW (`Firewall`). Enable/disable and allow/deny rules via `pkexec /usr/bin/ufw`. Rules persist in `/etc/ufw`. Enable forces deny incoming, allow outgoing, deny routed. No `config.json` keys, no Restore, no `ufw reset`. |
| System | Update | `system` | Pending packages via `checkupdates` (`Update`). `modern update` / `modern mirrors` (pkexec from Settings). |

## Restore defaults

Privacy, Energy, Design, Bar, Launcher, Applications, Screenshot,
Gaming, Language & Time, and Keyboard show **Restore** on the page header.
Confirm copies that page’s keys from `config.default.json` via
`modern config restore` (one jq write). Privacy also clears session
DND and does not reset `accounts.calendarIcsUrl`. Design re-runs `theme-apply.sh` so the palette matches the
restored profile. Overview, Users, AI, devices, Storage, Backup, Firewall, and
Update have no Restore control.


## Bar widget forms

Click a widget on Settings → Bar. Overlay fields (when the widget has
them): weather location/units, clock seconds/weekday, audio scroll
steps (Shift+wheel uses the fine step). Customizable widgets (clock,
weather, volume) use a hover outline instead of a gear. Drag rows
across the three-column Left / Middle / Right table; enable/disable
from Available widgets (on → left). Auto-hide stays pinned open while
a bar popup is showing.

## Update, mirrors, backup

| Action | CLI | Notes |
|--------|-----|--------|
| System update | `modern update` | Overlay with live log and progress. Auto-closes on success and posts a notification. Snapshot-before-update if `backup.preUpdateSnapshot` and Snapper is ready; otherwise the update still runs. |
| Mirrorlist | `modern mirrors` | `reflector` using `network.mirrorCountry`. **Update mirrors** sits next to **Update system**. **Search for Updates** on the status card re-runs `checkupdates` and shows a spinner while it runs. |
| Snapshots | `snapper -c root list` / `create` / `delete` | Settings lists snapshots with timestamps, can create (pkexec), and can request delete. **Restore** is gated (`docs/BACKUP.md`). The Snapper/Restic enable toggles were removed: they did not write `/etc/snapper` or configure a restic repo. |
| Firewall | `ufw status numbered` / `enable` / `disable` / `allow` / `deny` / `delete NUM` | Settings lists numbered allow/deny rules, can add (port required) and delete. Enable sets deny incoming, allow outgoing, deny routed, then `--force enable`. Disable asks for confirmation. No `reset`, no default-allow, no config.json copy of rules. |

## How to add a page

1. `Modules/Settings/sections/<id>/{Section.qml,Model.qml,section.json,qmldir}`
2. Register the id in **`Modules/Settings/Catalog.qml`** (`ids`, `_byId`,
   `groupOrder` if you add a group). Search does **not** pick up a folder
   that is missing from the catalog.
3. Add `settings.sections.<id>` (and nav group if new) to both
   `translations/en.json` and `de.json`.
4. If old deep links must keep working, add an alias in
   `Services/Settings.qml` `resolve()`.

Keep section files near ~200 lines; split subsections (`Windows.qml`,
`Gaming.qml`, overlays) and load them with `Loader`.

## Design rules

Match the control panel: `Colors.color.surface`, `Tokens.radius.medium`,
`outlineVariant` hairline, `Config.design.transparency`. Overlays use
`MOverlay` / `MDialog`. Charts use `MSparkline` / `MLinearProgress`.
No hex, no Module-spawned processes, every user-visible string through
`I18n.t()`.
