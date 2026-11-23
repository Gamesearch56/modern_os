# Modding

A modded system is not supported. If something breaks while an
extensions folder is present, that is yours to fix. Problem reports
from a modded system are not something this project will sort out.
Removing the folder and signing in again returns the stock desktop.

## Where a mod goes

Create `~/.local/share/modern/extensions/` and copy the repository path
of the file you want to change. The two trees that are read:

```
~/.local/share/modern/extensions/stow/shell/.config/quickshell/modern/Modules/Viewer/Stage.qml
~/.local/share/modern/extensions/stow/hypr/.config/hypr/modules/keybinds.lua
```

The first replaces that one shell file. The second replaces that one
Hyprland module. Every other file stays the shipped one. The folder
must be owned by you and not writable by anyone else. A symlink in the
folder is refused. Anything outside those two trees is refused,
including `scripts/`, the boot files, and polkit.

Sign out and back in after adding a file. Editing a file that is
already in use shows up when the shell reloads.

## What an update does

The installed files live in `~/modern_os`. A mod does not delete or
rewrite them. They are marked so the account cannot remove them.
System update is the only thing that replaces them: it clears that
mark, installs the release, and sets the mark again. Your extensions
folder is left as it is. After an update a mod may no longer match the
file it replaced, and the shell or Hyprland may fail to start. That is
part of using a mod.

A development checkout is not marked and is not protected this way.

## Turning it off

Rename or remove `~/.local/share/modern/extensions` and sign in again.
The stock files are still on disk.

`scripts/doctor.sh` prints a warning when the folder exists, so a
problem report shows that the system was modded.
