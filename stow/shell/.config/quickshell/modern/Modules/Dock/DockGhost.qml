import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Services"
import "../../Widgets"

PanelWindow {
    id: root

    readonly property var _screen: Dock.dragActive ? Dock.screenAt(Dock.dragX, Dock.dragY) : null
    readonly property real _size: DockLayout.iconSize + Tokens.spacing.sm

    visible: Dock.dragActive && root._screen !== null
    screen: root._screen
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "modern-dock-ghost"
    // The icon sits on the pointer. An input region would take the drag
    // away from the window underneath.
    mask: Region {
        width: 0
        height: 0
    }
    anchors.top: true
    anchors.left: true
    anchors.right: false
    anchors.bottom: false
    implicitWidth: root._size
    implicitHeight: root._size
    margins.left: {
        const s = root._screen;
        if (!s)
            return 0;
        const o = Dock.screenOrigin(s);
        const x = Math.round(Dock.dragX - o.x - root._size / 2);
        return Math.max(0, Math.min(x, s.width - root._size));
    }
    margins.top: {
        const s = root._screen;
        if (!s)
            return 0;
        const o = Dock.screenOrigin(s);
        const y = Math.round(Dock.dragY - o.y - root._size / 2);
        return Math.max(0, Math.min(y, s.height - root._size));
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Colors.color.surfaceContainerHigh
        MIcon {
            anchors.centerIn: parent
            name: Dock.iconFor(Dock.dragId)
            size: DockLayout.iconSize
            tint: false
            preferSymbolic: false
        }
    }
}
