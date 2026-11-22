# The desktop at a glance

This chapter walks you through everything you see on the screen after you sign in: the top bar and its widgets, the control panel, notifications, the dock, the lock screen, the power menu, the wallpaper picker, screenshots and screen recordings, and the Quick Look preview.

Buttons and menus are named here with their English label first and the German label in parentheses, for example Control panel (Kontrollzentrum). You can switch the desktop language at any time in System Settings under Language & Time (Sprache & Zeit). See [Settings](07-settings.md).

Throughout this manual, SUPER means the key with the Windows or logo symbol on it.

## How it fits together

The desktop takes its colors from your wallpaper. When you pick a new wallpaper, the bar, the panels, the dock, window borders and the built-in apps all switch to a matching color scheme. You never have to pick colors by hand, though you can choose a color style in [Appearance](08-appearance.md).

Everything you change in System Settings (Systemeinstellungen) is saved in one settings file, and the bar, the panels and the window manager all read from it. That is why a change in Settings shows up everywhere at once.

## The top bar

The bar runs along the top of every screen. It is split into three groups, called islands: left, middle and right. Each widget sits in its own rounded pill, except for two small clusters that share one pill (see Grouped clusters below).

Out of the box the bar shows:

| Where | Widgets, from left to right |
|---|---|
| Left | Applications (launcher button), Assistant, Workspaces, Media |
| Middle | Date and time |
| Right | Weather, Network and Bluetooth, Volume, Applications (running apps), Battery, Control panel, Power |

Two widgets are both called Applications (Anwendungen). The one on the far left, with a grid of squares, opens the app launcher. The one on the right, with a window symbol, lists the apps that are running right now.

You can move the bar to the bottom, left or right edge, change its height, let it hide itself, and add, remove or rearrange widgets in Settings → Bar (Leiste). In the Widgets Position (Widget-Position) board, drag a widget between the Left island, Middle island and Right island. Under Available widgets (Verfügbare Widgets), each widget has a switch. Weather, Date and time, Volume and Media have extra options. To open them, click the widget's name.

### Applications (launcher button)

The grid icon at the far left opens the app launcher, the same as pressing `SUPER + SPACE`. While the launcher is open, the button stays highlighted. See [Launcher and Overview](04-launcher-and-overview.md).

### Assistant

The Assistant (Assistent) button opens a chat panel below the bar. You can also press `SUPER + A`.

- Type into Ask anything... (Frag etwas...) and press Enter or Send (Senden).
- While a reply is being written, Send turns into Stop (Stopp).
- Clear chat (Chat leeren) empties the conversation.
- The gear button, Assistant settings (Assistent-Einstellungen), opens Settings → AI (KI).

The assistant needs to be set up before it can answer. If it isn't, the panel shows The assistant has to be set up (Der Assistent muss eingerichtet werden) with a Set up assistant button. You can choose a local model that runs on your computer (Ollama), or connect a Gemini or ChatGPT account. See [Settings](07-settings.md).

### Workspaces

This widget shows one numbered chip per workspace on this screen. Workspaces are explained in [Windows and workspaces](05-windows-and-workspaces.md).

- The chip of the workspace you are on is highlighted.
- A chip turns red when an app on that workspace asks for your attention.
- Click a chip to switch to that workspace.
- The small plus button, Next workspace (Nächster Arbeitsbereich), opens the next free workspace.
- Right-clicking a chip closes **every window** on that workspace. Use it with care.

### Media

The Media (Medien) pill shows what is playing: album art, then title and artist, followed by previous, play/pause and next buttons.

- Click the cover or the title to bring the playing app to the front.
- Scroll over the pill to change the volume of that app only. Hold Shift while scrolling for finer steps.
- Hover over the pill to see a volume slider for that app.
- If an app plays sound but has no media controls, the pill shows its name, and the play/pause button mutes or unmutes it.

The Volume widget changes the overall volume. The Media pill only changes the app that is playing.

### Date and time

The middle of the bar shows the date and time in the formats you chose under Language & Time. Click it to open the Calendar (Kalender) panel:

- The Calendar tab shows a month grid with buttons for the previous and next month.
- The Events (Termine) tab lists today's events from a connected calendar.
- Refresh (Aktualisieren) reloads your events.
- Open calendar (Kalender öffnen) starts your calendar app.

