//@ pragma AppId modern.manual
// ModernOS Manual, one window per process. scripts/modern-manual starts
// it with `qs -p`; it loads only the manual, never the bar, lock screen,
// or other panels. File watching is off: a live reload would lose the
// open document and its Back history.
import Quickshell
import "Modules/Manual" as ManualMod

ShellRoot {
    settings.watchFiles: false

    ManualMod.Module {}
}
