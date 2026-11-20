// One island column in MSlotBoard. Equal-width card; pointer mapping
// lives on the board so a row can be dragged into another column.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Rectangle {
    id: root

    property var board: null
    property string slotId: ""
    property string titleKey: ""
    property var items: []
    property var labelKey: function (id) { return String(id); }
    property var iconName: function (id) { return ""; }
    property var configurable: function (id) { return false; }
    property bool showLabels: true

    readonly property alias listBox: listBox
    readonly property real _rowH: Tokens.spacing.xxl + Tokens.spacing.sm
    readonly property bool _dropHover: !!(board && board._dragId.length && board._hoverSlot === slotId && board._hoverIndex >= 0)

    radius: Tokens.radius.medium
    color: Colors.color.surfaceContainerHigh
    border.width: Tokens.stroke.hairline
    border.color: root._dropHover ? Colors.color.primary : Colors.color.outlineVariant
    clip: false
    implicitHeight: Tokens.spacing.sm * 2 + col.implicitHeight

    function indexAt(y: real): int {
        const n = (root.items || []).length;
        if (root._rowH <= 0)
            return n;
        let i = Math.round(y / root._rowH);
        if (i < 0)
            i = 0;
        if (i > n)
            i = n;
        return i;
    }

    ColumnLayout {
        id: col
        x: Tokens.spacing.sm
        y: Tokens.spacing.sm
        width: parent.width - Tokens.spacing.sm * 2
        spacing: Tokens.spacing.xs

        MText {
            key: root.titleKey
            styleName: "labelMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }

        Item {
            id: listBox
            Layout.fillWidth: true
            implicitHeight: listCol.implicitHeight

            MSlotDropMark {
                active: root._dropHover
                insertIndex: root.board ? root.board._hoverIndex : -1
                rowHeight: root._rowH
                count: (root.items || []).length
            }

            ColumnLayout {
                id: listCol
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                Repeater {
                    model: (root.items || []).length

                    delegate: Item {
                        id: row
                        required property int index
                        readonly property string itemId: String((root.items || [])[index] || "")
                        readonly property bool canEdit: root.configurable(row.itemId)
                        property bool _moved: false
                        property real _pressX: 0
                        property real _pressY: 0
                        Layout.fillWidth: true
                        implicitHeight: root._rowH
                        z: drag.drag.active ? 20 : 0
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.t(root.labelKey(row.itemId))
                        Accessible.onPressAction: {
                            if (row.canEdit && root.board)
                                root.board.itemClicked(row.itemId);
                        }
                        Keys.onPressed: (event) => {
                            if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
                                return;
                            if (row.canEdit && root.board)
                                root.board.itemClicked(row.itemId);
                            event.accepted = true;
                        }
                        Rectangle {
                            id: tile
                            width: row.width
                            height: row.implicitHeight
                            radius: Tokens.radius.small
                            color: drag.drag.active ? Colors.color.primaryContainer : "transparent"

                            Rectangle {
                                anchors.fill: parent
                                radius: Tokens.radius.small
                                color: Colors.color.primary
                                opacity: row.canEdit && drag.containsMouse && !drag.drag.active
                                    ? Chrome.stateLayer(true, false) : 0
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.spacing.xs
                                anchors.rightMargin: Tokens.spacing.xs
                                spacing: Tokens.spacing.xs

                                MIcon {
                                    visible: root.iconName(row.itemId).length > 0
                                    name: root.iconName(row.itemId)
                                    size: Tokens.icon.sm
                                    color: Colors.color.primary
                                    preferSymbolic: false
                                }
                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: nameRow.implicitHeight

                                    Row {
                                        id: nameRow
                                        spacing: Tokens.spacing.xs
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter

                                        MText {
                                            visible: root.showLabels
                                            key: root.labelKey(row.itemId)
                                            styleName: "bodySmall"
                                            width: {
                                                const extra = editBadge.visible ? editBadge.width + nameRow.spacing : 0;
                                                return Math.min(implicitWidth, Math.max(0, nameRow.parent.width - extra));
                                            }
                                        }
                                        MIcon {
                                            id: editBadge
                                            visible: row.canEdit
                                            name: "document-edit-symbolic"
                                            size: Tokens.icon.xs
                                            color: Colors.color.onSurfaceVariant
                                            Accessible.name: I18n.t("settings.bar.customize")
                                        }
                                    }
                                }
                            }

                            MFocusRing {
                                id: ring
                                radius: Tokens.radius.small
                                active: row.activeFocus && ring._shown && !ring._pointer
                            }
                        }
                        MouseArea {
                            id: drag
                            anchors.fill: parent
                            preventStealing: true
                            hoverEnabled: true
                            cursorShape: drag.drag.active
                                ? Qt.ClosedHandCursor
                                : (row.canEdit ? Qt.PointingHandCursor : Qt.OpenHandCursor)
                            drag.target: tile
                            drag.axis: Drag.XAndYAxis
                            drag.threshold: Tokens.spacing.md
                            onPressed: (mouse) => {
                                ring.markPointer();
                                row._moved = false;
                                row._pressX = mouse.x;
                                row._pressY = mouse.y;
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed)
                                    return;
                                const slop = Tokens.spacing.md;
                                if (!row._moved
                                        && (Math.abs(mouse.x - row._pressX) > slop
                                            || Math.abs(mouse.y - row._pressY) > slop)) {
                                    row._moved = true;
                                    if (root.board)
                                        root.board.beginDrag(root.slotId, row.index, row.itemId);
                                }
                                if (row._moved && root.board)
                                    root.board.hoverFrom(drag, mouse.x, mouse.y);
                            }
                            onReleased: (mouse) => {
                                if (row._moved && root.board)
                                    root.board.dropFrom(drag, mouse.x, mouse.y);
                                tile.x = 0;
                                tile.y = 0;
                                if (root.board)
                                    root.board.endDrag();
                                if (!row._moved && row.canEdit && root.board)
                                    root.board.itemClicked(row.itemId);
                            }
                            onCanceled: {
                                tile.x = 0;
                                tile.y = 0;
                                if (root.board)
                                    root.board.endDrag();
                            }
                        }
                    }
                }
                MText {
                    visible: (root.items || []).length === 0
                    key: root.board ? root.board.emptyKey : ""
                    styleName: "bodySmall"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                    Layout.preferredHeight: root._rowH
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
