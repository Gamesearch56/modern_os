# Privacy and security

This chapter explains how ModernOS protects your computer and your data:
the firewall, notification and privacy options, the lock screen, where
passwords and keys are kept, what a problem report contains, and what an
administrator can do.

## Administrator rights

The account created during installation is an **administrator**. Other
accounts can be administrators or **standard** users; you choose that in
**System Settings** (**Systemeinstellungen**) **→ Users** (**Benutzer**), see
[First steps](02-first-steps.md).

Whenever something changes the whole system, a password window appears
and asks for an administrator password. This happens, for example, when
you:

- install updates or refresh the mirror list,
- turn the firewall on or off, or add and remove a rule,
- create, restore or delete snapshots,
- clean up disk space,
- add, change or delete accounts, or turn automatic login on or off,
- install or remove apps in the App Store.

Each action asks on its own; ModernOS does not keep an administrator
session open in the background. If you cancel the window, nothing is
changed.

A standard user does not see the **Update** (**Aktualisierung**),
**Backup** (**Sicherung**) and **Firewall** pages at all, and the Users page is read-only for them, with the hint
"Adding, editing, and deleting people and groups needs an administrator."

In a terminal, administrators use `sudo` for system commands, and it asks
for their own password.

## The firewall

Open **System Settings → Firewall** (only for administrators). ModernOS
uses **UFW**, a simple firewall. It is installed but **off** after a new
installation, so the status card shows **Inactive** (**Inaktiv**).

### Turning it on

Choose **Enable firewall** (**Firewall einschalten**) and confirm. Then:

- incoming connections are blocked, except those you allow with a rule;
- outgoing connections are allowed, so browsing and updates keep working;
- forwarded traffic is blocked.

The status changes to **Active** (**Aktiv**), and the setting survives a
restart. **Disable firewall** (**Firewall ausschalten**) stops filtering
again; your rules are kept for later.

### Rules

Rules are listed under **Allow rules** (**Allow-Regeln**) and **Deny
rules** (**Deny-Regeln**). To add one, choose **Add allow rule**
(**Allow-Regel hinzufügen**) or **Add deny rule** (**Deny-Regel
hinzufügen**) and fill in:

- **Port** (required): one port such as `22`, or a range such as
  `1714:1764`;
- **Protocol** (**Protokoll**): **Any** (**Beliebig**), **TCP** or **UDP**;
- **Direction** (**Richtung**): **In** (**Ein**) or **Out** (**Aus**);
- **From** (**Von**): an IP address or network; leave it empty for
  **Anywhere** (**Überall**). Host names are not accepted;
- **Comment** (**Kommentar**): a note for yourself.

Each rule can be edited or deleted later.

**Example: KDE Connect.** To pair your phone with KDE Connect, add two
allow rules for port `1714:1764`: one with protocol **TCP** and one with
**UDP**. Only do this on a network
you trust, such as your home Wi-Fi.

## The Privacy page

Open **System Settings → Privacy** (**Datenschutz**).

### Notifications

- **Do not disturb** (**Nicht stören**) hides notification banners.
- **Quiet hours** (**Ruhezeiten**) turns Do not disturb on automatically
  between the times you set under **From** (**Von**) and **To** (**Bis**).
- **Banner duration (seconds)** (**Banner-Dauer (Sekunden)**) sets how
  long a banner stays on screen, from 2 to 15 seconds.

### Connected Services

**KDE Connect** links your phone to this computer. The switch turns it on
or off, and the line below shows how many devices are connected. Phone
pairing also needs the firewall rule described above if the firewall is
on.

## The lock screen and idle

### Locking the screen

- Press **SUPER + L**, or choose **Lock** (**Sperren**) in the power menu
  (**SUPER + M**).
- To unlock, type your password and choose **Unlock** (**Entsperren**).
  A wrong password shows **Could not unlock** (**Entsperren
  fehlgeschlagen**), and **Caps Lock is on** warns you when needed.

The lock covers every monitor. Before the computer goes to sleep, it
locks first, so nobody sees your desktop when it wakes up. If the desktop
shell ever crashes while locked, the screen stays locked and the lock
comes back when the shell restarts.

### When the screen dims, locks and sleeps

Open **System Settings → Energy** (**Energie**). Under **Idle**
(**Leerlauf**):

| Option | Default |
|---|---|
| **Dim after** (**Abdunkeln nach**) | 2 min |
| **Screen off** (**Bildschirm aus**) | 5 min |
| **Lock** (**Sperren**) | 10 min |
| **Sleep** (**Schlafmodus**) | 30 min |

