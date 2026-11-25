# Windows and workspaces

ModernOS arranges windows for you. Instead of dragging and resizing windows by hand, each new window takes its share of the screen automatically. This chapter explains how that works, how to bend it when you want to, and how to spread your work across workspaces.

SUPER is the key with the Windows or logo symbol. Labels are given in English with the German label in parentheses. You can switch the desktop language in System Settings under Language & Time (Sprache & Zeit).

## Tiling in a nutshell

The window manager tiles windows. That means they never overlap. They split the screen between them like tiles on a floor.

- The first window on a workspace fills the whole screen, apart from a small gap around the edges.
- The second window splits the space of the window that has focus. While that space is wider than it is tall, the two sit side by side. Once it gets taller than wide, the new window goes below instead.
- Every further window splits the focused window's space again.
- When you close a window, its neighbours grow back into the free space.

You don't need to plan anything: open apps, and the screen arranges itself. If an arrangement doesn't suit you, the shortcuts below change it.

The gaps between windows and around the screen edge are set in Settings → Design under Window gaps (Fensterabstände).

## Arranging windows

| Keys | What it does |
|---|---|
| `SUPER + Q` | Close the window (Fenster schließen) |
| `SUPER + F` | Fullscreen on or off (Vollbild) |
| `SUPER + V` | Toggle floating (Schwebend umschalten) |
| `SUPER + P` | Pseudo tile (Pseudo-Kachel) |
| `SUPER + J` | Toggle split (Teilung umschalten) |
| `SUPER + arrow key` | Move focus to the window in that direction |
| `SUPER + SHIFT + arrow key` | Move the window in that direction |

### Closing windows

`SUPER + Q` closes the window that has focus. If a panel, popup or the screenshot selection is open, it closes that first, so pressing it once more then closes the window. A screen recording keeps running, and the other shortcuts keep working.

Apps that start by themselves when you sign in, such as mail, calendar and messenger, are not really closed. They go back to the background, so they can keep showing notifications. See "The background" below.

### Fullscreen

`SUPER + F` makes the window cover the whole screen, including the bar. Press it again to go back. This also works for games and videos that went fullscreen on their own.

### Floating windows

A floating window sits on top of the tiles and keeps its own size and position, like on a classic desktop. Press `SUPER + V` to switch the focused window between tiled and floating.

- To move any window, hold SUPER and drag it with the left mouse button.
- To resize any window, hold SUPER and drag with the right mouse button.
- You can also drag the edge of a window to resize it.

### Pseudo tile

`SUPER + P` keeps the window in its tile but lets it keep the size the app asked for, centered in that space. This helps with small dialogs and apps that look odd when stretched. Press it again to undo.

### Toggle split

`SUPER + J` turns the split around for the focused window and its neighbour: side by side becomes stacked, and stacked becomes side by side.

### Moving focus and windows

`SUPER` plus an arrow key moves the keyboard focus to the window on that side. If there is no window in that direction and you have another screen there, the focus jumps to that screen.

`SUPER + SHIFT` plus an arrow key moves the focused window itself, swapping places with its neighbour or moving it to that side.

You can do most of this from the Applications list too (`SUPER + DELETE`). Right-click an entry for Float, Fullscreen and Toggle split. See [Launcher and Overview](04-launcher-and-overview.md).

## Workspaces

A workspace is a separate screenful of windows. You might keep your browser on workspace 1, chat on 2 and a game on 3, and flip between them without rearranging anything.

| Keys | What it does |
|---|---|
| `SUPER + 1` … `SUPER + 9`, `SUPER + 0` | Go to workspace 1 to 9, or 10 |
| `SUPER + SHIFT + 1` … `SUPER + SHIFT + 0` | Move the focused window to workspace 1 to 10 |

The number keys are the row above the letters, and they work the same with any keyboard layout.

The Workspaces (Arbeitsbereiche) widget on the bar shows the workspaces of that screen:

- Click a number to switch to it.
- The plus button opens the next free one.
- Right-click a number to close every window on that workspace.

On a touchpad, swipe three fingers sideways to move to the next or previous workspace.

