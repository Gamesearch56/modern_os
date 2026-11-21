//@ pragma AppId modern.editor
// ModernOS Texteditor, one window per process. scripts/modern-editor
// starts it with `qs -p`; it loads the editor and, once Open is used, the
// file manager's chooser — never the bar, lock screen, or other panels.
// File watching is off: a live reload would drop unsaved text.
import Quickshell
import "Modules/Editor" as EditorMod

ShellRoot {
    settings.watchFiles: false

    EditorMod.Module {}
}
