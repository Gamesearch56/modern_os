//@ pragma AppId modern.imageviewer
// ModernOS Imageviewer, one window per process. scripts/modern-imageviewer
// starts it with `qs -p`; it loads the viewer and, once Open is used, the
// file manager's chooser — never the bar, lock screen, or other panels.
// File watching is off: a live reload would drop the open picture list.
import Quickshell
import "Modules/Viewer" as ViewerMod

ShellRoot {
    settings.watchFiles: false

    ViewerMod.Module {}
}
