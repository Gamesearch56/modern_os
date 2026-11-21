# ModernOS Texteditor

A plain-text editor in the spirit of Windows Notepad, styled by the same
tokens as the shell. Desktop entry `modern.editor.desktop` (Name
"ModernOS Texteditor"; launcher, dock, and Overview show "Texteditor"
via `Commons/ModernApps.qml`). It is the default for every type in
`TEXT_TYPES` in `scripts/mime-defaults.sh`, so Files opens text files in it.
Why it is built this way: `docs/DECISIONS.md` #25.

## Pieces

```
scripts/modern-editor          launcher: file:// → path, focus an open window or start qs -p
scripts/editor-io.sh           → scripts/lib/editor_io.py   load/save/trash/claim (JSON out)
scripts/lib/editor_codec.py    bytes ↔ text: encodings, BOM, line endings, NBSP stand-in
scripts/lib/editor_claim.py    one window per file ($XDG_RUNTIME_DIR/modern-editor)
editor.qml                     process root (AppId modern.editor, no file watching)
Services/EditorIo.qml          job queue around editor-io.sh
Services/EditorDoc.qml         the open document: path, encoding, eol, lock, dirty, notices
Services/EditorPrefs.qml       config.editor (wrap, status bar, monospace, zoom) via ConfigWrite
Modules/Editor/
  Module.qml                   window lifecycle, file chooser, quit after last write
  EditorWindow.qml             header + menus, FindBar, TextPane, StatusBar, dialogs
  DocFlow.qml                  unsaved → save/discard, Save as fallback, conflicts, trash
  actions.js / Actions.qml     every command once: label, icon, keys, menu, handler
  MenuRow / ActionMenu         File / Edit / View menus and the right-click menu
  KeyBindings.qml              Shortcut per key in actions.js (off while a dialog is open)
  TextPane / FindBar / StatusBar / *Dialog.qml
  textops.js                   pure find/replace/line helpers (tested with node)
```

## Adding a command

1. Add a row to `Modules/Editor/actions.js`: `id`, `key`
   (`editor.actions.<id>`), `icon`, `keys`, `menu` (`file`/`edit`/`view`),
   and `toggle`/`divider`/`context` as needed.
2. Add the handler to `Actions.run()` (and `enabled()`/`checked()` if it
   has a state).
3. Add `editor.actions.<id>` to `en.json` and `de.json`.

Menus, the keyboard shortcut, and the right-click menu pick it up from the
table. `scripts/test-editor.sh` fails if a command lacks a label in
either language or a case in `Actions.run()`.

## Safety rules

- The QML side never touches a file; everything goes through
  `editor-io.sh`.
- A save passes `--expect <mtime>`; a newer file on disk asks first.
- Save as passes `--no-clobber`; replacing asks first.
- Read-only files, files another window has open, and files that cannot
  round-trip open read-only, and Save goes to Save as.

## Testing

```bash
scripts/test-editor.sh        # codec, I/O, claims, launcher, desktop entry, commands
MODERN_EDITOR_DRY=1 modern-editor some.txt
```
