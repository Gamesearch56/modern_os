# Troubleshooting

This chapter collects fixes for the problems you are most likely to meet:
no sound, no Wi-Fi, display trouble, a frozen bar, and apps that will not
start. It also shows where ModernOS writes its logs and how to send a
problem report.

Some fixes use the terminal. Open one with **SUPER + T**, type the command
shown, and press Enter. Each command is explained next to it.

## First aid

Try these in order before anything else:

1. **Reload the desktop shell** (the bar, panels and notifications). See
   the next section.
2. **Sign out and back in** with **SUPER + SHIFT + M**, which ends the
   session and returns you to the login screen.
3. **Restart the computer** from the power menu (**SUPER + M**).
4. **Report the problem** with **SUPER + #** if it comes back.

## The bar is frozen or missing

The bar, the launcher, the control panel and System Settings all belong to
the **desktop shell**. If it crashes, ModernOS restarts it on its own
within a moment. If it crashes five times within two minutes, it stops
trying, so you can fix the cause.

To reload the shell yourself, open a terminal and run:

```bash
modern shell reload
```

If that does not help, reload the whole desktop, which also restarts the
shell when it is not running at all:

```bash
modern ui reload
```

This reloads the window manager, the idle and lock timer, the shell, and
the terminal colors.

### When you cannot open a terminal

**SUPER + RETURN** always opens an emergency terminal, even when the
normal terminal shortcut or the launcher is broken. Use it to run the
commands above.

If the screen does not react at all, switch to a text console with
**Ctrl + Alt + F3**, sign in with your username and password, and list
your sessions:

```bash
loginctl list-sessions
```

To end a stuck desktop session, use the number from the first column:

```bash
loginctl terminate-session <number>
```

Go back to the graphical screen with **Ctrl + Alt + F1** (or **F2**).

### The login screen does not appear

If the computer starts to a text prompt instead of the login screen, sign
in there with your username and password on the first console. The
desktop then starts directly.

## No sound

1. Click the speaker icon in the bar. This opens **System Settings**
   (**Systemeinstellungen**) **→ Audio**. Scrolling on the icon changes the volume.
2. Under **Speaker** (**Lautsprecher**), make sure the right output is
   selected and **Mute** (**Stumm**) is off.
3. Under **Applications** (**Anwendungen**), check that the app itself is
   not turned down.
4. Check **Master volume limit** (**Lautstärkegrenze**); a low limit caps
   every app.
5. For a microphone, check **Microphone** (**Mikrofon**) the same way.

**Bluetooth headphones:** when they connect, sound switches to them, and
back when they disconnect. **Set default** (**Standard festlegen**)
chooses which speaker takes over then. If headphones connect but stay
silent, they are probably still in use on another device; disconnect them
there and connect again. If they say they no longer know this computer,
put them back into pairing mode, usually by holding the button on the
case, and connect again.

To see every sound device the system knows about, run:

```bash
wpctl status
```

If your speaker or headphones are missing from that list, the system does
not see them at all. Report the problem under **Sound** (**Ton**).

## No Wi-Fi

1. Open **System Settings → Network** (**Netzwerk**) and make sure the
   **Wi-Fi** (**WLAN**) switch is on.
2. If the page says "No Wi-Fi adapter, or the radio is hardware-blocked",
   check the Wi-Fi switch or airplane-mode key on your laptop.
3. If the network is listed but will not connect, click it, choose
   **Forget** (**Vergessen**), then connect again and retype the password.
4. Move closer to the router and choose **Refresh** (**Aktualisieren**).
5. As a fallback, plug in an Ethernet cable or share your phone's
   connection over USB.

To see whether Wi-Fi is switched on or blocked, run:

```bash
nmcli radio
```

Report a lasting problem under **Internet**.

## Bluetooth does not find devices

- Turn the **Bluetooth** switch off and on again in **System Settings →
  Bluetooth**. Each time, a short search runs and then stops.
- Put the device into pairing mode right before you search.
- If the page says "No Bluetooth adapter, or the radio is
  hardware-blocked", check the airplane-mode key.
- Headphones linked to two devices at once may refuse a third. Disconnect
  one, then try again.

## Display and scaling problems

Open **System Settings → Display** (**Anzeige**) and pick your monitor.

- **Everything is tiny or blurry:** change **Scale** (**Skalierung**).
  For a 27-inch monitor at 1440p, 1.25 is a good start.
- **Wrong resolution or flicker:** check **Resolution** (**Auflösung**)
  and **Refresh rate** (**Bildwiederholrate**).
