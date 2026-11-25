//@ pragma AppId modern.mediaplayer
// ModernOS Mediaplayer, one window per process. scripts/modern-mediaplayer
// starts it with `qs -p`; it loads the player and, once Open is used, the
// file manager's chooser — never the bar, lock screen, or other panels.
// File watching is off: a live reload would stop what is playing.
import Quickshell
import "Modules/Player" as PlayerMod

ShellRoot {
    settings.watchFiles: false

    PlayerMod.Module {}
}