Each one can also be set to **Never** (**Nie**). Two switches keep the
computer awake when you need it:

- **Inhibit idle on fullscreen** (**Idle bei Vollbild unterdrücken**),
  for videos and games in fullscreen;
- **Inhibit idle while media plays** (**Idle bei Wiedergabe
  unterdrücken**).

Under **Power** (**Ein/Aus**) you choose what the **Power button**
(**Ein/Aus-Taste**) does, and what happens on **Lid close (on AC)**
(**Deckel schließen (Netzteil)**) and **Lid close (on battery)**
(**Deckel schließen (Akku)**). The choices are **Power menu**
(**Power-Menü**), **Sleep**, **Lock** and **Shut down**
(**Herunterfahren**). By default, closing the lid locks the screen when
plugged in and puts the computer to sleep on battery.

### Automatic login

**Auto login** (**Automatische Anmeldung**) on the Users page skips the login screen after a restart.
That is convenient, but anyone who switches the computer on gets your
desktop. On a laptop you carry around, keep it off.

## The keyring

ModernOS includes **GNOME Keyring**, a safe that some apps use to store
passwords. It opens with your login password when you sign in at the
login screen, so apps that use it do not ask you separately.

If the stored keyring no longer opens with your login password, ModernOS
replaces it with a new, empty one at the next sign-in, so you are not
asked to create a "Default Keyring". Passwords saved in the old keyring
are then no longer available.

The Vivaldi browser and Spotify do not use the keyring; they keep their
logins in their own storage.

## Where your keys and passwords are stored

API keys and account details you enter in ModernOS, such as keys for the
AI chat and calendar login details, are kept in one private file:

```
~/.config/modern/secrets.json
```

Only your account can read this file. ModernOS keeps it that way every
time it saves a key. It is never part of a problem report, and it is not
part of system snapshots either, because it lives in your home folder.
Keep a copy somewhere safe if you reinstall.

If you ever need to fix its permissions by hand, this command makes it
readable only by you again:

```bash
chmod 600 ~/.config/modern/secrets.json
```

Your account password itself is never stored by ModernOS; it is checked
by the system each time you sign in or unlock.

## Problem reports: what is sent

Press **SUPER + #** (on a US keyboard, the same key is `\`) to open
**Report a problem** (**Problem melden**). The window guides you through
four steps:

1. **What happened?** (**Was ist passiert?**): a **Short summary**
   (**Kurze Zusammenfassung**), the **Steps to repeat it** (**Schritte zum
   Wiederholen**), the affected area, when it happened and whether
   it happens again.
2. **Screenshots** (**Bildschirmfotos**): one picture per monitor, taken
   right before the window opened. Untick any that show something private.
3. **What gets sent** (**Was gesendet wird**): the list of collected
   files. You can open each one and untick it.
4. **Send** (**Senden**).

### What is collected

The report contains technical facts: the ModernOS version, hardware and driver versions, monitor and window
layout (without window titles), recent error messages from the system
and the desktop, sound, Bluetooth and network status, update history, and
your behaviour settings.

### What is removed or never included

Personal data is removed **before** the review list, so what you can open
is exactly what gets sent:

- **Never included:** your secrets file, keyrings, SSH and GnuPG keys,
  and browser profiles.
- **Removed from every file:** tokens and other secret values, the query
  part of web addresses, mail addresses, IP addresses, hardware (MAC)
  addresses except their last part, Wi-Fi network names, your computer's
  name, your username and your home folder path.
- **Settings files** lose every value that belongs to an account, a
  location or a secret.

### Where it goes

The report is filed as a private issue for the ModernOS developers. If
you are offline, it is saved and sent automatically once you are back
online. If reporting is not set up on your computer, choose **Save as
file** (**Als Datei speichern**); the report is saved in your
`Downloads` folder, and you can send it yourself.

If the desktop shell is not responding, SUPER + # still works: it then
takes the screenshots, collects the information and sends a quick report
without asking questions.

## Related chapters

- [First steps](02-first-steps.md) for user accounts.
- [Settings](07-settings.md) for the other pages of System Settings.
- [Troubleshooting](14-troubleshooting.md) for unlock and login problems.
- Technical details: [../SECURITY.md](../SECURITY.md) and
  [../BUGREPORT.md](../BUGREPORT.md).
