# First steps

This chapter takes you from the installation stick to a working desktop:
installing ModernOS, signing in for the first time, setting your language
and keyboard, adding people, and getting online. At the end there is a
short tour that points you to the rest of the manual.

## Getting ModernOS

ModernOS comes as a live image (an ISO file). You write it to a USB stick,
start the computer from that stick, and the installer opens by itself.
There is nothing to log in to on the stick: the live system goes straight
to the installer.

Before you start, check these points:

- **Internet is required.** The installer downloads packages while it
  sets up your desktop. A Wi-Fi network or an Ethernet cable is fine.
- **The whole disk is used.** The installer erases the disk you choose.
  Copy anything you want to keep to another drive first.
- **At least 16 GiB of disk space** and 1 GB of memory.
- **Turn Secure Boot off** in the firmware settings. UEFI mode is
  preferred; older Legacy/CSM mode also works.

On the first page of the installer you also find **Support** and
**Known issues** buttons. They open the project pages in a browser window;
close that window to return to the installer.

## The installer, step by step

The installer walks you through a few pages. Use **Next** to move on and
**Back** to change something.

### Welcome: your language

Pick the language you want to use. ModernOS currently offers English and
German. This choice carries over: the desktop and the login screen start
in this language after installation.

### Location: region and time zone

Choose your region and time zone. Together with the language, this sets
regional formats. For example, German with Vienna gives Austrian formats,
English with London gives British formats.

### Keyboard

The keyboard page opens on the layout that usually belongs to your
country (for example the Swiss layout for Switzerland). Change it if you
use a different one, and try it in the test field. The layout you pick
here is also used on the login screen and on the desktop.

### Network

The **Network** (**Netzwerk**) page makes sure you are online. **Next**
stays off until you are connected.

- With an Ethernet cable plugged in, you see "You're connected with
  Ethernet" and can continue.
- Otherwise you get a list of **Nearby networks** (**Netzwerke in der
  Nähe**). Choose **Connect** (**Verbinden**) next to your network, type
  the password, and wait for the confirmation.
- If your network is missing, move closer to the router and choose
  **Refresh** (**Aktualisieren**).
- If the list stays empty, the page tells you why: a Wi-Fi switch that
  is off, a Wi-Fi chip without a driver, or no Wi-Fi adapter at all. A
  cable or sharing your phone's connection over USB works as well.

The Wi-Fi network you join here is saved and used again on your new
desktop.

### Partitions

ModernOS installs onto a whole disk. Choose the disk, and the installer
erases it and lays it out for you. You can also choose how swap space is
set up; the default is a swap file. Manual partitioning is not offered.

The disk is formatted with Btrfs, which is what makes system snapshots
possible later (see [Updates and backups](11-updates-and-backups.md)).

### User

On the **User** (**Benutzer**) page you enter your name, the login name
you will sign in with, and a password. This first account is an
**administrator**: it can install updates, change the firewall, and
manage other accounts. There is no separate root password to remember.

### Summary and installing

The **Summary** (**Übersicht**) page lists everything once more. When you
start the installation, a progress bar and a short slideshow with tips
appear. The installation can take a while, and the bar can sit still for
several minutes while a large step runs. That is normal.

When everything is done, you see "All done." and a **Restart now**
button. Remove the USB stick while the computer restarts.

If something fails, the installer shows an error with the last lines of
the failed step. See [Troubleshooting](14-troubleshooting.md) and the
technical details in [../INSTALL.md](../INSTALL.md).

## The first start

When the computer starts, a ModernOS splash screen with a spinner appears
while the system loads. The boot menu is hidden; hold **Space** while the
computer starts if you ever need it (see
[Updates and backups](11-updates-and-backups.md)).

### The login screen

Then the login screen appears, in the language and keyboard layout you
chose during installation. It shows:

- a clock;
- a list of people who can sign in, with your account already selected;
- a **Password** (**Passwort**) field, with a warning **Caps Lock is on**
  (**Feststelltaste aktiv**) when needed;
- the **Sign in** (**Anmelden**) button;
- a power button with **Restart** (**Neu starten**) and **Shut down**
  (**Herunterfahren**).

Type your password and press Enter or **Sign in**. If the password is
wrong, the screen says **Could not sign in** (**Anmeldung
fehlgeschlagen**).

### Is there a first-run wizard?

Normally no. The installer already set your language, keyboard and
default settings, so you go straight to the desktop. A short welcome
sequence with **Next**, **Back** and **Skip** only appears if your
personal settings file is missing; it ends by opening System Settings.

## Language and keyboard layout

You can change both at any time. Open **System Settings**
(**Systemeinstellungen**) with **SUPER + I**.

### Language

Go to **Language & Time** (**Sprache & Zeit**):

- **UI language** (**UI-Sprache**) switches the desktop between English
  and German. The login screen follows the same choice.
- **First day of week** (**Erster Wochentag**), **Date format**
  (**Datumsformat**) and **Time format** (**Zeitformat**) change how dates
  and times appear, for example in the bar clock.

### Keyboard

Go to **Keyboard** (**Tastatur**):

