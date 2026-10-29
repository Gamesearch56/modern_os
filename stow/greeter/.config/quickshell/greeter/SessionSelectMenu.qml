// Dropdown rows for SessionSelect. HoverHandler matches MListItem;
// ListView MouseArea.containsMouse is not delivered on this kiosk.
import QtQuick

Rectangle {
    id: root

    property var chrome: null
    property var rows: []
    property var value: ""

    signal chosen(var value)

    readonly property var _c: root.chrome
    readonly property var _rows: root.rows || []
    readonly property int _count: {
        const n = root._rows.length;
        return (typeof n === "number" && n > 0) ? n : 0;
    }

    z: 80
    implicitHeight: Math.min(list.contentHeight, (root._c ? root._c.fieldHeight : 36) * 6)
        + (root._c ? root._c.spaceSm * 2 : 16)
    radius: root._c ? root._c.radiusMedium : 16
    color: root._c ? root._c.color.surfaceContainer : "#211F26"
    border.color: root._c ? root._c.color.outlineVariant : "#49454F"
    border.width: root._c ? root._c.strokeHairline : 1

    function moveDown() {
        list.incrementCurrentIndex();
    }

    function moveUp() {
        list.decrementCurrentIndex();
    }

    function chooseCurrent() {
        const opt = root._rows[list.currentIndex];
        if (opt)
            root.chosen(opt.value);
    }

    function syncIndex() {
        const rows = root._rows;
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i].value) === String(root.value)) {
                list.currentIndex = i;
                return;
            }
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: root._c ? root._c.spaceSm : 8
        clip: true
        model: root._count
        keyNavigationEnabled: true
        highlightFollowsCurrentItem: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: row
            required property int index
            readonly property var opt: root._rows[index] || ({})
            readonly property bool _sel: String(opt.value) === String(root.value)
            readonly property bool _hot: hover.hovered || list.currentIndex === index
            width: list.width
            height: root._c ? root._c.fieldHeight : 36
            Accessible.role: Accessible.MenuItem
            Accessible.name: root._c && root._c.accountTitle
                ? root._c.accountTitle(opt)
                : (opt.titleValue || String(opt.value || ""))

            HoverHandler {
                id: hover
            }

            Rectangle {
                anchors.fill: parent
                radius: root._c ? root._c.radiusSmall : 8
                color: row._sel
                    ? (root._c ? root._c.color.primaryContainer : "#4F378B")
                    : "transparent"
            }

            Rectangle {
                anchors.fill: parent
                radius: root._c ? root._c.radiusSmall : 8
                color: root._c ? root._c.color.primary : "#D0BCFF"
                opacity: row._sel ? 0 : (row._hot ? (root._c ? root._c.hoverLayer : 0.08) : 0)
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: root._c ? root._c.spaceMd : 12
                anchors.rightMargin: root._c ? root._c.spaceMd : 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: root._c && root._c.accountTitle
                    ? root._c.accountTitle(opt)
                    : (opt.titleValue || String(opt.value || ""))
                color: row._sel
                    ? (root._c ? root._c.color.onPrimaryContainer : "#EADDFF")
                    : (root._c ? root._c.color.onSurface : "#E6E0E9")
                font.family: root._c ? root._c.fontFamily : "sans-serif"
                font.pixelSize: root._c ? root._c.typePx("bodyLarge") : 16
                Accessible.ignored: true
            }

            MouseArea {
                z: -1
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.chosen(opt.value)
            }
        }
    }
}