- **Colors look too bright or neon:** turn **HDR** off unless you need it.
  The wallpaper is meant to be shown without HDR.
- **Workspaces appear on the wrong monitor:** see **Workspace
  arrangement** (**Workspace-Anordnung**) at the top of the page.
  **Dynamic** (**Dynamisch**) opens a workspace on the monitor under the
  pointer; **Fixed** (**Fixiert**) keeps workspaces 1–5, 6–10 and so on
  from left to right.

**A browser fills the whole screen after watching a video:** press
**SUPER + F**. If that does not return it to normal, run:

```bash
hyprctl dispatch fullscreenstate 0 0
```

This takes the focused window out of fullscreen.

Report display problems under **Display** (**Bildschirm**).

## An app will not start

- **Start it from the launcher** (**SUPER + SPACE**). Apps started there
  get the right colors and settings.
- **It may still be running in the background.** Some apps keep running
  after you close their window. Open **Applications** (**Anwendungen**)
  with **SUPER + DELETE**; it also lists those, and you can close them
  there. Then start the app again.
- **Look for an error message.** Type the app's command in a terminal and
  press Enter; any error appears right there.
- **A window does not react:** **SUPER + Q** closes the focused window.

### The App Store waits for confirmation

If the App Store shows "Waiting for confirmation" but no password window
appears, the password helper has stopped. Restart it with these commands,
one after the other:

```bash
systemctl --user stop hyprpolkitagent.service
systemctl --user reset-failed phylax.service
systemctl --user start phylax.service
pkexec true
```

The last command should show the password window. Only one password
window can be open at a time, so finish or cancel any other one first.

## Unlock or sign-in refuses the right password

- Check **Caps Lock**; the screen warns you when it is on.
- Check the keyboard layout; it follows **System Settings → Keyboard**.
- After several wrong attempts, the account can be locked temporarily,
  and then even the right password is refused. To clear that lock, run
  this in a terminal:

```bash
faillock --user "$USER" --reset
```

Problems with startup, login, the lock screen or shutdown are best
reported under **Startup, login, lock & shutdown** (**Start, Anmeldung,
Sperren & Ausschalten**).

## A setting went wrong

Many pages in System Settings have a **Restore** (**Zurücksetzen**) button
at the top. It resets every option on that page to the original defaults,
without touching other pages.

For updates that failed, see
[Updates and backups](11-updates-and-backups.md). It also explains how to
go back to a snapshot or start the recovery kernel.

## Where the logs are

ModernOS writes its logs into a hidden folder in your home folder,
`~/.local/state/modern/`. The most useful files:

| File | What it records |
|---|---|
| `quickshell.log` | The desktop shell: bar, panels, lock screen |
| `hyprland.log` | The window manager, one section per sign-in |
| `update.log` | The last system update (`update.log.1` is the one before) |
| `hypridle.log` | Dimming, locking and sleep |
| `battlenet.log` | Battle.net starts |

The login screen writes to `/var/lib/modern/session/greeter.log`. To read
the end of a log, for example the shell's:

```bash
tail -n 80 ~/.local/state/modern/quickshell.log
```

To see what happened during the previous shutdown, run:

```bash
journalctl -b -1 -n 300
```

You rarely need to read these yourself: a problem report collects them
for you.

## The system health check

ModernOS includes a health check that only looks and never changes
anything. Run it in a terminal:

```bash
doctor.sh
```

It prints sections such as disk space, backup tools, firewall and desktop
services, with a warning line for anything that looks wrong, often with
the command that fixes it.

## Reporting a problem

Press **SUPER + #** (on a US keyboard, the same key is `\`). The **Report
a problem** (**Problem melden**) window asks what happened, which area is
affected, and when. It takes screenshots of each monitor, collects logs
and system facts, and removes personal data before you review the list. Then choose **Send report** (**Bericht
senden**).

- Without an internet connection, the report is saved and sent
  automatically later.
- If reporting is not set up on your computer, choose **Save as file**
  (**Als Datei speichern**) and send the file from your `Downloads`
  folder yourself.
- If the desktop shell is not responding, SUPER + # sends a quick report
  without asking questions.

What exactly is collected and removed is explained in
[Privacy and security](13-privacy-and-security.md).

## More help

- [Keyboard shortcuts](06-keyboard-shortcuts.md) for every shortcut.
- [Settings](07-settings.md) for all pages of System Settings.
- Advanced and technical fixes: [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md).
