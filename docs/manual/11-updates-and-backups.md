# Updates and backups

This chapter explains how ModernOS keeps itself up to date, how system
snapshots let you go back after a bad update, and how to see and free disk
space.

The three pages described here live in the **System** group of **System
Settings** (**Systemeinstellungen**); open it with **SUPER + I**. **Update** and **Backup** are only
shown to administrators; a standard account does not see them.

## How updates work

ModernOS updates two things together:

- **Packages** from the Arch Linux repositories: the kernel, drivers,
  Hyprland, your apps, and everything else installed through the system.
- **ModernOS itself**: new releases of the desktop, its settings pages,
  and its apps.

Programs you installed from other sources, such as the AUR or Flatpak,
are not checked on this page.

### Finding out about updates

ModernOS looks for updates when you open System Settings or the App
Store, and again every hour while they stay open. When something is
waiting, a notification appears, for example "3 updates available" or
"There is a new ModernOS version … available". Click the notification to
open the Update page.

### The Update page

Open **System Settings → Update** (**Aktualisierung**). At the top, a card
tells you where you stand:

- **Up to date** (**Auf dem neuesten Stand**),
- **1 update available** (**1 Update verfügbar**), or for example
  **3 updates available** (**3 Updates verfügbar**),
- **A new ModernOS version is available** (**Eine neue ModernOS-Version
  ist verfügbar**).

Next to it, **Search for Updates** (**Nach Updates suchen**) checks again
right now.

Below the card, pending updates are grouped:

- **System packages** (**Systempakete**): the ModernOS release, if there
  is one, and the packages that ship with ModernOS.
- **Other packages** (**Andere Pakete**): everything else you installed.

Click a group to open or close it. Each entry shows the old and the new
version, and some have a **Changelog** (**Änderungen**) button.

Occasionally you see **Boot repair** (**Startreparatur**): the installed
kernel is not the one the computer would start. The next update fixes
that first.

### Installing updates

1. Choose **Update system** (**System aktualisieren**).
2. Type your password in the password window that appears.
3. A progress window shows each step. If **Snapshot before updates** is
   on (see below), a snapshot of the system is taken first.

You can keep working while the update runs. Logging out, a desktop reload
or closing System Settings does not interrupt it, and the computer will
not go to sleep or shut down in the middle of it.

When a new ModernOS version was part of the update, the desktop reloads
itself at the end and you see "ModernOS updated to …". After a kernel or
driver update, restart the computer when it suits you.

### Mirrors

**Update mirrors** (**Mirrors aktualisieren**) refreshes the list of
download servers for your location. Use it when downloads are very slow
or a server keeps failing. A notification tells you when the list is
updated.

### When an update fails

The Update page names the problem in plain words. The most common ones:

| Message | What to do |
|---|---|
| Update cancelled: the password was not entered | Choose Update system again and type your password |
| Update stopped: the backup snapshot could not be created | Set up snapshots on the Backup page, or turn off Snapshot before updates |
| Package update failed; nothing was changed | Usually a network or server problem; try again later or update the mirrors |
| Package update stopped halfway; update again before restarting | Choose Update system again before you restart, so it can finish |
| The last update stopped before it finished | Update again |
| Another program is installing packages; try again when it is done | Wait for the App Store or the other program, then update again |
| ModernOS could not be updated | Update again; the release stays offered as "Finish installing …" |

If an update breaks off after it already started changing packages,
ModernOS restores the snapshot it took before the update and tells you
**System update undone** (**Systemupdate rückgängig gemacht**). Restart
the computer to finish.

The full update log is saved in your home folder at
`~/.local/state/modern/update.log`. More details are in
[../TROUBLESHOOTING.md](../TROUBLESHOOTING.md).

## Snapshots and backups

A **snapshot** is a saved state of the system part of your disk: the
programs, drivers and system settings. ModernOS uses **Snapper** on the
Btrfs file system that the installer set up.

**Snapshots do not cover your home folder.** Your documents, photos,
downloads and personal settings are left alone, both when a snapshot is
taken and when one is restored. To protect your own files, copy them to
an external drive or another computer regularly. If you ever reinstall,
also keep a copy of `~/.config/modern/secrets.json` (your saved keys, see
[Privacy and security](13-privacy-and-security.md)) and your `~/.ssh`
folder if you use one.