### Several screens

How workspaces are shared between screens is set in Settings → Display (Anzeige) under Workspace arrangement (Workspace-Anordnung):

- **Dynamic (Dynamisch)**, the default: a new workspace opens on the screen under the mouse pointer. Each screen's bar shows only the workspaces on that screen.
- **Fixed (Fixiert)**: every screen owns five workspaces, counted from left to right. The first screen has 1 to 5, the second 6 to 10, the third 11 to 15, and so on. `SUPER + 7` then always takes you to the second screen.

## The background

Some apps should keep running without taking up room on your workspaces. Mail, calendar and messenger are the usual examples, because they need to deliver notifications. ModernOS keeps such apps on a hidden background workspace.

- The apps on the autostart list start in the background when you sign in. Out of the box that is Proton Mail, Proton Calendar and WhatsApp. You can change the list in Settings → Applications (Anwendungen) under Autostart.
- To bring one up, open Applications (`SUPER + DELETE` or the window icon on the bar). Background apps are marked Background (Hintergrund). Click one, and it appears on the workspace you are on.
- `SUPER + Q` sends such an app back to the background instead of closing it.
- You can send any other window there too. In Applications, right-click it and choose Send to background (In den Hintergrund).
- To really end a background app, close it from the Applications list while it is in the background.

Background apps don't appear in the Overview or on the workspace chips. They only show up in the Applications list.

## Using the mouse

| Mouse | What it does |
|---|---|
| SUPER + drag with the left button | Move a window |
| SUPER + drag with the right button | Resize a window |
| Drag a window edge | Resize a window |
| Middle-click an entry in Applications | Close that app |

### The side buttons

Many mice have two extra buttons on the side. The rear one, nearer your palm, is MB4. The front one is MB5. In web browsers they normally mean back and forward. ModernOS adds window controls on top of that:

| Side buttons | What it does |
|---|---|
| Hold MB4 and move the mouse | Move the window under the pointer |
| Hold MB5 and move the mouse | Resize the window |
| Press MB4 and MB5 together | Close the window, the same as `SUPER + Q` |
| Hold MB4 and click the middle button | Toggle floating |
| Hold MB5 and click the middle button | Toggle fullscreen |

A short click on a side button still works as back or forward in every app, even while the mouse is moving. Only holding the button starts a move or resize. The middle button only changes its meaning while a side button is held.

In games and fullscreen windows, the side buttons behave normally, so your game controls keep working. MB5 + middle button still toggles fullscreen there, so you can get out of a fullscreen game with the mouse alone.

To turn these controls off, switch off Mouse control (Maussteuerung) in Settings → Keyboard (Tastatur). The keyboard shortcut sheet (`SUPER + K`) lists them under Mouse (Maus) while they are on.

## Windows that float by default

Most apps tile. A few windows open floating and centered instead, because they are dialogs or tool windows:

| Window | Notes |
|---|---|
| System Settings (Systemeinstellungen) | Fixed size |
| Files (Dateien), the file manager | Fixed size; other windows stay clickable |
| Texteditor | Fixed size |
| App Store | Fixed size |
| Wallpapers (Hintergründe) and the wallpaper website | Fixed size |
| Keyboard shortcuts (Tastenkombinationen) | Fixed size |
| Report a problem (Problem melden) | Fixed size |
| Quick Look (Schnellansicht) | The rest of the screen is dimmed |
| The password prompt for administrator actions | Stays on top until you answer it |
| The Battle.net launcher | Floats at a fixed size |
| Dialogs of JetBrains development tools | Float instead of tiling |

Most of these windows dim the rest of the screen while they are open. Files and the Texteditor don't, so you can keep working beside them.

The Imageviewer and Mediaplayer tile like normal apps. Games are detected separately and go fullscreen on their own. See [Settings](07-settings.md) for the Gaming page.

You can change any window with `SUPER + V`, or with SUPER + drag once it floats. Advanced users can add their own rules under Window rules (Fensterregeln) in Settings → Design. See [Appearance](08-appearance.md).
