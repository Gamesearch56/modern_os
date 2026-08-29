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
| `gaming` | `system` (subsection `gaming`) |
| `display` | `displays` |
| `screenshot` | `screenshots` |

## Nav map

Six groups, 19 pages. Catalog lives in
`Modules/Settings/Catalog.qml` (`groupOrder` + `_byId`). Search uses
`section.json` keywords **and** that catalog.

| Group | Page | Id | Config / Services |
|-------|------|----|-------------------|
| General | Overview | `overview` | `Diagnostics`, `SystemStats`, `Battery` |
| General | Users | `users` | `general.autologin`; `Passwd`, `User` |
| General | Privacy | `privacy` | `general.dndSchedule`, `kdeconnect`, `accounts.protonDrive`, `accounts.calendarIcsUrl` |
| General | Energy | `power` | `power.*`, `general.idleTimings`; `Battery`, `SystemStats` |
| Appearance | Design | `design` | `design.*`, `typography`, `motion`, `windows.*`, `windowRules`; `Theme`, `Wallpaper` |
| Appearance | Bar | `bar` | `bar.left\|center\|right`, `bar.autoHide`, `widgets.*` |
| Appearance | Launcher | `launcher` | `launcher.*` |
| Apps | Applications | `applications` | `apps.defaults`, `general.autostart` |
| Apps | Screenshot | `screenshots` | `screenshots.*` |
| Apps | AI | `ai` | `accounts.ai` |
| Input | Language & Region | `language` | `language.*` (incl. `previewDate`); `Locale` (`timedatectl`) |
| Input | Keyboard | `keyboard` | `input.*`, `keybinds`; `Cheatsheet` |
| Devices | Display | `displays` | `monitors.*`; `Hypr` |
| Devices | Audio | `audio` | `audio.*`; `Audio` (PipeWire streams when present) |
| Devices | Network | `network` | `network.*`; `Network` (Wi-Fi password overlay, curl speed test) |
| Devices | Bluetooth | `bluetooth` | `Bluetooth` |
| System | Storage | `storage` | `Storage` |
| System | Backup | `backup` | `backup.*`; `Snapshots` (snapper list/delete) |
| System | System | `system` | `gaming.*`; `Update` (`modern update`, `modern mirrors`) |

`language.previewDate` is UI-only (`DateTime.displayDate`) — it does not
call `timedatectl`. Timezone display/set is `Services/Locale.qml`.

## Bar widget forms

Click a widget on Settings → Bar. Overlay fields (when the widget has
them): weather location/units, clock seconds/weekday, performance
poll/GPU/temps, audio scroll steps. Drag reorders within
`bar.left`, `bar.center`, or `bar.right`. Enable/disable from the
catalog list.

## Update, mirrors, backup

| Action | CLI | Notes |
|--------|-----|--------|
| System update | `modern update` | Overlay: current step + log. Snapshot-before-update if `backup.preUpdateSnapshot`. |
| Mirrorlist | `modern mirrors` | `reflector` using `network.mirrorCountry`. Also a button on System. |
| Snapshots | `snapper -c root list` / `delete` | Settings lists and can request delete. **Restore** is gated (`docs/BACKUP.md`). Enabling `backup.snapperEnabled` does not write `/etc/snapper`. |

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
