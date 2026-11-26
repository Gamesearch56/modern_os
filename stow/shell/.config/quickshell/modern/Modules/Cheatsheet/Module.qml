import Quickshell
import Quickshell.Io
import QtQuick
import "../../Commons"
import "../../Services"

Scope {
    id: root

    property string query: ""
    property string categoryId: "applications"

    IpcHandler {
        target: "cheatsheet"
        function toggle() { Cheatsheet.toggle(); }
        function show() { Cheatsheet.show(); }
        // `show` is a `qs ipc` subcommand, so `ipc call cheatsheet show`
        // lists targets and never opens the window. Callers use open.
        function open() { Cheatsheet.show(); }
        function hide() { Cheatsheet.hide(); }
    }

    function _syncCategory() {
        const cats = CheatsheetModel.categories(root.query);
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === root.categoryId)
                return;
        }
        root.categoryId = cats.length > 0 ? cats[0].id : "applications";
    }

    Connections {
        target: Cheatsheet
        function onOpenChanged() {
            if (Cheatsheet.open)
                return;
            root.query = "";
            root.categoryId = "applications";
        }
    }

    LazyLoader {
        active: Cheatsheet.open

        FloatingWindow {
            id: win
            visible: Cheatsheet.open
            title: "modern.cheatsheet"
            color: "transparent"
            implicitWidth: Tokens.window.settingsWidth
            implicitHeight: Tokens.window.settingsHeight

            onVisibleChanged: {
                if (!visible) {
                    Cheatsheet.hide();
                    return;
                }
                Qt.callLater(() => overlay.focusSearch());
            }

            Overlay {
                id: overlay
                anchors.fill: parent
                query: root.query
                categoryId: root.categoryId
                onQueryEdited: (t) => {
                    root.query = t;
                    root._syncCategory();
                }
                onPicked: (id) => root.categoryId = id
                onClosed: Cheatsheet.hide()
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Cheatsheet.hide()
            }
        }
    }
}