### The Backup page

Open **System Settings → Backup** (**Sicherung**). The status card at the
top shows Snapper's state:

- **Ready** (**Bereit**): snapshots work.
- **Not configured** (**Nicht eingerichtet**): choose **Create config**
  (**Config anlegen**) and confirm with your password. ModernOS then
  prepares Snapper for the system disk. Automatic hourly snapshots stay
  off.
- **Not installed** (**Nicht installiert**): install the `snapper`
  package from the App Store, then come back to this page. It notices the
  new package by itself.

### Options

- **Snapshot before updates** (**Snapshot vor Updates**) takes a snapshot
  every time you choose Update system, so you can roll back if an update
  goes wrong. This is the most useful option; turn it on.
- **Remove old snapshots** (**Alte Snapshots entfernen**) deletes the
  oldest snapshots once there are more than you want to keep.
- **Keep at most** (**Höchstens behalten**) sets that number, between 3
  and 20. The default is 8.

### Managing snapshots

The **Snapshots** list shows every snapshot with its number and date.
Snapshots taken before an update are labelled **ModernOS Update**; the
ones you made yourself are labelled **Manual** (**Manuell**).

- **Create snapshot** (**Snapshot erstellen**) takes one now, for example
  before you try something risky.
- **Delete** (**Löschen**) removes one snapshot.
- **Clear all** (**Alle löschen**) deletes every snapshot except the
  running system.

Each of these asks for your password.

### Restoring a snapshot

1. On the Backup page, find the snapshot you want to go back to.
2. Choose **Restore** (**Wiederherstellen**).
3. Read the dialog: the system goes back to that snapshot, files in your
   home folder stay. Choose **Restore and restart** (**Wiederherstellen
   und neu starten**) and enter your password.
4. The computer restarts into the restored system.

The state you left is not thrown away; it is kept aside on the disk, so a
restore is not a one-way street for the system itself.

### The boot menu

Snapshots are restored from the Backup page, not from the boot menu. The
boot menu is hidden; hold **Space** while the computer starts to open it.
It offers:

- **ModernOS**, the normal start;
- **ModernOS (recovery)**, the last kernel that started successfully.

After a kernel update, ModernOS tries the new kernel once. If that start
fails, the next start uses the recovery kernel on its own, so a broken
kernel does not lock you out. Once you are back on the desktop, update
again or restore a snapshot.

## Storage and cleanup

Open **System Settings → Storage** (**Speicher**).

### Seeing what uses your disk

- **System disk** (**Systemplatte**) shows how much of the disk is used
  and how much is free.
- **Calculate categories** (**Kategorien berechnen**) splits the used
  space into **Games** (**Spiele**), **Files** (**Dateien**), **Programs**
  (**Programme**), **AI models** (**KI-Modelle**), **Cache**,
  **Snapshots**, **Other** (**Sonstiges**) and **Free** (**Frei**).
- **Other drives** (**Weitere Laufwerke**) lists further internal disks.
- **External** (**Extern**) lists USB sticks and external disks. Use
  **Open** (**Öffnen**) to browse one, and **Eject** (**Auswerfen**)
  before you unplug it. Save anything still open on it first.

### Cleaning up

Choose **Clean up** (**Aufräumen**) at the top of the Storage page. The
dialog explains what it removes:

- package files that are no longer needed,
- logs older than two weeks,
- caches that are rebuilt automatically: thumbnails, folder sizes, the
  GPU cache and the font cache.

Your photos, documents, downloads and games stay untouched. Confirm with
**Clean up** and your password. When it finishes, the dialog tells you how
much space was freed, or that nothing needed removing.

If space is still short, old snapshots are a common cause: lower **Keep
at most** on the Backup page, or delete snapshots you no longer need.

## Related chapters

- [Settings](07-settings.md) for the rest of System Settings.
- [Apps](09-apps.md) for the App Store.
- [Troubleshooting](14-troubleshooting.md) when something goes wrong.
- Technical background: [../BACKUP.md](../BACKUP.md) and
  [../BOOT.md](../BOOT.md).
