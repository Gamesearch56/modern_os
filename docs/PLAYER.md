# ModernOS Mediaplayer

A small video and music player in the spirit of mpv, styled by the same
tokens as the shell. Desktop entry `modern.mediaplayer.desktop` (Name
"ModernOS Mediaplayer"; launcher, dock, and Overview show "Mediaplayer"
via `Commons/ModernApps.qml`). It is the default `apps.defaults.videoPlayer`,
and `scripts/mime-defaults.sh` pins every type in its `MimeType=` line
to it, so Files opens videos and songs in it. Space in Files is still the
Quick Look preview (`Modules/FilePreview/VideoWindow.qml`, also Qt
Multimedia); Enter opens the player.

The preview plays muted and on repeat, with a small copy of the control
bar (`Modules/FilePreview/VideoBar.qml`: seek, back, play/pause, forward,
mute, and "Open in player") under the same hover-and-idle rule as the
player. A click toggles play; ←/→ step by `player.seekSeconds`, M
toggles sound, and both show the bar briefly. Space or Esc closes it.
Nothing set in the preview is saved. The seek row is the shared widget
`Widgets/MSeekBar.qml`, which the player's `Controls.qml` uses too.
Why it is built this way: `docs/DECISIONS.md` #27.

## Behaviour

- A normal tiled window (class `modern.mediaplayer`), never floating;
  move, resize, and fullscreen it like any other window.
- The controls (top strip, control bar) and the pointer show only while
  the pointer is inside the window and has moved in the last three
  seconds (`Motion.viewerChromeIdleMs`), rests on a control, a control
  has key focus, a menu or dialog is open, a song plays, or nothing is
  open. Otherwise only the video.
- One video opens the videos of its folder, one song the songs (natural
  order, hidden files skipped unless opened directly); several files or
  folders open just those. Previous/next wrap at both ends.
- Repeat (on by default) loops the current file. With repeat off, the
  next file starts at the end of one.
- Volume, mute, and repeat follow the last window; the first start is
  muted (`config.player.muted`).
- Started without a file it asks Files for one (the chooser runs in the
  player's own process). A file dropped on the window opens too.
- One click pauses, a double click toggles fullscreen, the wheel sets
  the volume. Speed, volume, seeks, zoom, and track changes show a short
  OSD.
- Ctrl+wheel (or a touchpad pinch) zooms the video around the pointer,
  from fit up to 8×; a drag pans while zoomed, and the picture never
  leaves a gap it could fill. Zooming back out fits it again; the next
  file always starts fitted.
- "Save frame" writes a PNG of the current frame to
  `Pictures/Screenshots` (the XDG pictures folder), never overwriting.
- A new window per launch.

## Pieces

```
scripts/modern-mediaplayer     launcher: URIs → paths, JSON args, qs -p mediaplayer.qml
scripts/player-io.sh           → scripts/lib/player_io.py   list/info/frame/copy-path (JSON out)
scripts/lib/player_formats.py  the format table: extensions, MIME types, video or audio
scripts/lib/media_files.py     listing, refusals, clipboard (shared with the Imageviewer)
mediaplayer.qml                process root (AppId modern.mediaplayer, no file watching)
Services/PlayerIo.qml          player-io.sh through Services/JsonJobs.qml
Services/PlayerDoc.qml         playlist, current file, saved frames, notices
Services/PlayerPrefs.qml       config.player (volume, muted, loop, seek steps) via ConfigWrite
Modules/Player/
  Module.qml                   window lifecycle, file chooser, quit after last write
  PlayerWindow.qml             Playback, hover-only chrome, OSD, empty state, drop, dialog
  Playback.qml                 MediaPlayer + AudioOutput, song view, error view, wheel
  VideoView.qml                VideoOutput with zoom around a point, pinch, and pan
  Controls.qml                 seek bar, times, play, volume, speed and track menus, fullscreen
  TopBar.qml                   name, n / count, the full menu, close
  Osd.qml                      the short message over the video
  actions.js / Actions.qml     every command once: label, icon, keys, menu, handler
  playops.js                   pure time/speed/seek/volume/track/zoom helpers (tested with node)
```

Shared with the Texteditor and the Imageviewer: `Widgets/MActionMenu`
(menu from the command table; rows may carry `params` or a raw `value`
for track names), `Widgets/MActionKeys`, `Commons/KeyLabel`,
`Services/JsonJobs`.

Adding a command is one row in `actions.js`, one `case` in
`Actions.run`, and its label in both translations (`scripts/test-player.sh`
checks all three). A choice menu (speed, audio, subtitles) uses ids like
`speed:1.5` so `Actions.run` stays the one place that acts.

## Keys

See `docs/KEYBINDS.md` → Mediaplayer. The table in `actions.js` is the
only place keys are defined; the menu shows them.

## Safety

- Only `player-io.sh` touches files. Paths travel as a JSON array in
  `MODERN_PLAYER_ARGS` and as argv, never through a shell string. The
  launcher drops anything that is not a local file (`http://`, …).
- Playback is Qt Multimedia in the window's own process, so a broken
  file or a stuck decoder closes only that window. Media load through
  `file://` with every segment encoded.
- Saving a frame runs ffmpeg with `-nostdin`, the input as `file:PATH`
  (a `:` in a name is never a protocol), and the PNG on a pipe, so ffmpeg
  never opens an output path. Python creates the file with `O_EXCL |
  O_NOFOLLOW` in a real folder, numbering on a clash; 64 MB cap and a
  timeout.

## Preferences

`config.player` in `config.json`, written through `ConfigWrite`:

| Key | Values | Meaning |
|---|---|---|
| `volume` | 0–1 | Slider position; output gain is its cube, like PipeWire |
| `muted` | bool | Start muted |
| `loop` | bool | Repeat the current file |
| `seekSeconds` | 1–60 | ← / → step |
| `jumpSeconds` | 5–600 | ↑ / ↓ step |

## Formats

What Qt Multimedia's FFmpeg backend plays: MP4/M4V, MKV, WebM, AVI, MOV,
WMV, FLV, MPEG, TS/M2TS, OGV, 3GP, and MP3, FLAC, Ogg/Opus, M4A/AAC, WAV,
WMA, MKA. Hardware decoding is used where the GPU offers it. Needs
`qt6-multimedia` and `qt6-multimedia-ffmpeg`
(`install/manifests/20-theming.txt`). A new format is one row in
`player_formats.py`; the desktop entry's `MimeType=` and the Files
chooser's `media` extensions (`Services/FilesChoose.qml`) must match.

## Tests

`scripts/test-player.sh` (run by `scripts/ci-check.sh`): the Python file
layer (`test-player.py`, frames need ffmpeg), launcher dry runs
(`MODERN_PLAYER_DRY=1`), the desktop entry, defaults, that no mpv, imv,
or gedit is installed or stowed, the command table against both
translations, and the node checks for `playops.js` and `actions.js`.
