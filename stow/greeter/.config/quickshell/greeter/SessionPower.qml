import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var chrome: null
    property bool menuOpen: false
    property bool tabFocus: true

    readonly property var _c: root.chrome
    readonly property real _btn: root._c ? root._c.spaceXxl + root._c.spaceSm : 40
    readonly property real _gap: root._c ? root._c.spaceSm : 8
    readonly property real _menuW: Math.max(root._c ? root._c.spaceXxl * 7 : 224, menuCol.implicitWidth)

    implicitWidth: Math.max(root._btn, root.menuOpen ? root._menuW : 0)
    implicitHeight: root._btn + (root.menuOpen ? menuBox.implicitHeight + root._gap : 0)
    z: 20

    function close() {
        root.menuOpen = false;
    }

    function _run(kind: string) {
        root.menuOpen = false;
        const verb = kind === "reboot" ? "reboot" : "poweroff";
        Quickshell.execDetached(["/usr/lib/modern/splash-hold.sh", verb]);
    }

    activeFocusOnTab: root.tabFocus
    Accessible.role: Accessible.Button
    Accessible.name: root._c ? root._c.t("powerMenu.title") : ""
    Accessible.onPressAction: root.menuOpen = !root.menuOpen

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape && root.menuOpen) {
            root.menuOpen = false;
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.menuOpen = !root.menuOpen;
            event.accepted = true;
        }
    }

    Rectangle {
        id: menuBox
        visible: root.menuOpen
        anchors.top: parent.top
        anchors.right: parent.right
        implicitWidth: root._menuW
        implicitHeight: menuCol.implicitHeight
        radius: root._c ? root._c.radiusSmall : 8
        color: root._c ? root._c.color.surfaceContainerHighest : "#36343B"
        border.color: root._c ? root._c.color.outlineVariant : "#49454F"
        border.width: root._c ? root._c.strokeHairline : 1

        ColumnLayout {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            Repeater {
                model: [
                    { id: "reboot", key: "powerMenu.restart" },
                    { id: "poweroff", key: "powerMenu.poweroff" }
                ]

                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: root._c ? root._c.fieldHeight : 36
                    color: itemMa.containsMouse
                        ? (root._c ? root._c.color.surfaceContainerHigh : "#2B2930")
                        : "transparent"
                    radius: root._c ? root._c.radiusSmall : 8
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: root._c ? root._c.t(modelData.key) : ""

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: root._c ? root._c.spaceMd : 12
                        anchors.rightMargin: root._c ? root._c.spaceMd : 12
                        verticalAlignment: Text.AlignVCenter
                        text: root._c ? root._c.t(modelData.key) : ""
                        color: root._c ? root._c.color.onSurface : "#E6E0E9"
                        font.family: root._c ? root._c.fontFamily : "sans-serif"
                        font.pixelSize: root._c ? root._c.typePx("labelLarge") : 14
                        font.weight: 500
                        Accessible.ignored: true
                    }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._run(modelData.id)
                    }
                }
            }
        }
    }

    Item {
        width: root._btn
        height: root._btn
        anchors.bottom: parent.bottom
        anchors.right: parent.right

        Rectangle {
            anchors.fill: parent
            radius: root._c ? root._c.radiusFull : 9999
            color: ma.containsMouse || root.menuOpen
                ? (root._c ? root._c.color.surfaceContainerHighest : "#36343B")
                : (root._c ? root._c.color.surfaceContainerHigh : "#2B2930")
            border.color: root.activeFocus
                ? (root._c ? root._c.color.primary : "#D0BCFF")
                : "transparent"
            border.width: root.activeFocus ? (root._c ? root._c.strokeFocus : 2) : 0
        }

        Text {
            anchors.fill: parent
            text: "⏻"
            color: root._c ? root._c.color.onSurface : "#E6E0E9"
            font.family: root._c ? root._c.fontFamily : "sans-serif"
            font.pixelSize: root._c ? root._c.iconLg : 28
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Accessible.ignored: true
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.menuOpen = !root.menuOpen
        }
    }
}
