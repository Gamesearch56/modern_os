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
| General | Users | `users` | `general.autologin` writes `config.json`, then `Autologin` pkexecs `scripts/autologin-apply.sh` so the next reboot opens this account (greetd `[initial_session]`, or `getty@tty1` when greetd is not the display manager). `Passwd`, `User`, `Apps.runInTerminal` for confirmed terminal login. Groups are read-only; no usersd edit overlays. |
| General | Privacy | `privacy` | Live `Notifications.dnd` (same as the control-panel tile) plus applied `general.dndSchedule` quiet hours; `general.notificationTimeoutMs`. `kdeconnect.enabled` starts/stops `kdeconnectd`. `accounts.calendarIcsUrl` feeds the clock popup. No Proton Drive UI. |
| General | Energy | `power` | Live `Battery` hero. Power button (`ask` = power menu) and lid actions via `modern power`. `IdleDaemon` runs `scripts/hypridle-apply.sh` on each `config.json` load so `hypridle` listeners match `general.idleTimings` (nested JsonObject ints do not always notify). Fullscreen/media idle inhibit via `org.freedesktop.ScreenSaver` (`scripts/idle-inhibit.sh`). |
| Appearance | Design | `design` | Wallpaper gallery + four derived theme profiles (`Theme`, `Wallpaper`). `design.*`, `typography`, `motion`, `windows.*`, `windowRules`. Animations and cursor theme are selects; cursor list comes from installed `cursors/` themes. Changing a knob writes `config.json` then applies live: shell chrome (transparency, rounding, type scale, motion), Hyprland (`hyprctl keyword` / reload for animations), cursor (`cursor-apply.sh` + GTK/Qt), and toolkit chrome (`theme-apply.sh --chrome-only` for GTK/Qt/KDE/Vivaldi radii and fonts). |
| Appearance | Bar | `bar` | `bar.position`, `bar.style`, `bar.height`, `bar.edgeGap`, `bar.endGap`, `bar.autoHide`, `bar.left\|center\|right`, `widgets.*`. Islands drag across left/middle/right (`MSlotBoard`); enabling a widget appends to `bar.left`. Auto-hide slides the bar to an edge strip. |
| Appearance | Launcher | `launcher` | `launcher.frecencyEnabled`, `launcher.showIcons`, `launcher.showDescriptions`, `launcher.resultCount`, `launcher.mostUsedGridSize`. Prefixes in `launcher.providers` stay in config for a future provider layer; Settings does not edit them. |
| Apps | Applications | `applications` | `apps.defaults` (browser Vivaldi; calendar/mail/messenger are Vivaldi `--app=` windows: Proton Calendar, Proton Mail, WhatsApp). Proton Drive is a launcher-only desktop entry, not a default role and not autostarted. File manager Nautilus, video player mpv, image viewer imv, terminal kitty. `general.autostart` starts mail, calendar, and WhatsApp on `special:background` via `hl.exec_cmd` (Hyprland 0.56 rejects `hyprctl dispatch exec`) so they keep notifying; those ids are locked on the autostart list. First WhatsApp Web pairing needs a visible window to scan the QR — open it from the launcher once. Shortcuts go through `scripts/modern-launch` and those defaults, not hardcoded binaries. Changing video player, image viewer, file manager, or mail also updates `~/.config/mimeapps.list` via `scripts/mime-defaults.sh` (`mailto:` follows the mail app; Nautilus/`xdg-open` follow the rest). |
| Apps | Recording | `screenshots` | Stills: `screenshots.format` (PNG/JPEG/WebP), `quality`, `directory`, `copyToClipboard`, `openEditorAfterCapture`, `includeCursor` via `scripts/screenshot.sh` (grim). Video: `screenshots.videoDirectory`, `videoFilenameTemplate`, `recordAudio` via `scripts/screencast.sh` (`wf-recorder`). |
| Apps | Gaming | `gaming` | `gaming.autoFullscreen` / `gaming.autoOptimize` for Steam, gamescope, Wine, and native titles such as Project Zomboid. Per-window Hyprland rules only — see `docs/GAMING.md`. |
| Apps | AI | `ai` | `accounts.ai` (Ollama, Gemini, or Off). Ollama models come from a running daemon; if it is missing or stopped, Settings defaults that provider to Off and shows install steps. Gemini uses a Google AI Studio API key in gitignored `secrets.json` (or `GEMINI_API_KEY`); Pro quota follows the Google account that created the key. |
| Keyboard & Region | Language & Time | `language` | `language.ui`, `firstDayOfWeek`, `dateFormat`, `timeFormat`. Clock weekday/seconds live under Settings → Bar. |
| Keyboard & Region | Keyboard | `keyboard` | `input.kbLayout` (searchable select from `keyboard-layouts.json`, same catalog as the installer Keyboard step; default `us`), `repeatRate`, `repeatDelay`, `numlockOnBoot` (off by default) applied live (`hyprctl eval`). Cheat sheet button opens `Cheatsheet` (Super+K), including the Mouse category for Super+mouse and edge resize. |
| Devices | Display | `displays` | `monitors.workspaceMode` (default **dynamic**; **fixed** keeps 1–5 / 6–10 / 11–15 / … by x-position). Per-profile `scale`, `mode` (resolution + refresh), `cm`, `hdr`, `vrr` on the selected display (`desc:` + serial). Brightness via `Brightness` when DDC/backlight matches that panel. |
| Devices | Audio | `audio` | `audio.masterVolumeLimit`; bar/Settings master is the sink (`audio.masterVolume`). 0% / mute also mutes every app stream. `audio.autoSwitchBluetooth` (on/off, default on) trusts paired Bluetooth audio, connects them only while the PC has active playback (A2DP default sink), and disconnects after idle so a phone can keep multipoint. The BlueZ mic is not auto-selected (that forced HFP). Speaker and microphone headings have a **Set default** button: **None** restores the last non-Bluetooth endpoint after a Bluetooth disconnect; a chosen device is used instead. The live device lists still switch output and input immediately. Per-app streams with icon and mute via `Audio`. |
| Devices | Network | `network` | Wi-Fi radio, nearby networks, ethernet status, curl speed test (`Network` / `scripts/network-speed.sh`: four parallel Arch-ISO downloads, 15s, so a gigabit link can fill). A network opens the same dialog as Bluetooth: connect, disconnect, forget. Passwords go through `scripts/wifi-join.sh` (`nmcli`), which activates the network instead of only saving it. The bar icon is Wi-Fi when a wireless network is up, Ethernet only when a physical cable is up. Mirror country stays on Update / `modern mirrors`; DNS override is not applied. |
| Devices | Bluetooth | `bluetooth` | Adapter power, nearby/connected lists, connect/disconnect/forget via `Bluetooth` (BlueZ). |
| System | Storage | `storage` | System-disk remaining space plus a category chart (`StorageUsage` / `scripts/storage-usage.sh`: games, files, programs, cache, snapshots). **Clean up** is one `pkexec` of `scripts/storage-clean.sh`: unused package files (`paccache`), logs older than 14 days, and regenerable caches (thumbnails, GPU, fonts) — never documents, photos, or games. Other internal disks and external drives via `Storage` (`lsblk`). Open uses `xdg-open`; eject uses `udisksctl` unmount + power-off. |
| System | Backup | `backup` | Live Snapper status (`Snapshots`). `backup.preUpdateSnapshot` drives `modern update`. `backup.pruneEnabled` / `backup.keepCount` (3–20, default 8) prune oldest snapshots via `pkexec` of `scripts/snapper-gc.sh`. Create/delete/clear via the same service. Restore is one `pkexec` of `scripts/snapper-restore.sh` (replaces `@`, leaves `/home`, then reboots). |
| System | Firewall | `firewall` | Live UFW (`Firewall`). Status is unprivileged (`scripts/ufw-status.sh` reads `/etc/ufw`). Enable/disable is one `pkexec` of `scripts/ufw-apply.sh`. Allow/deny add/delete via `pkexec /usr/bin/ufw`. Rules persist in `/etc/ufw`. Enable forces deny incoming, allow outgoing, deny routed. No `config.json` keys, no Restore, no `ufw reset`. |
| System | Update | `system` | Pending packages via `checkupdates` (`Update`). `modern update` / `modern mirrors` (pkexec from Settings). |

