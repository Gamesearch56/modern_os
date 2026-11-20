import QtQuick
import "../../Commons"
import "../../Services"

Item {
    id: root

    property var rows: []
    property int columns: 1
    property var view: null

    readonly property bool armed: Files.open && Files.renaming.length === 0 && !Files.typing
            && !FilesSearch.popup && !Files.propertiesOpen && !Files.confirming && !Files.naming
            && !Files.menuOpen && Storage.confirmWhere !== "files"

    Shortcut { sequence: "Left"; enabled: root.armed; context: Qt.WindowShortcut; onActivated: root._step(-1) }
    Shortcut { sequence: "Right"; enabled: root.armed; context: Qt.WindowShortcut; onActivated: root._step(1) }
    Shortcut { sequence: "Up"; enabled: root.armed; context: Qt.WindowShortcut; onActivated: root._step(-Math.max(1, root.columns)) }
    Shortcut { sequence: "Down"; enabled: root.armed; context: Qt.WindowShortcut; onActivated: root._step(Math.max(1, root.columns)) }

    function _step(delta: int) {
        const rows = root.rows || [];
        if (!rows.length)
            return;
        const sel = Files.selected && Files.selected.length ? String(Files.selected[0] || "") : "";
        let at = -1;
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i].path || "") === sel) {
                at = i;
                break;
            }
        }
        const next = at < 0 ? (delta > 0 ? 0 : rows.length - 1) : Math.max(0, Math.min(rows.length - 1, at + delta));
        const path = String(rows[next].path || "");
        if (path.charAt(0) !== "/")
            return;
        Files.selected = [path];
        if (root.view && root.view.reveal)
            root.view.reveal(next);
    }
}
