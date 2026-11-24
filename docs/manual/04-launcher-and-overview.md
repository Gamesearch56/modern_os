# Launcher and Overview

Four full-screen helpers let you find things quickly without hunting through menus:

| Keys | Helper | What it is for |
|---|---|---|
| `SUPER + SPACE` | Launcher | Find and start apps |
| `SUPER + TAB` | Overview | See every open window and jump to one |
| `SUPER + DELETE` | Applications | See everything that runs, including background apps, and end tasks |
| `SUPER + K` | Keyboard shortcuts | Look up any shortcut |

SUPER is the key with the Windows or logo symbol. Labels are given in English with the German label in parentheses. You can switch the desktop language in System Settings under Language & Time (Sprache & Zeit).

## The launcher

Press `SUPER + SPACE`, or click the grid icon at the far left of the bar, to open the launcher. Press `SUPER + SPACE` again, press Esc, or click anywhere outside the launcher to close it.

The launcher has a search field in the middle of the screen with a list underneath.

### Before you type: Most used

With an empty search field, the list is titled Most used (Meistgenutzt). It shows the apps you start most often, with recent use counting more than old use. The more you use the launcher, the better this list fits you.

### Searching

Start typing and the list changes to Results (Ergebnisse). The launcher looks for your text in:

- the app's name, for example "Vivaldi"
- the kind of app, for example "Web Browser"
- the app's short description
- the app's search keywords, which often include words like "music", "photo" or "office"

You don't have to type a whole word. The letters only need to appear in the right order, so "lbo" finds LibreOffice. Apps you use often are listed first.

The system's own windows show up in the results as well. Typing "settings" offers System Settings (Systemeinstellungen), and "store" offers the App Store. These English words work in every desktop language, and so do the translated names.

If nothing matches, the list says No results (Keine Ergebnisse).

### Calculate

Type a sum, for example `2+2` or `(3-1)*4`. The result is the first row. Enter copies it. Only numbers and `+ - * / %` and parentheses are accepted, so the field cannot run a program by pretending it is a calculation. Start with `=` when you want a single number, for example `=2`.

### Run a command

Start the line with `>`. `>notify-send hello` starts that program with those arguments. The launcher does not use a shell, so `;`, `|`, `$` and similar cannot add a second program, and `sudo` or `sh` are refused. Open a terminal for those.

### Starting an app

- Click a result, or move with the Up and Down keys and press Enter.
- If the app is already open, the launcher takes you to its window instead of starting a second copy.

### All applications

Below the list is the All applications (Alle Anwendungen) button. It opens a grid of every installed app in alphabetical order, including System Settings, the App Store and the file manager (Filemanager).

- Click the button, or press Down past the last result and then Enter.
- In the grid, move with the arrow keys and press Enter to start an app.
- Esc closes the grid first. Press Esc again to close the launcher.

### The launcher and the dock

If the dock is turned on (see [The desktop at a glance](03-desktop.md)), you can drag an app from the results or from the All applications grid onto the dock to pin it. While the launcher is open, dock icons can also be rearranged or dragged onto the trash to unpin them.

When you drag an app from the grid or the results, a trash icon appears as well. Dropping the app on it uninstalls the app through the App Store, which asks you to confirm first. Some apps can't be removed this way, and the trash is greyed out for them:

- apps the system needs
- the built-in ModernOS apps
- web apps
- Flatpak apps

Dragging only works while the dock is turned on.

### Launcher settings

Settings → Launcher has a few options:

| Option | What it does |
|---|---|
| Frecency ranking (Häufigkeitsranking) | Sorts apps by how often and how recently you started them. Turn it off for a plain list. |
| Show icons (Symbole anzeigen) | Shows or hides app icons. |
| Show descriptions (Beschreibungen anzeigen) | Shows or hides the short line under each app name. |
| Result count (Anzahl Ergebnisse) | How many results are listed while you type (4 to 20, default 9). |
| Most used (Häufig verwendet) | How many apps the Most used list shows (4 to 16, default 8). |

