// Accessible filled button. Mirrors Widgets/MButton (filled) without
// importing the desktop package.
import QtQuick

Item {
    id: root

    property var chrome: null
    property string label: ""
    property bool enabled: true
    property bool busy: false
    property bool tabFocus: true

    signal clicked()

    readonly property var _c: root.chrome
    readonly property bool _hot: ma.containsMouse && root.enabled && !root.busy
    readonly property bool _canPress: root.enabled && !root.busy

    implicitWidth: Math.max(root._c ? root._c.spaceXxl * 2 : 64, lab.implicitWidth + (root._c ? root._c.spaceLg * 2 : 32))
    implicitHeight: root._c ? root._c.fieldHeight : 36
    opacity: root._canPress ? 1 : 0.38
    activeFocusOnTab: root._canPress && root.tabFocus
    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.onPressAction: {
        if (root._canPress)
            root.clicked();
    }

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && root._canPress) {
            root.clicked();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root._c ? root._c.radiusFull : 9999
        color: root._hot
            ? (root._c ? root._c.color.primaryContainer : "#4F378B")
            : (root._c ? root._c.color.primary : "#D0BCFF")
        border.color: root.activeFocus
            ? (root._c ? root._c.color.onSurface : "#E6E0E9")
            : "transparent"
        border.width: root.activeFocus ? (root._c ? root._c.strokeFocus : 2) : 0
    }

    Text {
        id: lab
        anchors.centerIn: parent
        text: root.label
        color: root._hot
            ? (root._c ? root._c.color.onPrimaryContainer : "#EADDFF")
            : (root._c ? root._c.color.onPrimary : "#381E72")
        font.family: root._c ? root._c.fontFamily : "sans-serif"
        font.pixelSize: root._c ? root._c.typePx("labelLarge") : 14
        font.weight: root._c ? root._c.typeWeight("labelLarge") : 500
        Accessible.ignored: true
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root._canPress
        hoverEnabled: true
        cursorShape: root._canPress ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