## App Store

A Hyprland `FloatingWindow` titled `modern.store` (control panel header
opens it; Super+Q is `killactive`). Chrome title is **App Store**. It
installs and removes official Arch packages only — no `-Sy`/`-Syu`.
System upgrades stay on Settings → System.

- Catalog: `~/.config/modern/store/catalog.json` (popular grid +
  category allowlists). Discover shows Popular (6) then each category
  (6, three per row). Installed is `pacman -Qe`, not a name list.
- Search: `scripts/pkg-search.sh` (`pacman -Ss`). Info:
  `scripts/pkg-info.sh`. Mutate: `scripts/pkg-mutate.sh` via
  `/usr/bin/pkexec /usr/bin/pacman` only (no `PACMAN=` override, no
  shell). Install preflights `pacman -Si`; remove preflights `pacman -Q`
  and refuses a protected set (glibc, pacman, systemd, hyprland,
  quickshell, …). Remove is `-R` of that name only (`-s`/`-n` stay off).
  The shell never SIGKILLs an in-flight transaction. `pkg-mutate.sh`
  starts `phylax.service` if it is down so the password window can
  appear; Cancel is allowed only while still waiting for that prompt.
- Updates button appears only when `Update.pending` is non-empty
  (label without a count; `MBadge` pill is the count) and opens
  Settings → System. IPC: `qs -c modern ipc call store toggle`.


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
| System update | `modern update` | Overlay with live log and progress. **ModernOS** is always first under System packages (`desktop-sync.sh`). Pending only when this clone is behind the latest GitHub release tag `vX.Y.Z` (`docs/GIT.md`) — not `dev` / `main` tip. Apply (ff-only checkout of that tag + `install.sh --profile m0 --yes`) runs before `pacman -Syu`; a failed apply does not start pacman. Without a terminal `install.sh` cannot sudo, so it writes missing native packages and the greetd step to a root plan (`$XDG_STATE_HOME/modern/root-plan`). One `pkexec` of `scripts/update-apply.sh` then runs Snapper (if `backup.preUpdateSnapshot`), `pacman -Syu`, and the plan. The plan is kept until that step succeeds, so a cancelled prompt is retried by the next update. The UI reload (`reload-ui.sh`, detached) runs last, only after a desktop release; `update-applied` in the state dir carries the version to the reloaded shell, which shows it as a toast (`modern update-notice`). Simulated end to end by `scripts/test-update-apply.sh`. When `~/.config/modern/deploy_key` is present (the ISO embeds gitignored `secrets/github-deploy-key`), the release check uses that read-only key over SSH; otherwise it stays on HTTPS (`docs/GIT.md`). |
| Mirrorlist | `modern mirrors` | `reflector --protocol https` using `network.mirrorCountry` (pacman/libcurl cannot use `rsync://`). **Update mirrors** sits next to **Update system**. **Search for Updates** on the status card re-runs `checkupdates` and shows a spinner while it runs. |
| Snapshots | `snapper-setup.sh` / `snapper-gc.sh` / `snapper-restore.sh` | Settings writes the Snapper `root` config with one `pkexec` of `scripts/snapper-setup.sh` (keeps an existing `/.snapshots` mount). It lists snapshots with timestamps, can create, delete, prune, clear, and restore. Restore clones the snapshot over `@` (`scripts/snapper-restore.sh`) and reboots; `/home` stays. |
| Firewall | `ufw-status.sh` / `ufw-apply.sh` / `allow` / `deny` / `delete NUM` | Settings lists numbered allow/deny rules from `/etc/ufw` without a password. Enable and disable are one `pkexec` of `ufw-apply.sh` (defaults + `--force enable` in that process). Add and delete use `pkexec /usr/bin/ufw`. Disable asks for confirmation. No `reset`, no default-allow, no config.json copy of rules. |

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
