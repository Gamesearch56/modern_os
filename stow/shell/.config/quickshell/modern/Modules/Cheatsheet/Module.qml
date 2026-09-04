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
        function hide() { Cheatsheet.hide(); }
    }

    function _moveCategory(delta: int) {
        const cats = CheatsheetModel.categories(root.query);
        if (!cats || cats.length === 0)
            return;
        let i = 0;
        for (; i < cats.length; i++) {
            if (cats[i].id === root.categoryId)
                break;
        }
        if (i >= cats.length)
            i = 0;
        const n = Math.max(0, Math.min(cats.length - 1, i + delta));
        root.categoryId = cats[n].id;
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
            Shortcut {
                sequence: "Up"
                onActivated: root._moveCategory(-1)
            }
            Shortcut {
                sequence: "Down"
                onActivated: root._moveCategory(1)
            }
        }
    }
}