To show events, connect Proton Calendar, Google Calendar or Apple Calendar in Settings → Bar by clicking Date and time. There you can also turn on Show weekday and Show seconds.

### Weather

This widget shows the current weather icon and temperature. Click it for the Weather (Wetter) panel, which has three tabs:

- Today (Heute) shows feels-like temperature, high and low, humidity, wind, precipitation, UV index, pressure, sunrise and sunset.
- Hourly (Stündlich) shows an hour-by-hour forecast.
- 7 days (7 Tage) shows the coming week.

The refresh button updates the forecast right away. If the bar shows Weather unavailable (Wetter nicht verfügbar), the panel offers Set up (Einrichten). That opens the weather options, where you can choose Celsius or Fahrenheit and either use your current location or search for a city.

### Volume

This widget shows the speaker icon and the volume in percent.

- Hover to get a volume slider.
- Scroll over it to change the volume. Hold Shift for finer steps.
- Right-click or middle-click to mute or unmute.
- Click to open Settings → Audio. Click again to close it.

You can set the scroll steps in Settings → Bar by clicking Volume.

### Applications (running apps)

The window icon on the right opens a list of everything that is running. You can also press `SUPER + DELETE`. The list includes:

- normal windows, each labeled with the workspace it is on
- apps that run in the background, labeled Background (Hintergrund)
- small helper apps that only live in the tray

How to use it:

- Click an entry to jump to it. A background app is brought to the workspace you are on.
- Middle-click an entry, or click its small close button, to end it.
- Right-click an entry for a menu with Show (Anzeigen), Send to background (In den Hintergrund), Float (Schwebend), Fullscreen (Vollbild), Toggle split (Teilung umschalten) and Close (Schließen).

The list also works from the keyboard:

- Up and Down move through the list. Home and End jump to the first and last entry.
- Enter or Space opens the selected entry.
- Delete or Backspace ends it.
- Right moves to the close button, and Left moves back.

Closing from this list ends the app and the processes it started. Apps that start automatically when you sign in are the exception: closing one sends it back to the background first, so it keeps delivering notifications. Close it again from the background to end it.

### Battery

This widget only appears on computers with a battery. It shows the charge in percent and turns into a warning at 15 % or less while not charging. Click it to open Settings → Energy (Energie).

### Control panel and Power

The grid button opens the Control panel (Kontrollzentrum), described below. The power button opens the power menu, also described below.

### Other widgets

A few older widgets still work but are not offered under Available widgets. They only show up if they are listed in the bar section of your settings file:

- **Tray (Ablage)** shows the icons of tray apps. Left-click opens the app, right-click opens its menu.
- **Microphone (Mikrofon)** shows the input level. Scroll to change it, middle-click to mute, and click to open the audio settings.
- **Notifications (Benachrichtigungen)** shows a bell with the number of unread notifications and opens the control panel.
- **Performance (Leistung)** shows CPU and RAM usage.
- **Network (Netzwerk)** and **Bluetooth** are single-icon versions of the cluster below.
- **Calendar (Kalender)** opens the date and time options.
- **Mail** opens your mail app.
- **KDE Connect** shows how many phones are connected.

## Grouped clusters

Two sets of widgets share a pill when they sit next to each other.

**Network and Bluetooth (Netzwerk und Bluetooth).** On the left is the Wi-Fi or cable icon with the name of your network. On the right is the Bluetooth icon with the name of the first connected device. Clicking either one opens Settings → Network or Settings → Bluetooth, where you can join networks and pair devices. Clicking it again closes Settings.

**Battery, Control panel and Power.** These three sit together at the right end of the bar. On a desktop computer without a battery, only the Control panel and Power buttons remain.

## The control panel

Open the Control panel (Kontrollzentrum) with the grid button on the bar or with `SUPER + N`. It slides in at the right edge, below the bar. Click anywhere outside it, or click its close button, to close it.

From top to bottom, it contains:

- **The time and date**, with four buttons next to them:
  - Keyboard shortcuts (Tastenkombinationen)
  - App Store
  - Settings (Einstellungen), which opens the Overview page of System Settings
  - Close
