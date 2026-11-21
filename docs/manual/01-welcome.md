# Welcome to ModernOS

ModernOS is a complete desktop built on Arch Linux. Its look follows Google's Material Design 3: calm surfaces, rounded shapes, and colors that come from your wallpaper. This manual explains what you see on screen, what every part does, and how the parts work together.

You are reading it in the ModernOS Manual. You can open it at any time with **SUPER + Y**. SUPER is the key with the Windows logo.

## How to use this manual

- The list on the left shows every document, sorted into topics. **User manual** holds these numbered chapters, written for everyday use. **Technical reference** holds the in-depth documents for administrators and developers.
- Type in the search field to find a word in any document, not just in the titles. Several words narrow the search down.
- Links to other chapters open right here. **Back** in the title bar, Alt + Left or the back button on the side of your mouse takes you back to where you were; **Forward** goes the other way. Web links open in your browser.
- Press Tab to step through the links of a page and Enter to open one. Ctrl + Plus and Ctrl + Minus change the text size.
- You can select text with the mouse and copy it with Ctrl + C, for example a command from the troubleshooting chapter.

The desktop is available in English and German. This manual names each button by its English label, followed by its German label in parentheses the first time, for example Settings (Systemeinstellungen). You can switch the language in [Settings](07-settings.md) under Language & Time (Sprache & Zeit).

## The big picture

ModernOS is made of a few parts, each with one job.

| Part | What it does |
|---|---|
| Arch Linux | The operating system underneath: drivers, programs, and updates. |
| Hyprland | The window manager. It places windows next to each other automatically (tiling), runs your workspaces, and handles keyboard shortcuts. |
| The ModernOS shell | Everything around your windows: the top bar, the launcher, notifications, the Control panel, the lock screen, the Overview, and the dock. |
| System Settings | The app where you change how everything behaves. |
| ModernOS apps | Files, Texteditor, Imageviewer, Mediaplayer, App Store, and this Manual. Each one runs in its own window. |
| The color system | Reads your wallpaper and turns it into a color palette for the whole desktop. |

### One settings file

Everything you change in [Settings](07-settings.md) is saved to one file in your home folder, `~/.config/modern/config.json`. The shell and the window manager both read that file, so a change applies right away. You don't need to log out.

Settings only ever writes that one file. It never edits program code or system files. If something goes wrong, the defaults are always one step away, and your choices survive updates.

Passwords and API keys, for example for the AI assistant or a calendar, are kept apart in a private file that only your user can read. See [Privacy and security](13-privacy-and-security.md).

### Colors from your wallpaper

When you choose a wallpaper, ModernOS picks its main colors and builds a full Material palette from them, light or dark. That palette colors the bar, the panels, the apps, window borders, the terminal, regular GTK and Qt programs, and the browser theme. Change the wallpaper and the whole desktop changes with it. You can also pick a theme style or a fixed color. See [Appearance](08-appearance.md).

### Every app on its own

The ModernOS apps each run as their own program. If a huge file makes the Imageviewer stumble, only that window is affected. The bar, your other windows, and the lock screen keep running.

## Finding your way around

| You want to | Do this |
|---|---|
| Start an app | Press SUPER + SPACE and start typing. See [Launcher and Overview](04-launcher-and-overview.md). |
| See all open windows | Press SUPER + TAB for the Overview. |
| Change a setting | Press SUPER + I, or use the settings button at the top of the Control panel. See [Settings](07-settings.md). |
| Quick toggles (Wi-Fi, Bluetooth, volume, Do Not Disturb) | Press SUPER + N for the Control panel (Kontrollzentrum). See [The desktop](03-desktop.md). |
| See every keyboard shortcut | Press SUPER + K, or read [Keyboard shortcuts](06-keyboard-shortcuts.md). |
| Arrange windows | See [Windows and workspaces](05-windows-and-workspaces.md). |
| Install or remove programs | Open the App Store. See [Apps](09-apps.md). |
| Ask the assistant | Press SUPER + A. See [The assistant](10-assistant.md). |
| Lock the screen | Press SUPER + L. |
| Shut down or restart | Press SUPER + M for the power menu. |
| Report a problem | Press SUPER + #. See [Troubleshooting](14-troubleshooting.md). |

## Chapters

The Manual's sidebar groups the chapters the same way.

**Getting started**

1. [Welcome](01-welcome.md): this overview.
2. [First steps](02-first-steps.md): installing, signing in, language, Wi-Fi, and a short tour.

**Using the desktop**

3. [The desktop](03-desktop.md): the bar and its widgets, the Control panel, notifications, the dock, the lock screen, screenshots.
4. [Launcher and Overview](04-launcher-and-overview.md): finding apps, files, and windows.
5. [Windows and workspaces](05-windows-and-workspaces.md): how tiling works, floating windows, workspaces, mouse gestures.
6. [Keyboard shortcuts](06-keyboard-shortcuts.md): the complete list.

**Settings and appearance**

7. [Settings](07-settings.md): every page of System Settings.
8. [Appearance](08-appearance.md): wallpapers, colors, themes.

**Apps**

9. [Apps](09-apps.md): Files, Texteditor, Imageviewer, Mediaplayer, App Store, this Manual, and the default apps.
10. [The assistant](10-assistant.md): the AI chat and what it can see.
11. [Gaming](11-gaming.md): Steam, game mode, and performance.

**Updates, security and help**

12. [Updates and backups](12-updates-and-backups.md): keeping the system current and safe.
13. [Privacy and security](13-privacy-and-security.md): the firewall, passwords, and what leaves your computer.
14. [Troubleshooting](14-troubleshooting.md): what to do when something doesn't work.
