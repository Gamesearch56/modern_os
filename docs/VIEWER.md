# ModernOS Imageviewer

How the ModernOS Imageviewer behaves (for end users) and how it is
built, tested and extended with formats (for developers).

A small picture viewer in the spirit of imv, styled by the same tokens as
the shell. Desktop entry `modern.imageviewer.desktop` (Name "ModernOS
Imageviewer"; launcher, dock, and Overview show "Imageviewer" via
`Commons/ModernApps.qml`). It is the default `apps.defaults.imageViewer`,
and `scripts/mime-defaults.sh` pins every type in its `MimeType=` line
to it, so Files opens pictures in it. Space in Files is still the Quick
Look preview (`Modules/FilePreview`); Enter opens the viewer.
Why it is built this way: `docs/DECISIONS.md` #26.

## Behaviour

- A normal tiled window (class `modern.imageviewer`), never floating;
  move, resize, and fullscreen it like any other window.
- The controls (top strip, previous/next arrows) show only while the
  pointer is inside the window and has moved in the last three seconds
  (`Motion.viewerChromeIdleMs`), rests on a control, a control has key
  focus, a menu or dialog is open, or there is no picture. Otherwise
  only the picture.
- One picture opens its whole folder (natural order, hidden files
  skipped unless opened directly); several pictures or folders open just
  those. Stepping wraps at both ends.
- Started without a picture it asks Files for one (the chooser runs in
  the viewer's own process). Cancelled, it shows an Open button; a
  picture dropped on the window opens too.
- A new window per launch, like imv.

## Pieces

```
scripts/modern-imageviewer     launcher: URIs → paths, JSON args, qs -p imageviewer.qml
scripts/viewer-io.sh           → scripts/lib/viewer_io.py   list/info/rotate/trash/copy (JSON out)
scripts/lib/viewer_formats.py  the format table: extensions, MIME types, rotatable formats
scripts/lib/media_files.py     listing, refusals, clipboard (shared with the Mediaplayer)
scripts/lib/safe_write.py      atomic or in-place write (shared with the Texteditor)
imageviewer.qml                process root (AppId modern.imageviewer, no file watching)
Services/ViewerIo.qml          viewer-io.sh through Services/JsonJobs.qml
Services/ViewerDoc.qml         picture list, current picture, facts, unsaved turn, notices
Services/ViewerPrefs.qml       config.viewer (scaling, info, slideshowSeconds) via ConfigWrite
Modules/Viewer/
  Module.qml                   window lifecycle, file chooser, quit after last write
  ViewerWindow.qml             Stage, hover-only chrome, InfoPanel, empty state, drop, dialog
  Stage.qml                    fit / zoom around the pointer / pan / turn; Image or AnimatedImage
  TopBar.qml                   name, n / count, zoom %, tool buttons, the full menu
  InfoPanel.qml                dimensions, size, type, modified, folder
  actions.js / Actions.qml     every command once: label, icon, keys, menu, handler
  viewops.js                   pure fit/zoom/pan/size/URL helpers (tested with node)
```

Shared with the Texteditor: `Widgets/MActionMenu` (menu from the command
table), `Widgets/MActionKeys` (a `Shortcut` per key), `Commons/KeyLabel`
(translated key names), `Services/JsonJobs` (one helper job at a time).

## Keys

See `docs/KEYBINDS.md` → Imageviewer. The table in `actions.js` is the
only place keys are defined; the menu shows them.

## Safety

- Only `viewer-io.sh` touches files. Paths travel as a JSON array in
  `MODERN_VIEWER_ARGS` and as argv, never through a shell string.
- Pictures load through Qt (`file://` with every segment encoded, so
  `#`, `?`, and `%` in a name are part of the name). Decoding stops at
  `QT_IMAGEIO_MAXALLOC` (1024 MB, set by the launcher).
- Saving a turn pipes the bytes through `magick FMT:- … FMT:-`, so a
  name is never parsed as a format prefix, with a 256 MB cap and a
  timeout. It refuses when the file changed since it was shown
  (`--expect` mtime), when it is read-only, and for SVG and other
  formats it has no writer for. A JPEG is re-encoded at the quality
  ImageMagick reads from it, so turning is only saved on Ctrl+S, never
  on its own. `safe_write` keeps mode, group, and xattrs.
- Trash uses the file manager's trash code (`files_trash`), so a
  protected path is refused the same way.

## Preferences

`config.viewer` in `config.json`, written through `ConfigWrite`:

| Key | Values | Meaning |
|---|---|---|
| `scaling` | `shrink`, `fit`, `actual` | Fit without enlarging (default), fill the window, or 1:1 |
| `info` | bool | Show the details panel |
| `slideshowSeconds` | 1–60 | Slideshow step |

## Formats

What Qt reads here: PNG, JPEG, GIF and WebP (animated too), BMP, TIFF,
SVG/SVGZ, ICO, TGA, ICNS, WBMP, XPM/XBM, PBM/PGM/PPM/PNM. WebP, TIFF,
TGA, and ICNS need `qt6-imageformats` (`install/manifests/20-theming.txt`).
A new format is one row in `viewer_formats.py`; the desktop entry's
`MimeType=` must match `mime_types()` (`tests/test-viewer.sh` checks).

## Tests

`tests/test-viewer.sh` (run by `scripts/ci-check.sh`): the Python file
layer (`test-viewer.py`), launcher dry runs (`MODERN_VIEWER_DRY=1`), the
desktop entry, window rules, the command table against both
translations, and the node checks for `viewops.js` and `actions.js`.
