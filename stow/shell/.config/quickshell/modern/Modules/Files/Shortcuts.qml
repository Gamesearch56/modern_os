import QtQuick
import "../../Commons"
import "../../Services"

Item {
    id: root

    property var places: null
    readonly property bool modal: Files.propertiesOpen || Files.confirming || Files.naming || FilesConflict.open
            || Files.menuOpen || Storage.confirmWhere === "files"
    // Editing the path must not swallow Back and Forward.
    readonly property bool nav: Files.open && Files.renaming.length === 0 && !root.modal
    readonly property bool armed: root.nav && !Files.typing

    Shortcut { sequence: "Ctrl+C"; enabled: root.armed; context: Qt.WindowShortcut; onActivated: Files.copy() }
    Shortcut { sequence: "Ctrl+X"; enabled: root.armed; context: Qt.WindowShortcut; onActivated: Files.cut() }
    Shortcut { sequence: "Ctrl+V"; enabled: root.armed; context: Qt.WindowShortcut; onActivated: Files.paste("") }
    Shortcut { sequence: "Ctrl+Z"; enabled: root.armed; context: Qt.WindowShortcut; onActivated: FilesUndo.undo() }
    Shortcut { sequence: "Ctrl+Y"; enabled: root.armed; context: Qt.WindowShortcut; onActivated: FilesUndo.redo() }
    Shortcut { sequence: "Ctrl+Shift+Z"; enabled: root.armed; context: Qt.WindowShortcut; onActivated: FilesUndo.redo() }
    Shortcut { sequence: "Ctrl+A"; enabled: root.armed; onActivated: Files.selectAll() }
    Shortcut { sequence: "Ctrl+Shift+N"; enabled: root.armed; onActivated: Files.askName("dir") }
    Shortcut { sequence: "F2"; enabled: root.armed && Files.selected.length === 1; onActivated: Files.renaming = Files.selected[0] }
    Shortcut { sequence: "Delete"; enabled: root.armed; onActivated: FilesTrash.move(Files.selected) }
    Shortcut { sequence: "Shift+Delete"; enabled: root.armed; onActivated: Files.ask("delete") }
    Shortcut { sequence: "Alt+Left"; enabled: root.nav; onActivated: Files.back() }
    Shortcut { sequence: "Alt+Right"; enabled: root.nav; onActivated: Files.forward() }
    Shortcut { sequence: "Backspace"; enabled: root.armed; onActivated: Files.back() }
    Shortcut { sequence: "Alt+Up"; enabled: root.nav; onActivated: Files.up() }
    Shortcut { sequence: "Alt+Home"; enabled: root.nav; onActivated: Files.home() }
    Shortcut { sequence: "Ctrl+T"; enabled: root.nav; onActivated: root.newTab(Files.path) }
    Shortcut { sequence: "Ctrl+N"; enabled: root.nav; onActivated: FilesExtra.open(Files.path) }
    Shortcut { sequence: "Ctrl+Tab"; enabled: root.nav; onActivated: root.stepTab(1) }
    Shortcut { sequence: "Ctrl+Shift+Tab"; enabled: root.nav; onActivated: root.stepTab(-1) }
    Shortcut { sequence: "Ctrl+PgDown"; enabled: root.nav; onActivated: root.stepTab(1) }
    Shortcut { sequence: "Ctrl+PgUp"; enabled: root.nav; onActivated: root.stepTab(-1) }
    Shortcut { sequence: "Alt+Return"; enabled: root.armed && Files.selected.length === 1; onActivated: root.properties(Files.selected[0]) }
    Shortcut { sequence: "Ctrl+L"; enabled: root.armed; onActivated: Files.locationOpen = true }
    Shortcut {
        sequence: "Ctrl+F"
        enabled: root.nav
        context: Qt.WindowShortcut
        onActivated: {
            // Already open does not signal again, so the field would stay unselected.
            Files.searchOpen = false;
            Files.searchOpen = true;
        }
    }
    Shortcut { sequence: "Tab"; enabled: root.armed && !FilesSearch.popup && root.places; context: Qt.WindowShortcut; onActivated: root.places.cycle(1) }
    Shortcut { sequence: "Backtab"; enabled: root.armed && !FilesSearch.popup && root.places; context: Qt.WindowShortcut; onActivated: root.places.cycle(-1) }
    Shortcut { sequence: "Ctrl+H"; enabled: root.armed; onActivated: Files.toggleHidden() }
    Shortcut { sequence: "F5"; enabled: root.armed; onActivated: Files.refresh() }
    Shortcut { sequence: "Return"; enabled: root.armed && !FilesSearch.popup && Files.selected.length === 1; onActivated: Files.show(Files.selected[0]) }
    Shortcut { sequence: "Space"; enabled: root.armed; onActivated: root.preview() }
    Shortcut { sequence: "Ctrl+I"; enabled: root.armed && Files.selected.length === 1; onActivated: root.properties(Files.selected[0]) }
    Shortcut { sequence: "Ctrl+D"; enabled: root.armed && Files.selected.length === 1; onActivated: FilesPlaces.toggleFavorite(Files.selected[0]) }
    Shortcut { sequence: "Ctrl+1"; enabled: root.armed; onActivated: Files.setView("list") }
    Shortcut { sequence: "Ctrl+2"; enabled: root.armed; onActivated: Files.setView("grid") }
    Shortcut { sequence: "Ctrl+W"; enabled: Files.open && !root.modal; onActivated: root.closeTab() }
    Shortcut {
        sequence: "Escape"
        enabled: Files.open
        onActivated: {
            if (Storage.confirmWhere === "files")
                Storage.cancelEject();
            else if (Files.naming)
                Files.naming = false;
            else if (Files.menuOpen)
                Files.menuOpen = false;
            else if (FilesSearch.popup) {
                FilesSearch.requestDismiss();
            } else if (Files.typing && Files.renaming.length === 0 && !Files.propertiesOpen && !Files.locationOpen) {
                FilesSearch.requestRelease();
            } else if (Files.searchOpen || FilesSearch.query.length > 0) {
                Files.searchOpen = false;
                FilesSearch.requestClear();
            } else if (Files.locationOpen)
                Files.locationOpen = false;
            else
                Files.clearSelection();
        }
    }

    function preview() {
        let path = "";
        if (Files.selected.length >= 1)
            path = String(Files.selected[0] || "");
        else if (Files.place === "folder")
            path = Files.path;
        FilePreview.togglePath(path);
    }

    function properties(path: string) {
        Files.propertiesOpen = true;
        FilesAccess.load(path);
    }

    function newTab(path: string) {
        if (!path.length || Files.place !== "folder")
            return;
        if (!FilesTabs.paths.length)
            FilesTabs.add(path);
        FilesTabs.add(path);
    }

    function closeTab() {
        if (FilesTabs.paths.length < 2) {
            Files.hide();
            return;
        }
        FilesTabs.closeAt(FilesTabs.index);
        const next = FilesTabs.paths[FilesTabs.index];
        if (next && Files.path !== next)
            Files.go(next, false);
    }

    function stepTab(delta: int) {
        const n = FilesTabs.paths.length;
        if (n < 2)
            return;
        const at = (FilesTabs.index + delta + n) % n;
        FilesTabs.pick(at);
        const next = FilesTabs.paths[at];
        if (next && Files.path !== next)
            Files.go(next, false);
    }
}
