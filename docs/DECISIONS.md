# Decisions (ADR log)

Chronological. Each entry: decision, rejected alternatives, why.

## 1. Quickshell over AGS / Waybar+SwayNC+Rofi / EWW

**Decision:** one Quickshell (QML) process owns bar, panels, launcher,
notifications, lock screen, greeter and Settings.

**Rejected:** Waybar+SwayNC+Rofi — three separate flat
CSS/RASI configs (204+211+108 lines) that can't share a component system
or a state model; styling MD3 elevation/tonal surfaces in flat CSS means
hand-duplicating the same values three times. AGS (GJS) — viable, but
QML's typed properties, `Behavior`, and native `Process`/D-Bus bindings
via Quickshell's own APIs fit the "one design pattern everywhere" goal
better than GJS's more dynamic style. EWW — no real component/state
model, would mean re-inventing one.

## 2. matugen over Wallust

**Decision:** matugen generates `tokens.json` as the single color source
of truth.

**Rejected:** Wallust — emits 19 slots; MD3 needs ~30
semantic roles plus 0–100 tonal steps per key color. In the audited
config, `surface` and `background` collapsed to the same value and GTK
selection was hardcoded `#FFFFFF` because there weren't enough slots.
Calling Material Color Utilities directly was considered (see "Open
decisions" below) but matugen wraps exactly that library with a template
system that already covers GTK/Qt/kitty-shaped output, so it's the
pragmatic starting point; swapping it later touches nothing downstream
since everything consumes `tokens.json`, not matugen's CLI directly.

## 3. JSON config + Lua reader, over Settings-app-generates-Lua

**Decision:** `config.json` is the only thing the Settings app writes.
`hyprland.lua` reads it via a small dependency-free JSON decoder
(`install/lib`'s shell equivalent, `Commons/config.lua`'s Lua equivalent).

**Rejected:** Settings app templating/rewriting Lua files directly — any
GUI bug could corrupt `hyprland.lua` and break the compositor on next
config reload, with no easy diff to see what changed. A JSON intermediate
means the worst case of a Settings bug is a bad config *value*, not
invalid Lua syntax, and `config.json` is trivially diffable, backupable
and hand-editable.

## 4. JSON i18n singleton over `qsTr()`

**Decision:** `translations/{en,de}.json` + `Commons/I18n.qml`.

**Rejected:** Qt Linguist / `qsTr()` — Quickshell's QML engine does not
wire up the Linguist toolchain, so `qsTr()` calls are silently untranslated
dead code in this environment. `noctalia-shell` independently converged on
the same JSON-singleton pattern, which is a useful sanity check.

## 5. Qt-first toolkit; Nautilus as default file manager

**Decision:** Nautilus is the shipped file manager so GTK/libadwaita
can follow matugen tokens (`gtk.css` named colors; Papirus-Dark icons).
Space preview in Nautilus is GNOME Sushi (`org.gnome.NautilusPreviewer`),
themed from the same `gtk.css` and floated over Nautilus with
`dim_around` — not the Quickshell Quick Look overlay. Media starts muted
(`scripts/sushi-previewer.sh` overlays gst/audio viewers). Selecting
another file replaces the preview (Nautilus `notify::selection`; the
window is not `stay_focused`). Qt/KDE apps are still first-class:
matugen writes `kdeglobals` + a Qt color scheme, and
`QT_QPA_PLATFORM=xcb` stays out of `.bashrc`.

**Rejected:** Shipping Dolphin as a second default, or going GTK-first
for Qt apps. The old setup needed `QT_QPA_PLATFORM=xcb` to make Qt
tolerable, which forces every Qt app onto XWayland — incompatible with
a Wayland-first design.

## 6. From-scratch build over forking end-4/dots-hyprland

**Decision:** build the shell from scratch in this repo.

**Rejected:** forking `end-4/dots-hyprland` (illogical-impulse) — it's the
closest existing match to the reference screenshots and already solves
MD3-over-Quickshell, but forking means inheriting its architecture,
its bugs, and a large upstream codebase not written to this project's
"files under 200 lines, one pattern everywhere" maintainability bar, plus
ongoing merge conflicts against upstream churn. Slower to reach parity,
but every line is understood and owned, per the user's explicit choice.

## 7. `WlSessionLock` over hyprlock

**Decision:** `Modules/Session` implements the lock screen via the
`ext_session_lock_v1` protocol (Quickshell's `WlSessionLock`).

**Rejected:** keeping hyprlock — it's a separate binary with its own
config format and can't share `Commons`/`Widgets`, so it visibly drifts
from the rest of the system (the exact problem being solved everywhere
else). Building it in QML means the lock screen, login greeter and
shutdown overlay share one `Session/SessionSurface.qml`.

## 8. greetd over autologin

**Decision:** real login via `greetd` + a second Quickshell instance,
gated behind an explicit, separately-applied phase (see
`docs/ISOLATION.md`). Autologin is a Settings toggle: `config.json`
plus `scripts/autologin-apply.sh` (pkexec) writes greetd
`[initial_session]` or a `getty@tty1` drop-in so the next reboot opens
the session account. Settings still never writes `/etc` itself.

**Rejected:** keeping autologin + hyprlock-as-a-workaround (current
setup) — works, but isn't a login screen, and blocks a themed boot→login
handoff.

## 9. Official `proton-drive` CLI over `rclone`'s protondrive backend

**Decision:** `Services/Drive` wraps the official Proton-shipped
`proton-drive` CLI (June 2026, JSON output, OS-keyring sessions).

**Rejected:** `rclone`'s `protondrive` backend — unmaintained, integration
tests failing for months, cannot resolve files created by Proton's 3.x
SDK clients. The official CLI is first-party and covers exactly the
list/upload/download/move/trash operations the notes widget needs.

## 10. Calendar connect on Date and time — ICS for Proton/Google, CalDAV for Apple

**Decision:** The Date and time bar widget connects calendars. Proton and
Google use a private iCal link (their supported subscribe path). Apple
uses CalDAV with an Apple ID and an app-specific password. The link and
password live in gitignored `secrets.json`; `config.json` only stores
the provider id and Apple ID. Mail stays a bar button to the mail web
app. Privacy does not hold calendar credentials.

**Rejected:** Google/Apple OAuth client IDs (would need a shipped app
registration), a Proton Calendar API (still none; events stay
end-to-end encrypted), and a raw ICS URL field on Privacy. Unofficial
Proton bridges still decrypt a session to disk.

## 11. No pacman hook for the new manifests

**Decision:** `install/manifests/*.txt` are hand-curated, no hook rewrites
them.

**Rejected:** an auto-generating pacman hook — AUR-only packages can
land in the native list, where `pacman -S` hard-fails on them.
`scripts/snapshot-packages.sh --diff` covers the "what drifted" need
manually instead.

## 12. Local-first notes with a custom reconciliation loop

**Decision:** plain markdown files with YAML front-matter locally;
`Services/Drive`'s own list-and-diff sync against Proton Drive, since the
CLI ships no background sync engine.

**Rejected:** waiting for Proton's full Linux client's sync engine (not
yet available) or building against the CLI as if it synced automatically
(it doesn't — the widget would silently show stale data). A stable UUID
+ content-hash + remote-revision manifest, with conflicts kept as a
separate `(conflict <date>).md` file rather than resolved silently, was
judged worth the ~150 lines it costs.

## 13. Static-by-default Plymouth boot theme

**Decision:** the boot splash regenerates only on an explicit "Sync boot
screen" action or a theme *profile* change, not on every wallpaper change.
A "live" mode (no initramfs rebuild, slightly later splash) is offered as
an opt-in alternative.

**Rejected:** regenerating Plymouth on every wallpaper change — the theme
lives in the initramfs, so that means `mkinitcpio -P` (~30s, non-trivial
risk if interrupted) on every wallpaper pick. Not worth it for a splash
that's on screen for a couple of seconds.

## 14. Shared `/var/lib/modern/session/` for greeter/Plymouth assets

**Decision:** `Services/Wallpaper` copies derived variants (source,
blurred, boot-downscaled, plus a `tokens.json` copy) into a
`tmpfiles.d`-managed, world-readable directory.

**Rejected:** loosening `~/.config`/home permissions, or an ACL grant for
the `greeter` user into a session `$HOME` — both weaken the home directory's
security boundary for every file in it, not just the wallpaper. Copying
one small set of derived, non-sensitive images is strictly less exposure.

## 15. Hand-curated layered manifests over a single package list

**Decision:** `00-base` through `60-flatpak`, each entry commented with
why it's there. `50-gaming` is the optional layer, deferred to M6. The
old `40-dev` layer (Docker, JDKs, Cursor, …) was dropped; those install
from Settings → Store or the AUR when wanted.

**Rejected:** one flat list — conflates "needed for any
Hyprland desktop" with optional layers (`50-gaming`).

## 16. `property var` object literals for MD3 color roles, not nested QML properties

**Decision:** `Colors.qml`'s `color` role map is a single `property var
color: ({ primary: "...", onPrimary: "...", ... })` JS object literal.

**Rejected:** one `readonly property string` per role on a nested
`QtObject` (the original design) — QML's grammar reserves any property
name matching `on<Capitalized>` for signal-handler syntax, and hits it
even when declared with an explicit `property <type>` prefix ("Cannot
assign a value to a signal (expecting a script to be run)"), not just
the bare `onX: <value>` shorthand. Half of MD3's role names are exactly
that shape (`onPrimary`, `onSurface`, `onError`, ...), so this wasn't a
one-off rename — confirmed empirically by running the real `quickshell`
binary (v0.3.1, already installed) against the generated file. A plain
object literal's keys aren't QML property declarations, so it sidesteps
the restriction entirely while keeping the exact same consumer syntax
(`Colors.color.onPrimary`).

This is also the project's standing practice going forward: every
Commons/Services QML file gets smoke-tested by actually running
`quickshell -p <throwaway dir>` with a non-visual `Scope` root (headless
`--dry-run`-style, `HOME` pointed at a fake dir under `/tmp`, never the
real one, timeout-bounded) before being considered done, not just
written to match documentation. `qmllint` alone doesn't catch this class
of bug (no Quickshell `.qmltypes` are installed for it to type-check
against, and the QML engine's own signal-vs-property disambiguation only
surfaces at actual load time, not at lint time).

## 17. `typography.ui` / `language.ui`, not `.interface`

**Decision:** `config.default.json`'s `typography` and `language`
sections use the key `ui` for "the interface font" / "the interface
language", not `interface`.

**Rejected:** `interface` (the originally planned, more descriptive
name) — `interface` is a reserved word in QML's identifier grammar
(alongside `implements`, `package`, `private`, `protected`, `public`,
`static`, `yield` — JS's strict-mode future-reserved words). Declaring
`property string interface: "Inter"` anywhere, including nested inside a
`JsonAdapter`'s `JsonObject`, is a hard parse error ("Reserved keyword
'interface' cannot be used as a QML identifier"), confirmed by actually
running `quickshell` against both a plain `QtObject` and a `JsonAdapter`
with that property name. Since `Commons/Config.qml` mirrors
`config.default.json`'s keys 1:1, the JSON key has to avoid this list
too, not just the QML side.

## 18. `I18n.t()`, not `I18n.tr()` — kept for brevity, not because `tr()` is broken

**Decision:** the translation lookup function on `Commons/I18n.qml` is
named `t(path, params)`, not `tr(...)`.

**History (corrected):** this was originally decided for the wrong
reason. `I18n.tr("bar.volume")` was observed failing at runtime with
`TypeError: Property 'tr' of object I18n is not a function`, and — since
every QML `QtObject`/`Singleton` does inherit a built-in, C++-backed
`tr()` from `QObject` (Qt Linguist's runtime translation mechanism) — the
initial (wrong) diagnosis was that the custom `tr()` was being silently
shadowed by that inherited method. **It was not.** The real cause was
decision #19's `qmldir` auto-synthesis bug: `I18n.qml` wasn't being
registered as a singleton at all, so *every* method on it was broken,
regardless of name. Once #19's `qmldir` fix landed, a function literally
named `tr()` on the same singleton was tested and works with no
shadowing, no collision, identical to `t()` — confirmed by re-running the
same real-`quickshell` test with the name reverted. The rename to `t()`
is kept anyway (harmless, one character shorter, avoids ever having to
wonder about the inherited `tr()` again) but is not fixing a real bug.

## 19. Hand-written `qmldir` in every QML layer directory, not auto-synthesis

**Decision:** every layer directory (`Commons/`, `Widgets/`, and `Services/`/`Modules/` once they exist) ships a hand-written `qmldir` file explicitly listing `singleton Name 1.0 Name.qml` (or plain `Name 1.0 Name.qml` for non-singleton `Widgets`) for every QML file in that directory. New files are not visible until added here — this is a deliberate manual checklist step, not an oversight to fix later.

**Rejected:** relying on Quickshell's implicit directory-import auto-synthesis (what `import "Commons"` does with no `qmldir` present — it scans the directory and synthesizes one on the fly, auto-detecting `pragma Singleton`). This works for most files but was caught, by this project's mandatory real-`quickshell`-runtime-testing practice (decision #16), silently mis-detecting `Commons/I18n.qml` specifically: the synthesized qmldir registered it as a plain type (`I18n 1.0 I18n.qml`) instead of a singleton (missing the `singleton` keyword), even though the file is byte-for-byte a normal `pragma Singleton` file matching every other Commons file's shape. The failure mode is brutal to diagnose from the call site — `I18n.t(...)` throws `TypeError: Property 't' of object I18n is not a function` with no indication the actual problem is the type registration, not the function itself; `typeof I18n.t` reads `"undefined"` and every property on the singleton reads `undefined` too, permanently (a binding that throws once during its first, synchronous evaluation never gets a retry once its dependency — `Config`, in this case — finishes loading, since QML's dependency tracking for that binding never got established). This was root-caused by grepping the session's own `log.qslog` for `qmldir`/`singleton`, not by reasoning about the QML source. Confirmed fix: an explicit `qmldir` in the same directory makes Quickshell log `Found qmldir file, qmldir synthesization will be disabled for directory ".../Commons"` and skip the buggy scan entirely.

**Consequence:** `AGENTS.md`'s "add a new Commons/Widgets file" instructions must include "add it to that directory's `qmldir`" as a required step, not an optional one — forgetting it doesn't error at all for most files (auto-synthesis still finds them), so this is an easy step to skip and only surfous as this exact class of silent, hard-to-diagnose bug for whichever file the scanner happens to mis-detect next.

## 20. No compositor titlebars

**Decision:** This desktop does not use hyprbars or any other SSD titlebar. The plugin did not stay reliable (missing bars, unknown `plugin.hyprbars` keys, hyprpm store/pkexec on login). Window chrome is Super+mouse move/resize, Hyprland `resize_on_border`, and the Applications right-click menu (float, fullscreen, togglesplit, close). `windows.titlebar` and `modules/titlebar.lua` are gone.

**Rejected:** shipping hyprbars behind a Settings toggle, drawing titlebars in Quickshell, or keeping a no-op `titlebar.lua` that only ran when the plugin happened to load.

## 21. Settings and picker menus are Hyprland windows, not layer overlays

**Decision:** Settings, wallpaper, cheatsheet, power menu, launcher, and overview are Quickshell `FloatingWindow`s with unique titles (`modern.settings`, …). Super+Q is `killactive` on those. The screenshot HUD, bar `MPopup`s, and Super+N control panel stay layer-shell. Lock stays on Super+L; Super+N is the control panel.

**Rejected:** keeping Settings as an `MOverlay` PanelWindow (no compositor focus border, Super+Q had to special-case it), or faking a Hyprland highlight ring on layers.

## 22. Calamares sidebar is QML, not the widget ProgressTreeView

**Decision:** the live installer uses `sidebar: qml` plus `calamares-sidebar.qml` (Settings-like nav pills, padded About) and keeps `navigation: widget` for Back/Next/Install. `stylesheet.qss` still colors QWidget pages. The product mark is a committed `logo.png` (charcoal squircle, lavender M), not a wallpaper-tinted procedural PNG.

**Rejected:** rounding the widget sidebar with QSS — Calamares's `ProgressTreeView` delegate ignores item `border-radius`. Custom `calamares-navigation.qml` — more chance of breaking Install/Cancel wiring for little visual gain over pill-shaped `QPushButton`s.

## 23. Calamares combo lists are in-window; late clone uses the ISO tree

**Decision:** combo lists are an in-window `QListView` called `modernComboOverlay`. An application-wide `ComboOverlay` event filter (AUR patch, `CalamaresWindow.cpp`) swallows the combo's own open gesture, so Qt never builds a `Qt::Popup` at all, and shows the overlay as a child of `combo->window()` instead. Geometry comes from `combo->mapTo( window, { 0, 0 } )`: the field's width and x, flush under the field's bottom edge, flipped above the field when the list would run past the window, and clamped to the larger free side so a long list scrolls instead of overflowing. The first in-window attempt SIGSEGV'd on start (`calamares exited 139`) because it reparented the combo's *own* view out of `QComboBoxPrivateContainer`; this one leaves that view alone, builds the overlay lazily on first use, and defers `setModel( nullptr )` and `setCurrentIndex()` out of the click that closed the list, since picking a region rebuilds the zone combo's model underneath it. QSS keeps `combobox-popup: 0` and gives the overlay `padding: 0` so the C++ can size it from row height plus frame. Late install copies `/usr/share/modern/dotfile` (the pin, bundled at ISO build) instead of `git clone` from GitHub. Shellprocess `verbose: false` so a failed command's stdout reaches the error dialog. Late desktop does not `chmod 0750 /etc` (that made `/etc/gitconfig` unreadable to the target user during yay bootstrap). Summary `title()` calls `tr()` on each read so the sidebar follows Welcome language (cached `m_title` stayed German in English and English in German). Late `ensure_dns` writes non-loopback nameservers and sets nsswitch `hosts: files dns` (Arch `nss-resolve` skipped `resolv.conf`, so `Could not resolve host: aur.archlinux.org` survived a stub rewrite). Late desktop runs `pacman-key --init` / `--populate` then `pacman --disable-sandbox -Sy archlinux-keyring` before `install.sh` (unpackfs copies the squashfs, not the live `pacman-init` keyring, so otherwise `pacman -S` dies with `keyring is not writable`; squashfs also has no `extra.db`; pacman 7 landlock cannot download in the Calamares chroot). It also uncomments `[multilib]` (m0 has `lib32-gamemode`), sets `IgnorePkg` so pacman cannot pick `jack2`/`pulseaudio` (`--noconfirm` answers No to conflict prompts), installs the PipeWire stack before `install.sh`, and overlays pin `install_native` (the tagged copy still one-shots every native package). The ISO ships m0 AUR packages (`yay`, `matugen-bin`, `bibata-cursor-theme-bin`, `phylax-git`) so late `yay -S --needed` does not build in the chroot. Pin `20-theming.aur.txt` still names `bibata-cursor-theme` with a trailing comment; the rewrite must match that, not only a bare `^name$` line, or yay queries AUR and dies when `systemd` has already replaced `resolv.conf` with a stub under empty `/run`. `NoExtract` + `chattr +i` keep the chroot resolver. Source `matugen` / `bibata-cursor-theme` are not used on the ISO (rustup with no default toolchain; AUR `python-clickgen` makedepend). The AUR builder runs `rustup default stable` as `modernisoaur` when a PKGBUILD mentions cargo (`phylax-git`). QEMU `--unattended` is fw_cfg-only so a USB stick never auto-wipes a disk. Live Calamares has a Network step after Keyboard (`modernnet` C++ viewmodule compiled into AUR Calamares). Next requires a default route (Ethernet is enough; otherwise Wi-Fi via `nmcli`). Live setup enables NetworkManager and stops `iwd`. Page chrome uses the same QSS tokens as the other installer pages.

**Rejected:** hide / move / show on the native popup — cage ignores the X11 `ConfigureWindow` for a `Qt::Popup`, so the list stayed at the screen origin at whatever width Qt chose. Reparenting the combo's own view into the window (SIGSEGV on start). Radius/padding on `QComboBoxPrivateContainer` (Qt then asks for `(0,0)`). `verbose: true` on late jobs. Cloning GitHub from the target. `install -d -m 0750 /etc`.

## Open decisions

- Whether `matugen` alone gives enough control over contrast/variant, or
  whether `Services/Wallpaper` should call Material Color Utilities
  directly for the `tokens.json` step. Deferred — everything downstream
  only ever consumes `tokens.json`, so this is swappable later without
  touching a single consumer.
- Spotify queue: MPRIS's `TrackList` interface isn't implemented by the
  Spotify Linux client, so the media widget's queue section is a
  self-contained, optional provider (see `docs/WIDGETS.md`) pending a
  possible future Spotify Web API integration.
