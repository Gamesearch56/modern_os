import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
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

    function _focusedScreen(): var {
        const n = Hypr.focusedMonitorName();
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === n)
                return screens[i];
        }
        return screens.length ? screens[0] : null;
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

        PanelWindow {
            id: win
            visible: Cheatsheet.open
            screen: root._focusedScreen()
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            aboveWindows: true
            WlrLayershell.layer: WlrLayer.Overlay

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

            HyprlandFocusGrab {
                id: keyGrab
                windows: [win]
                onCleared: {
                    if (Cheatsheet.open)
                        Cheatsheet.hide();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
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

            Component.onCompleted: {
                Qt.callLater(() => {
                    if (!Cheatsheet.open)
                        return;
                    keyGrab.active = true;
                    overlay.focusSearch();
                });
            }
        }
    }
}
