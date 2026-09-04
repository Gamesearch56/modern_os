// In-window user list. Mirrors Widgets/MSelect without Commons.
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var chrome: null
    property var model: []
    property var value: ""
    property string placeholder: ""
    property bool enabled: true
    property bool tabFocus: true
    property bool _pointer: false

    signal selected(var value)

    readonly property var _c: root.chrome
    readonly property int _count: {
        const rows = root.model;
        if (!rows)
            return 0;
        const n = rows.length;
        return (typeof n === "number" && n > 0) ? n : 0;
    }
    readonly property var _rows: root.model || []
    readonly property string _label: {
        const n = root._count;
        for (let i = 0; i < n; i++) {
            const row = root._rows[i];
            if (row && String(row.value) === String(root.value))
                return row.titleValue || String(row.value || "");
        }
        return "";
    }

    property bool menuOpen: false

    implicitWidth: root._c ? root._c.formWidth : 352
    implicitHeight: root._c ? root._c.fieldHeight : 36
    opacity: root.enabled ? 1 : 0.38
    z: root.menuOpen ? 40 : 0
    activeFocusOnTab: root.enabled && root.tabFocus
    onActiveFocusChanged: {
        if (!root.activeFocus)
            root._pointer = false;
    }
    Accessible.role: Accessible.ComboBox
    Accessible.name: root.placeholder
    Accessible.description: root._label
    Accessible.onPressAction: {
        if (root.enabled)
            root.menuOpen = !root.menuOpen;
    }

    function closeMenu() {
        root.menuOpen = false;
    }

    function _raise(on: bool) {
        const z = on ? 40 : 0;
        root.z = z;
        let p = root.parent;
        const cap = root._c ? root._c.spaceXxl * 20 : 640;
        while (p) {
            if (p.height > cap)
                break;
            p.z = z;
            p = p.parent;
        }
    }

    onMenuOpenChanged: root._raise(root.menuOpen)

    function _choose(val: var) {
        root.selected(val);
        root.menuOpen = false;
    }

    Rectangle {
        anchors.fill: parent
        radius: root._c ? root._c.radiusFull : 9999
        color: root._c ? root._c.color.surfaceContainerHighest : "#36343B"
        border.color: root.activeFocus && !root._pointer
            ? (root._c ? root._c.color.primary : "#D0BCFF")
            : (root._c ? root._c.color.outline : "#938F99")
        border.width: root.activeFocus && !root._pointer
            ? (root._c ? root._c.strokeFocus : 2)
            : (root._c ? root._c.strokeHairline : 1)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root._c ? root._c.spaceMd : 12
        anchors.rightMargin: root._c ? root._c.spaceMd : 12
        spacing: root._c ? root._c.spaceSm : 8

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root._label.length > 0 ? root._label : root.placeholder
            color: root._label.length > 0
                ? (root._c ? root._c.color.onSurface : "#E6E0E9")
                : (root._c ? root._c.color.onSurfaceVariant : "#CAC4D0")
            font.family: root._c ? root._c.fontFamily : "sans-serif"
            font.pixelSize: root._c ? root._c.typePx("bodyLarge") : 16
            Accessible.ignored: true
        }

        Text {
            text: root.menuOpen ? "▴" : "▾"
            color: root._c ? root._c.color.onSurfaceVariant : "#CAC4D0"
            font.family: root._c ? root._c.fontFamily : "sans-serif"
            font.pixelSize: root._c ? root._c.iconMd : 24
            Accessible.ignored: true
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root._pointer = true;
            root.menuOpen = !root.menuOpen;
        }
    }

    Keys.onPressed: (event) => {
        if (!root.enabled)
            return;
        if (!root.menuOpen) {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.menuOpen = true;
                event.accepted = true;
            }
            return;
        }
        if (event.key === Qt.Key_Escape) {
            root.menuOpen = false;
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Down) {
            menu.moveDown();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Up) {
            menu.moveUp();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            menu.chooseCurrent();
            event.accepted = true;
        }
    }

    SessionSelectMenu {
        id: menu
        visible: root.menuOpen
        chrome: root._c
        rows: root._rows
        value: root.value
        anchors.top: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root._c ? root._c.spaceXs : 4
        onVisibleChanged: {
            if (visible)
                menu.syncIndex();
        }
        onChosen: (val) => root._choose(val)
    }
}