- **Quick tiles:**
  - Network (Netzwerk) turns Wi-Fi on or off.
  - Bluetooth turns the Bluetooth radio on or off.
  - Do not disturb (Nicht stören) silences notifications.
  - Alarm (Wecker) is a countdown timer. Click it, set the number of minutes, and press Start. The tile shows the time left. When it runs out, a sound plays and an Alarm notification appears. Click the tile while it runs to cancel it.
  - Capture (Aufnahme) starts a screenshot. If a screen recording is running, it stops the recording instead.
- **Sliders:**
  - Volume (Lautstärke)
  - Brightness (Helligkeit), only shown if your screen lets the computer change its brightness
- **Performance (Leistung):** CPU, GPU, RAM, disk and temperature at a glance.
- **Notifications (Benachrichtigungen):** your recent notifications. Click one to open the app it came from. Click its close button to remove it, or Clear all (Alle löschen) to remove all of them.

## Notifications and Do Not Disturb

New notifications pop up as small cards in the corner next to the end of the bar. A thin line along the bottom of each card shows how long it will stay. After about 6 seconds by default it disappears, and it is still listed in the control panel. Some apps send notifications that stay until you dismiss them.

- Click a card to open the app that sent it.
- Click the small close button to dismiss it.
- Opening the control panel marks all notifications as read.

**Do not disturb (Nicht stören)** stops new notifications from appearing, both as pop-ups and in the list. You can turn it on in two ways:

- the Do not disturb tile in the control panel
- the switch in Settings → Privacy (Datenschutz)

On the same Privacy page you can:

- set Quiet hours (Ruhezeiten), with a From and To time (23:00 to 07:00 when first turned on), so Do not disturb switches on and off by itself
- change the Banner duration (seconds) (Banner-Dauer (Sekunden)), which is how long pop-ups stay

## The dock

The dock is a row of pinned apps. It is on when you first sign in. Show dock (Dock anzeigen) in Settings → Dock turns it off.

The dock always sits on the edge opposite the bar, so with the bar at the top it sits at the bottom. Click an icon to open the app. If the app is already open, its window comes to the front.

Out of the box the dock holds Vivaldi, WhatsApp, Spotify, Steam, the terminal (Kitty), the file manager, the App Store and System Settings.

To change what is in the dock:

- Open the launcher (`SUPER + SPACE`) and drag an app from the results or from All applications onto the dock.
- While the launcher is open, you can also drag dock icons to reorder them, or drop one on the trash to remove it.
- Settings → Dock has the same list under Applications in the dock (Anwendungen im Dock). You can rearrange it there without opening the launcher.

Settings → Dock also offers:

- Auto-hide (Automatisch ausblenden)
- Icon size (Symbolgröße)
- Show names (Namen anzeigen)
- Style (Stil): Edge dash (Kantenstrich), Plate (Platte) or Floating (Schwebend)
- Hover animation (Hover-Animation): Zoom, Color (Farbwechsel), Bounce (Federn), Lift (Anheben) or None (Keine)

## The lock screen

Press `SUPER + L`, or choose Lock (Sperren) in the power menu, to lock your screen. The computer also locks by itself after 10 minutes without input, and always before it goes to sleep.

The lock screen shows the time, your picture and your name, and a Password (Passwort) field. Type your password and press Enter or Unlock (Entsperren). If Caps Lock is on, you'll see Caps Lock is on (Feststelltaste aktiv). A wrong password shows Could not unlock (Entsperren fehlgeschlagen).

The lock screen uses your current wallpaper as its background.

The volume, mute, media and brightness keys still work while the screen is locked.

### When the screen dims, turns off and locks

Settings → Energy (Energie) controls what happens when you leave the computer alone. Out of the box:

| After | What happens |
|---|---|
| 2 minutes | The screen dims (Abdunkeln nach) |
| 5 minutes | The screen turns off (Bildschirm aus) |
| 10 minutes | The session locks (Sperren) |
| 30 minutes | The computer goes to sleep (Schlafmodus) |

The computer stays awake while a fullscreen window is in front or while media is playing. You can change both in Settings → Energy.

The same page sets what the power button does, and what closing a laptop lid does:

| Event | Default |
|---|---|
| Power button | Opens the power menu |
| Closing the lid on battery | The computer goes to sleep |
| Closing the lid on mains power | The screen locks |

## The power menu and leaving the session

Open the power menu (Ein/Aus) with the power button on the bar or with `SUPER + M`. It shows your picture and name and four large buttons:

| Button | What it does |
|---|---|
| Lock (Sperren) | Locks the screen |
| Log out (Abmelden) | Ends your session and returns to the login screen |
| Restart (Neu starten) | Restarts the computer |
| Shut down (Herunterfahren) | Turns the computer off |

Click a button, or use the arrow keys and press Enter. The action happens right away, with no extra confirmation, so save your work first. Press Esc or click outside the buttons to close the menu.

`SUPER + SHIFT + M` (Exit Hyprland / Hyprland beenden) ends the session immediately, without the menu. It still works if the bar or panels have stopped responding. Unsaved work in open apps is lost.

## The wallpaper picker

Press `SUPER + W` to open Wallpapers (Hintergründe). It shows your wallpaper collection as a grid of pictures.

- Click a picture, or move with the arrow keys and press Enter, to use it. The whole desktop changes its colors to match.
- Add (Hinzufügen) opens a file chooser, starting in your Pictures folder, and adds the image you pick to the collection.
- Get wallpapers (Hintergründe holen) opens a wallpaper website in its own window. Pictures you download there land in your wallpaper folder.
- Open folder (Ordner öffnen) shows the wallpaper folder (Pictures/Wallpapers) in the file manager.
- Pictures you added can be removed with their Delete (Löschen) button. The wallpaper you are using now and the built-in wallpapers can't be deleted.

In Settings → Design you can choose how the desktop changes to a new wallpaper (Wallpaper animation / Hintergrund-Animation) and which website Get wallpapers opens (Wallpaper Provider / Hintergrund-Anbieter). More in [Appearance](08-appearance.md).

## Screenshots and screen recording

| Keys | What happens |
|---|---|
| `PRINT` | Opens the selection screen |
| `SHIFT + PRINT` | Captures the active window right away |
| `SUPER + PRINT` | Captures the whole screen right away |

The Capture tile in the control panel opens the same selection screen as `PRINT`.

On the selection screen, drag across the area you want (Drag to select / Zum Auswählen ziehen). A small toolbar lets you switch between Capture (Aufnahme) for a still picture and Record (Aufnehmen) for a video. You can also pick Region (Bereich), Window (Fenster) or Full screen (Ganzer Bildschirm). Press Esc to cancel.

After a screenshot, a notification says Screenshot saved (Screenshot gespeichert). By default the picture is:

- saved as a PNG in Pictures/Screenshots
- copied to the clipboard, so you can paste it straight into a chat or document

**Recording.** Choose Record (Aufnehmen) in the toolbar, then a region, window or the full screen, and recording starts. A Stop (Stopp) button appears at the top of the screen, and a hint sits just above the dock. Both fade out after a few seconds so they don't end up in your video. Move the pointer to the top edge to bring them back. The dock stays clickable.

Keyboard shortcuts keep working while a recording runs. `SUPER + Q` still closes the focused window.

To stop a recording, do any of these:

- click Stop
- press `SUPER + PRINT`
- press any other screenshot key
- click the Capture tile

The video is saved as an MP4 file in Videos/Recordings, and a Recording saved (Aufnahme gespeichert) notification appears. Your microphone is recorded along with the screen unless you turn that off.

Settings → Recording (Aufnahme) has the options for both:

- for screenshots: picture format and quality, Copy to clipboard, Open editor after capture, Include cursor, and the Screenshot directory
- for recordings: Record microphone (Mikrofon aufnehmen) and the Recordings directory

`SUPER + SHIFT + C` is a color picker. Click anywhere on the screen, and the color's code is copied to the clipboard.

## Quick Look

Quick Look (Schnellansicht) shows a file without opening an app. In the file manager, select a file and press Space. If nothing is selected, it previews the folder you are in.

| File type | What Quick Look shows |
|---|---|
| Pictures | The picture |
| Videos | The video with back, play/pause, forward and mute buttons, plus Open in player (Im Player öffnen) |
| PDF documents | A preview of the page |
| Text files | The text |
| Folders | A list of what's inside |
| Other files | A preview image |

Press Space or Esc to close it (Leertaste oder Esc schließt). More about the file manager in [Apps](09-apps.md).

## If something looks wrong

If the bar or a panel stops responding, `SUPER + RETURN` always opens a terminal. Press `SUPER + #` to send a problem report. Both are described in [Keyboard shortcuts](06-keyboard-shortcuts.md), and more help is in [Troubleshooting](14-troubleshooting.md).