## The Overview

Press `SUPER + TAB` to open the Overview (Übersicht). It covers the whole screen, and your windows fade in as a grid of previews. Each open window on all your workspaces and screens gets its own card. Under each card are the app's name and the workspace it lives on, for example Workspace 3 (Arbeitsbereich 3).

How to move around:

- Arrow keys move the highlight in the grid. Tab and Shift + Tab move forward and back.
- The mouse wheel, or two fingers on a touchpad, also move the highlight.
- Pointing at a card highlights it.

To pick a window, click its card or press Enter. The Overview closes and takes you straight to that window, switching workspace and screen if needed. Press Esc, `SUPER + TAB` again, or click an empty area to close it without changing anything.

On a laptop touchpad you can also swipe three fingers up to fade the Overview in, following your fingers, and swipe down again to fade it out. Swiping three fingers sideways switches workspaces instead.

If no windows are open, the Overview says No open windows (Keine offenen Fenster).

Apps that run in the background, such as mail, calendar and messenger apps started at sign-in, are not shown in the Overview. You find them in the Applications list below.

## Applications: what's running

Press `SUPER + DELETE`, or click the window icon on the right side of the bar, to open Applications (Anwendungen). It is a list of everything that runs right now: normal windows, apps in the background, and small tray helpers. Each entry tells you which workspace it is on, or says Background (Hintergrund).

If nothing is running, it shows No running apps (Keine laufenden Apps). When a fullscreen app is in front, such as a game or a video, the list opens on top of it.

### With the mouse

- Click an entry to go to it. A background app is brought to the workspace you are on.
- Middle-click an entry, or click its close button, to end it.
- Right-click an entry for more actions:

| Action | What it does |
|---|---|
| Show (Anzeigen) | Goes to the window |
| Send to background (In den Hintergrund) | Moves the window to the background, out of sight but still running |
| Float (Schwebend) | Switches the window between tiled and floating |
| Fullscreen (Vollbild) | Switches fullscreen on or off |
| Toggle split (Teilung umschalten) | Switches the window's tile between side by side and stacked |
| Close (Schließen) | Ends the app |

### With the keyboard

| Key | What it does |
|---|---|
| Up / Down | Move through the list |
| Home / End | Jump to the first or last entry |
| Enter or Space | Go to the selected entry |
| Delete or Backspace | End the selected entry |
| Right / Left | Move to the close button and back |
| Esc | Close the list |

Ending an app here also ends the processes it started, which is handy when a program hangs. Apps that start automatically at sign-in are treated more gently. The first close sends them to the background, so they can keep showing notifications. Closing them again from there really ends them. Which apps start at sign-in is set in Settings → Applications (Anwendungen) under Autostart.

See [Windows and workspaces](05-windows-and-workspaces.md) for more about the background.

## The keyboard shortcut sheet

Press `SUPER + K` to open Keyboard shortcuts (Tastenkombinationen). It is a window that lists every shortcut of this desktop, grouped into categories:

- Applications (Anwendungen)
- System
- Recording (Aufnahme)
- Media (Medien)
- Window management (Fensterverwaltung)
- Workspaces (Arbeitsbereiche)
- Mouse (Maus)

How to use it:

- Pick a category on the left, or type into Search shortcuts... (Kombinationen durchsuchen...) to filter by name, key or category.
- The arrow keys move through the categories.
- Esc closes the window.

The sheet always shows the shortcuts that are in effect on your computer. If you change a shortcut, the sheet follows. The Mouse category also explains the mouse side buttons. If you turn off Mouse control (Maussteuerung) in Settings → Keyboard, the side-button entries disappear.

You can also open the sheet from:

- the keyboard button at the top of the control panel
- See keyboard shortcuts (Tastenkombinationen anzeigen) in Settings → Keyboard (Tastatur)

The full list is also in this manual: [Keyboard shortcuts](06-keyboard-shortcuts.md).