- **Keyboard layout** (**Tastaturlayout**) changes the layout right away.
  The login screen uses the new layout from your next sign-in.
- **Key repeat speed** (**Tastenwiederholung**) and **Key repeat delay**
  (**Wiederholverzögerung**) control what happens when you hold a key.
- **Num Lock at login** (**Num-Lock bei der Anmeldung**) turns Num Lock on
  when the system starts.
- **Mouse control** (**Maussteuerung**) lets you move, resize and close
  windows with the side buttons of your mouse.

The button below these options opens the list of all keyboard shortcuts.
More in [Keyboard shortcuts](06-keyboard-shortcuts.md).

## User accounts

Open **System Settings → Users** (**Benutzer**).

At the top is your own account, marked **You** (**Du**):

- Click your picture to choose a new one. You can drag and resize it; the
  circle is what gets saved. The picture appears on the login screen and
  the lock screen.
- **Edit user** (**Benutzer bearbeiten**) changes your display name.
  **Change password** (**Passwort ändern**) opens a terminal where you set
  a new password.
- **Auto login** (**Automatische Anmeldung**): after the next restart,
  your account opens the desktop without asking for a password. Turn it
  off to be asked again.

Below that, under **Other people** (**Andere Personen**), an administrator
can:

- **Add user** (**Benutzer hinzufügen**) with a username, a display name,
  a password, and whether the person is an **Admin** or **Standard**
  user. The new account gets this desktop ready to use, and the person
  can sign in from the login screen.
- Edit or **Delete** (**Löschen**) an account. Deleting removes that
  person's home folder, so make sure nothing important is left in it.
- Manage **Groups** (**Gruppen**) to share access between accounts.

Every change asks for an administrator password. You cannot delete your
own account, and at least one administrator always stays. A standard
user sees the page but cannot change other people. More about
administrator rights in [Privacy and security](13-privacy-and-security.md).

## Connecting to Wi-Fi

In the bar, the Network and Bluetooth button shows your connection.
Click the network icon, or open **System Settings → Network**
(**Netzwerk**):

1. Make sure the **Wi-Fi** (**WLAN**) switch is on.
2. Under **Nearby networks**, click your network. Each entry shows its
   signal strength.
3. Choose **Connect** (**Verbinden**). For a protected network, type the
   **Wi-Fi password** (**WLAN-Passwort**) first.

Networks you used before are marked **Saved** (**Gemerkt**) and connect
again on their own. Click a saved network to **Disconnect** (**Trennen**)
or **Forget** (**Vergessen**) it. The **Ethernet** section shows whether a
cable is connected, and a speed test lets you check your connection.

If the page says "No Wi-Fi adapter, or the radio is hardware-blocked",
check the Wi-Fi switch or airplane key on your laptop. More help in
[Troubleshooting](14-troubleshooting.md).

## Connecting Bluetooth devices

Click the Bluetooth icon in the bar, or open **System Settings →
Bluetooth**:

1. Turn the **Bluetooth** switch on. A short search starts.
2. Put your device in pairing mode. It appears under **Available**
   (**Verfügbar**).
3. Click it and choose **Connect** (**Verbinden**). If the device is new,
   confirm the request on the device itself.

Connected devices are listed under **Connected** (**Verbunden**). Saved
devices are marked **Saved** (**Gemerkt**) and can be disconnected or
forgotten from the same dialog. When headphones connect, sound switches to
them automatically, and back to your speaker when they disconnect. You can
change that in **Audio**.

## Your first ten minutes

Here is a short tour. Try each shortcut once; the **SUPER** key is the
key with the Windows logo.

| Shortcut | What it opens |
|---|---|
| SUPER + SPACE | The launcher: search apps, run a command, calculate |
| SUPER + I | System Settings |
| SUPER + W | The wallpaper picker; colors follow your wallpaper |
| SUPER + N | The control panel |
| SUPER + K | The list of all keyboard shortcuts |
| SUPER + T | A terminal |
| SUPER + E | The file manager |
| SUPER + TAB | An overview of all your windows |
| SUPER + L | The lock screen |
| SUPER + M | The power menu |
| SUPER + Y | This manual |

A good order for the first minutes:

1. **Pick a wallpaper** with SUPER + W. The bar, apps and the login screen
   take their colors from it. See [The desktop](03-desktop.md).
2. **Look through System Settings** with SUPER + I. You can search with
   **Search settings...** (**Einstellungen durchsuchen...**) at the top. See [Settings](07-settings.md).
3. **Install an app** from the **App Store**. See [Apps](09-apps.md).
4. **Check for updates** under System Settings → **Update**
   (**Aktualisierung**), and turn on snapshots before updates. See
   [Updates and backups](11-updates-and-backups.md).
5. **Learn the shortcuts** with SUPER + K. See
   [Keyboard shortcuts](06-keyboard-shortcuts.md).

If something does not work, [Troubleshooting](14-troubleshooting.md) has
the common fixes, and SUPER + # sends a problem report. For an overview of
the whole manual, go back to [Welcome](01-welcome.md).
