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
    readonly property var _rows: root.model || []
    readonly property string _label: {
        const rows = root._rows;
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i].value) === String(root.value))
                return rows[i].titleValue || String(rows[i].value || "");
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
            font.family: root._c ? root._c.fontFamily : "Inter"
            font.pixelSize: root._c ? root._c.typePx("bodyLarge") : 16
            Accessible.ignored: true
        }

        Text {
            text: root.menuOpen ? "▴" : "▾"
            color: root._c ? root._c.color.onSurfaceVariant : "#CAC4D0"
            font.pixelSize: root._c ? root._c.typePx("labelLarge") : 14
            Accessible.ignored: true
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled && root.tabFocus
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
            list.incrementCurrentIndex();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Up) {
            list.decrementCurrentIndex();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const opt = root._rows[list.currentIndex];
            if (opt)
                root._choose(opt.value);
            event.accepted = true;
        }
    }

    Rectangle {
        visible: root.menuOpen
        anchors.top: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root._c ? root._c.spaceXs : 4
        implicitHeight: Math.min(list.contentHeight, (root._c ? root._c.fieldHeight : 36) * 6)
            + (root._c ? root._c.spaceSm * 2 : 16)
        radius: root._c ? root._c.radiusMedium : 16
        color: root._c ? root._c.color.surfaceContainerHighest : "#36343B"
        border.color: root._c ? root._c.color.outlineVariant : "#49454F"
        border.width: root._c ? root._c.strokeHairline : 1

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: root._c ? root._c.spaceSm : 8
            clip: true
            model: root._rows.length
            keyNavigationEnabled: true
            highlightFollowsCurrentItem: true
            onVisibleChanged: {
                if (!visible)
                    return;
                const rows = root._rows;
                for (let i = 0; i < rows.length; i++) {
                    if (String(rows[i].value) === String(root.value)) {
                        list.currentIndex = i;
                        break;
                    }
                }
            }

            delegate: Rectangle {
                required property int index
                readonly property var opt: root._rows[index] || ({})
                width: list.width
                implicitHeight: root._c ? root._c.fieldHeight : 36
                radius: root._c ? root._c.radiusSmall : 8
                color: String(opt.value) === String(root.value) || list.currentIndex === index
                    ? (root._c ? root._c.color.primaryContainer : "#4F378B")
                    : "transparent"
                Accessible.role: Accessible.MenuItem
                Accessible.name: opt.titleValue || String(opt.value || "")

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: root._c ? root._c.spaceMd : 12
                    anchors.rightMargin: root._c ? root._c.spaceMd : 12
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: opt.titleValue || String(opt.value || "")
                    color: String(opt.value) === String(root.value) || list.currentIndex === index
                        ? (root._c ? root._c.color.onPrimaryContainer : "#EADDFF")
                        : (root._c ? root._c.color.onSurface : "#E6E0E9")
                    font.family: root._c ? root._c.fontFamily : "Inter"
                    font.pixelSize: root._c ? root._c.typePx("bodyLarge") : 16
                    Accessible.ignored: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._choose(opt.value)
                }
            }
        }
    }
}
