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

Six groups, 22 pages. Catalog lives in
`Modules/Settings/Catalog.qml` (`groupOrder` + `_byId`). Search uses
`section.json` keywords **and** that catalog.

| Group | Page | Id | Config / Services |
|-------|------|----|-------------------|
| General | Overview | `overview` | `Diagnostics`, `SystemStats`, `Battery`. The page title row carries a Ko-fi button on the right (`Support`, https://ko-fi.com/gamesearch56); it opens the page in the browser and closes Settings. |
| General | Users | `users` | Compact session card (`User` + autologin). `general.autologin` writes `config.json`, then `Autologin` pkexecs `scripts/autologin-apply.sh` so the next reboot opens this account (greetd `[initial_session]`, or `getty@tty1` when greetd is not the display manager). Other people and groups add/edit/delete through one `pkexec` of `scripts/usersd.sh` (JSON stdin, `auth_admin`). The session account, uid 0, and the last administrator cannot be deleted. Self password is `passwd` in the terminal; display name is GECOS via the same `usersd.sh` update (`chfn` as root). |
| General | Privacy | `privacy` | Live `Notifications.dnd` (same as the control-panel tile) plus applied `general.dndSchedule` quiet hours; `general.notificationTimeoutMs`. `kdeconnect.enabled` starts/stops `kdeconnectd`. Calendar connect lives on the Date and time widget. No Proton Drive UI. |
| General | Energy | `power` | Live battery remaining / time-to-full, draw, health, energy, cycles (`Battery` / `scripts/battery-read.sh`). Power button (`ask` = power menu) and lid actions (lid hidden on AC-only PCs) via `modern power` (`session lock` / `systemctl suspend`). `scripts/logind-handles.sh` blocks logind's default lid and power-key so those settings win. `IdleDaemon` runs `scripts/hypridle-apply.sh` on each `config.json` load so `hypridle` listeners match `general.idleTimings`. Fullscreen/media idle inhibit via `org.freedesktop.ScreenSaver` (`scripts/idle-inhibit.sh`). |
| Appearance | Design | `design` | Wallpaper gallery + four derived theme profiles (`Theme`, `Wallpaper`). `design.*`, `typography`, `motion`, `windows.*`, `windowRules`. Animations and cursor theme are selects; cursor list comes from installed `cursors/` themes. Changing a knob writes `config.json` then applies live: shell chrome (transparency, rounding, type scale, motion), Hyprland (`hyprctl keyword` / reload for animations), cursor (`cursor-apply.sh` + GTK/Qt), and toolkit chrome (`theme-apply.sh --chrome-only` for GTK/Qt/KDE/Vivaldi radii and fonts). |
| Appearance | Bar | `bar` | `bar.position`, `bar.height`, `bar.edgeGap`, `bar.endGap`, `bar.autoHide`, `bar.left\|center\|right`, `widgets.*`. Islands drag across left/middle/right (`MSlotBoard`); enabling a widget appends to `bar.left`. Auto-hide slides the bar off the screen; the outer edge brings it back. |
| Appearance | Dock | `dock` | `dock.enabled` (off), `dock.autoHide`, `dock.iconSize` (48), `dock.showNames` (off), `dock.pad`, `dock.gap` (8), `dock.theme` (`floating` by default, also `beam` and `inventory`), `dock.hover` (`zoom`, `color`, `bounce`, `lift`, `none`), `dock.apps` (Vivaldi, WhatsApp, Spotify, Steam, Kitty, the file manager, the app store, Settings). The edge is the opposite of `bar.position` and is not stored. Pins are rearranged in this page, or on the dock while the launcher is open. Dragging a dock icon shows a trash target; a drop there removes the pin. Restore resets every dock setting except `dock.enabled` and leaves `dock.apps` in place. A desktop file that disappears is dropped from the dock, the launcher's remembered launches, autostart, and any default-app role that pointed at it (`AppsPrune`). |
| Appearance | Launcher | `launcher` | `launcher.frecencyEnabled`, `launcher.showIcons`, `launcher.showDescriptions`, `launcher.resultCount`, `launcher.mostUsedGridSize`. Prefixes in `launcher.providers` stay in config for a future provider layer; Settings does not edit them. |
| Apps | Applications | `applications` | `apps.defaults` (browser Vivaldi; calendar/mail/messenger are Vivaldi `--app=` windows on that same profile: Proton Calendar, Proton Mail, WhatsApp). Proton Drive is a launcher-only desktop entry, not a default role and not autostarted. File manager is the ModernOS File Manager (`modern.files`); text editor defaults to ModernOS Texteditor (`modern.editor`, shown as "Texteditor" in the launcher; prefs in `config.editor`, see `docs/EDITOR.md`); image viewer defaults to ModernOS Imageviewer (`modern.imageviewer`, shown as "Imageviewer" in the launcher; prefs in `config.viewer`, see `docs/VIEWER.md`); video player defaults to ModernOS Mediaplayer (`modern.mediaplayer`, shown as "Mediaplayer" in the launcher; prefs in `config.player`, see `docs/PLAYER.md`). Video player, image viewer, and text editor are `apps.defaults` (`videoPlayer`, `imageViewer`, `textEditor`). Packages and launch overrides for those three roles are `install/manifests/default-apps.json`. Terminal kitty. `general.autostart` starts mail, calendar, and WhatsApp on `special:background` via `hl.exec_cmd` (Hyprland 0.56 rejects `hyprctl dispatch exec`) so they keep notifying; those ids are locked on the autostart list. First WhatsApp Web pairing needs a visible window to scan the QR — open it from the launcher once. Shortcuts go through `scripts/modern-launch` and those defaults, not hardcoded binaries. Changing video player, image viewer, text editor, file manager, or mail also updates `~/.config/mimeapps.list` via `scripts/mime-defaults.sh` (`mailto:` follows the mail app; `xdg-open` follows the rest). |
| Apps | Recording | `screenshots` | Stills: `screenshots.format` (PNG/JPEG/WebP), `quality`, `directory`, `copyToClipboard`, `openEditorAfterCapture`, `includeCursor` via `scripts/screenshot.sh` (grim). Video: `screenshots.videoDirectory`, `videoFilenameTemplate`, `recordAudio` via `scripts/screencast.sh` (`wf-recorder`). |
| Apps | Gaming | `gaming` | `gaming.autoFullscreen` / `gaming.autoOptimize` (off) for Steam, gamescope, Wine, and native titles such as Project Zomboid. The speed switch turns both `autoOptimize` and `browserLight` on. It is the low-end hardware mode: blur, shadows, and wobble go off desktop-wide, windows and shell panels turn opaque (`Commons/Chrome.lightEffects`, `modules/light_effects.lua`), `MCard` drops its offscreen layer, and games get tearing plus direct scanout. Vivaldi starts without a separate graphics process. Mail, calendar, and WhatsApp are app windows of that same browser. See `docs/GAMING.md`. |
| Apps | AI | `ai` | `accounts.ai` (Ollama, Gemini, ChatGPT, or Off). Ollama models come from a running daemon; if it is missing or stopped, Settings defaults that provider to Off and shows install steps. Gemini uses a Google AI Studio API key in gitignored `secrets.json` (or `GEMINI_API_KEY`). A valid key still needs API quota; prepaid credits, a daily quota, or a spend limit is reported on the reply and Settings offers the billing page. ChatGPT uses an OpenAI API key in the same file (`openai.apiKey`, or `OPENAI_API_KEY`). A valid key still needs API credits; a credit or spend limit comes back as HTTP 429 and Settings offers the billing page. Thinking and short replies apply to Ollama, Gemini, and ChatGPT. |
| Keyboard & Region | Language & Time | `language` | `language.ui`, `firstDayOfWeek`, `dateFormat`, `timeFormat`. Clock weekday/seconds live under Settings → Bar. |
| Keyboard & Region | Keyboard | `keyboard` | `input.kbLayout` (searchable select from `keyboard-layouts.json`, same catalog as the installer Keyboard step; default `us`), `repeatRate`, `repeatDelay`, `numlockOnBoot` (off by default) applied live (`hyprctl eval`). Cheat sheet button opens `Cheatsheet` (Super+K), including the Mouse category for Super+mouse and edge resize. |
| Devices | Display | `displays` | `monitors.workspaceMode` (default **dynamic**; **fixed** keeps 1–5 / 6–10 / 11–15 / … by x-position). Per-profile `scale`, `mode` (resolution + refresh), `cm`, `hdr`, `vrr` on the selected display (`desc:` + serial). Brightness via `Brightness` when DDC/backlight matches that panel. |
| Devices | Audio | `audio` | `audio.masterVolumeLimit`; bar/Settings master is the sink (`audio.masterVolume`). 0% / mute also mutes every app stream. `audio.autoSwitchBluetooth` (on/off, default on) trusts paired Bluetooth audio when no search is running, so the headset can reconnect on its own. WirePlumber does not page it (`bluez5.auto-connect` empty, no dummy AVRCP player, no automatic headset profile). A Bluetooth sink that appears (the headset connected) becomes the default A2DP output; when it disappears, the fallback endpoint (or the last non-Bluetooth speaker) plays again. The shell never connects a headset itself, and endpoints already present at startup are left alone. The BlueZ mic is not auto-selected (that forced HFP). Speaker and microphone headings have a **Set default** button: **None** restores the last non-Bluetooth endpoint after a Bluetooth disconnect; a chosen device is used instead. The live device lists still switch output and input immediately. Per-app streams with icon and mute via `Audio`. |
| Devices | Network | `network` | Wi-Fi radio, nearby networks, ethernet status, curl speed test (`Network` / `scripts/network-speed.sh`: four parallel Arch-ISO downloads, 15s, so a gigabit link can fill). Opening the page, or turning Wi-Fi on, runs one `nmcli --rescan`. The list is connected, then saved, then the rest; within each, more signal bars first (`Services/signalLevel.js`, 0–4 bars so drift between scans does not reshuffle the list), then by name. Every row shows its bars (`MSignal`); a saved network in the list is tagged `settings.network.remembered`. A network opens the same dialog as Bluetooth: connect, disconnect, forget. Passwords go through `scripts/wifi-join.sh` (`nmcli`), which activates the network instead of only saving it. The password reaches the script on stdin and nmcli through a 0600 `passwd-file` in `$XDG_RUNTIME_DIR`, never argv (`/proc/*/cmdline` is world-readable); the installer's Network step runs the same script from `/usr/lib/modern/`. Exit codes 3 wrong password, 4 out of range, 5 timeout, 6 unsupported security (802.1X, WEP, OWE) map to `settings.network.fail.*`, shown in the dialog and as a toast for joins started from the bar. The bar icon is Wi-Fi when a wireless network is up, Ethernet only when a physical cable is up. Mirror country stays on Update / `modern mirrors`; DNS override is not applied. |
| Devices | Bluetooth | `bluetooth` | Adapter power, nearby/connected lists, connect/disconnect/forget via `Bluetooth` / `BluetoothLink` (BlueZ). A search lasts `Motion.bluetoothScanMs` and then stops, so two computers do not keep paging one multipoint headset. It runs when the page opens and when the adapter comes on. `BluetoothSignal` follows BlueZ's RSSI over `gdbus monitor` only while a search runs; a device heard in the last search is in range, and its readings stay until the next search ends. Available devices are saved and in range, then saved and not heard, then the rest, more bars first. Saved rows carry a `remembered` pill after the name; a saved device that a finished search did not hear is also drawn at `Tokens.dimmedOpacity` but stays clickable; every heard device shows its bars. A device with a BlueZ bond (paired or bonded) is connected without a new pair. Every pair runs in one short `bluetoothctl --agent NoInputNoOutput` session (`BluetoothClassic`): without an agent BlueZ rejects Pair, and a pairing the device starts itself is kept only as a temporary key that is gone after the next disconnect. That agent auto-accepts only pairings this side starts and exists only while the user pairs, so other pairing requests are still refused. The session pairs, trusts, and quits. A headset is paired over classic Bluetooth: dual-mode buds advertise on LE many times a second and BlueZ pairs on the transport it saw last, so a plain Pair lands on LE. The classic key is then only derived on this side, the buds never store theirs, and the first link after the case is refused and the bond deleted. A `bluetoothctl scan bredr` of `Motion.bluetoothClassicScanMs` right before Pair makes BR/EDR the transport seen last. BlueZ merges every client's discovery filter, so that scan first stops the page's own search (`Bluetooth.setDiscovering(false)` also cancels a pending refresh) and starts only once `Discovering` has read false for `Motion.bluetoothQuietMs`, or after `Motion.bluetoothStopWaitMs` at most; no refresh starts while it scans or pairs. A headset that already holds a link is paired on that link. A saved device that is only trusted lost its bond (the headset was reset or paired fresh elsewhere, and BlueZ deleted the key after the headset refused it), so Connect pairs it again; the dialog asks for pairing mode (`settings.bluetooth.repairBody`) and a failure says so (`settings.bluetooth.bondLost`). Connect on a link that is already up asks for audio instead, because BlueZ refuses it. Refusals are logged as warnings, not shell errors. A failed connect or pair stays on the dialog and a toast. A headset counts as connected only once PipeWire has its audio (`BluetoothAudio`), not when BlueZ reports a link. The shell never starts A2DP on a link by itself: the headset opens it, and BlueZ falls back to opening it about 3 s after the link. A third request in that window crosses theirs, AVDTP times out on both, and the headset drops the link. Only Connect on a link that is already up asks for A2DP, after `Motion.bluetoothProfileMs` (4 s); a disconnected headset is never paged. A link that never gets audio fails with `settings.bluetooth.noAudio` and is released. A headset sink that just appeared is warmed before it becomes the default (`BluetoothWarmup`): silence for `Motion.bluetoothWarmMs`, then a suspend and resume of the sink, so buds that queue audio right after a reconnect do not leave video out of sync. Pairing trusts the headset before its link counts, so it can connect back on its own. |
| System | Storage | `storage` | System-disk remaining space plus a category chart (`StorageUsage` / `scripts/storage-usage.sh`: games, files, programs, cache, snapshots). **Clean up** is one `pkexec` of `scripts/storage-clean.sh`: unused package files (`paccache`), logs older than 14 days, and regenerable caches (thumbnails, folder sizes, GPU, fonts) — never documents, photos, or games. Folder sizes stay saved until that cleanup removes them. Other internal disks and external drives via `Storage` (`lsblk`). Open uses `xdg-open`; eject uses `udisksctl` unmount + power-off. |
| System | Backup | `backup` | Live Snapper status (`Snapshots`). `backup.preUpdateSnapshot` drives `modern update`. `backup.pruneEnabled` / `backup.keepCount` (3–20, default 8) prune oldest snapshots via `pkexec` of `scripts/snapper-gc.sh`. Create/delete/clear via the same service. Restore is one `pkexec` of `scripts/snapper-restore.sh` (replaces `@`, leaves `/home`, then reboots). |
| System | Firewall | `firewall` | Live UFW (`Firewall`). Status is unprivileged (`scripts/ufw-status.sh` reads `/etc/ufw`). Enable/disable is one `pkexec` of `scripts/ufw-apply.sh`. Allow/deny add/delete via `pkexec /usr/bin/ufw`. Rules persist in `/etc/ufw`. Enable forces deny incoming, allow outgoing, deny routed. No `config.json` keys, no Restore, no `ufw reset`. |
| System | Update | `system` | Pending packages via `checkupdates` (`Update`). `modern update` / `modern mirrors` (pkexec from Settings). |

## App Store

A Hyprland `FloatingWindow` titled `modern.store` (control panel header
opens it; Super+Q is `killactive`). Chrome title is **App Store**. It
installs, updates, and removes official Arch packages only. Install and
remove do not `-Sy`; a per-package Update is `pacman -Sy --needed` of
that name so it actually fetches what `checkupdates` listed. Full
system upgrades stay on Settings → System.

- Catalog: `~/.config/modern/store/catalog.json` (popular list +
  category allowlists). Discover is a featured hero (first three
  popular), category chips, a compact Popular list, then each category
  as a tile strip (6). Installed is `pacman -Qe`, not a name list.
- Search: `scripts/pkg-search.sh` (`pacman -Ss`). Info:
  `scripts/pkg-info.sh`. Mutate: `scripts/pkg-mutate.sh` via
  `/usr/bin/pkexec /usr/bin/pacman` only (no `PACMAN=` override, no
  shell). Install preflights `pacman -Si` then `-S --needed` (no `-y`).
  Update preflights `-Q` and `-Si` then `-Sy --needed` of that name
  (`checkupdates` uses a privately synced DB; without `-y` the store
  reported success while the installed version stayed put). Remove
  preflights `pacman -Q` and refuses a protected set (glibc, pacman,
  systemd, hyprland, quickshell, …). Remove is `-R` of that name only
  (`-s`/`-n` stay off).
  The shell never SIGKILLs an in-flight transaction. `pkg-mutate.sh`
  starts `phylax.service` if it is down so the password window can
  appear; Cancel is allowed only while still waiting for that prompt.
- Updates button appears only when `Update.pending` is non-empty
  (label without a count; `MBadge` pill is the count) and opens
  Settings → System. IPC: `qs -c modern ipc call store toggle`.


## Restore defaults

Privacy, Energy, Design, Bar, Dock, Launcher, Applications, Screenshot,
Gaming, Language & Time, and Keyboard show **Restore** on the page header.
Dock restore leaves the pinned applications in place.
Confirm copies that page’s keys from `config.default.json` via
`modern config restore` (one jq write). Privacy also clears session
DND. Calendar credentials stay in `secrets.json`. Design re-runs `theme-apply.sh` so the palette matches the
restored profile. Overview, Users, AI, devices, Storage, Backup, Firewall, and
Update have no Restore control.


## Bar widget forms

Click a widget on Settings → Bar. Overlay fields (when the widget has
them): weather units plus current location (default on) or an
Open-Meteo city search (`lat,lon`; forecasts fall back to MET Norway via `weather-metno.py` when Open-Meteo is down), Date and time seconds/weekday plus calendar connect (Proton/Google private iCal, Apple CalDAV with an app-specific password or one shared iCloud link; `Calendar.check` runs `calendar-fetch.sh` with `MODERN_CAL_CHECK=1` and saves only once the calendar loads, exit codes 10/11/12 map to specific errors), audio/media
scroll steps (Shift+wheel uses the fine step). Customizable widgets
(clock, weather, volume, media) use a hover outline instead of a gear. Drag rows
across the three-column Left / Middle / Right table; enable/disable
from Available widgets (on → left). Auto-hide stays pinned open while
a bar popup is showing.

## Update, mirrors, backup

| Action | CLI | Notes |
|--------|-----|--------|
| System update | `modern update` | Overlay with live log and progress. **ModernOS** is always first under System packages (`desktop-sync.sh`). Pending only when this clone is behind the latest GitHub release tag `vX.Y.Z` (`docs/GIT.md`) — not `dev` / `main` tip. Apply (ff-only checkout of that tag + `install.sh --profile m0 --yes`) runs before `pacman -Syu`; a failed apply does not start pacman. Without a terminal `install.sh` cannot sudo, so it writes missing native packages, the greetd step, and the boot splash to a root plan (`$XDG_STATE_HOME/modern/root-plan`). One `pkexec` of `scripts/update-apply.sh --wait` accepts the password before the log moves. When snapper is installed and `backup.preUpdateSnapshot` is on, that process creates the snapshot first and stops the update if it fails; the desktop release is logged only after that snapshot succeeds. It then waits on a FIFO for `go` (`skip` when the release fails) and runs `pacman -Syu` and the plan. A release with no snapper and nothing else for root still asks only if its plan turns out non-empty. A terminal update runs `sudo -v` up front instead. The plan is kept until that step succeeds, so a cancelled prompt is retried by the next update. Settings runs all of this through `scripts/update-run.sh` and only follows its log, so a shell reload or crash never stops the update; the root step runs as the `modern-system-update` system service with shutdown inhibited, and a half-applied `pacman` run rolls back to the pre-update snapshot including `/boot` (`docs/BACKUP.md`). Progress comes from `@@progress` stage markers (`Services/UpdateProgress.qml`), not pacman's translated text, and only moves forward. The shell's file watcher is paused while an update runs; after a desktop release the overlay holds 100% for `Motion.updateSettleMs`, then `update-run.sh reload` restarts the UI (`reload-ui.sh`) once; `update-applied` in the state dir carries the version to the reloaded shell, which shows it as a toast (`modern update-notice`). The checkout is on the new tag before the release's `install.sh` runs, so a failed install leaves `release-incomplete` in the state dir and the release stays offered as "Finish installing" until a rerun completes it. Two starts share one update (`update.lock`); an update cut off without a result is reported once as stopped. Every failure has its own exit status and notice (`docs/TROUBLESHOOTING.md`). Simulated end to end by `scripts/test-update-apply.sh`. When `~/.config/modern/deploy_key` is present (the ISO embeds gitignored `secrets/github-deploy-key`), the release check uses that read-only key over SSH; otherwise it stays on HTTPS (`docs/GIT.md`). |
| Mirrorlist | `modern mirrors` | `reflector --protocol https` for the machine's country (public IP, matched to a country that has Arch mirrors). `network.mirrorCountry` (Germany) is the fallback. pacman/libcurl cannot use `rsync://`. The same refresh runs on the 1st and the 15th (`modern-mirrors.timer`, installed with the login home). **Update mirrors** sits next to **Update system**. **Search for Updates** on the status card re-runs `checkupdates` and shows a spinner while it runs. |
| Snapshots | `snapper-setup.sh` / `snapper-gc.sh` / `snapper-restore.sh` | Settings writes the Snapper `root` config with one `pkexec` of `scripts/snapper-setup.sh` (keeps an existing `/.snapshots` mount). It lists snapshots with timestamps, can create, delete, prune, clear, and restore. Restore clones the snapshot over `@` (`scripts/snapper-restore.sh`) and reboots; `/home` stays. |
| Firewall | `ufw-status.sh` / `ufw-apply.sh` / `allow` / `deny` / `delete NUM` | Settings lists numbered allow/deny rules from `/etc/ufw` without a password. Enable and disable are one `pkexec` of `ufw-apply.sh` (defaults + `--force enable` in that process). Add and delete use `pkexec /usr/bin/ufw`. Disable asks for confirmation. No `reset`, no default-allow, no config.json copy of rules. |
| Users | `usersd.sh` | Listing is unprivileged `getent`. Add/edit/delete of people and groups is one `pkexec` of `usersd.sh` with JSON on stdin. Create clones this desktop into the new home and runs `install.sh --dotfiles-only` (stow + theme; no packages or greetd). The signed-in account cannot be deleted or renamed. |

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
