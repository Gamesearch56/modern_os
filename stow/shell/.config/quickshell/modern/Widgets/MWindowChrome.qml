// Window header: title (+ optional subtitle) on the left, close on the
// right. `titleColumnWidth` aligns the title over a Settings-style sidebar
// and grows when the title needs more room.
// Empty chrome starts the compositor move (Super+mouse).
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string titleKey: ""
    property string titleValue: ""
    property string subtitleKey: ""
    property string subtitleValue: ""
    property string actionKey: ""
    property string actionIcon: ""
    property string iconName: ""
    property real titleColumnWidth: 0
    property bool busy: false
    // The files window puts its toolbar in the header and lets it use the
    // free space. Other windows keep a trailing chip beside the close button.
    property bool trailingFill: false
    property alias trailing: trailingSlot.data

    readonly property bool _hasSubtitle: root.subtitleKey.length > 0 || root.subtitleValue.length > 0

    signal closed()
    signal actionClicked()

    function _fillTrailing() {
        if (!root.trailingFill || trailingSlot.children.length !== 1)
            return;
        const child = trailingSlot.children[0];
        if (child.anchors.fill !== trailingSlot)
            child.anchors.fill = trailingSlot;
    }

    implicitHeight: row.implicitHeight
    implicitWidth: row.implicitWidth
    Layout.fillWidth: true

    MTitleDrag {
        anchors.fill: parent
        z: -1
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Tokens.spacing.md

    ColumnLayout {
        id: titleCol
        // The sidebar width is a floor, not a cap: a longer title (German
        // "Systemeinstellungen") widens the column instead of eliding.
        Layout.preferredWidth: root.titleColumnWidth > 0 ? Math.max(root.titleColumnWidth, titleCol.implicitWidth) : -1
        Layout.fillWidth: root.titleColumnWidth <= 0 && !root.trailingFill
        spacing: 0

        RowLayout {
            spacing: Tokens.spacing.sm
            Layout.fillWidth: true

            MIcon {
                visible: root.iconName.length > 0
                name: root.iconName
                size: Tokens.icon.lg
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                spacing: Tokens.spacing.xs
                Layout.fillWidth: true

                MText {
                    key: root.titleKey
                    value: root.titleValue
                    styleName: "headlineSmall"
                    Layout.fillWidth: !root.trailingFill
                }

                MText {
                    visible: root._hasSubtitle
                    key: root.subtitleKey
                    value: root.subtitleValue
                    styleName: "bodySmall"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
            }
        }
    }

    Item {
        visible: !root.trailingFill
        Layout.fillWidth: !root.trailingFill
    }

    Item {
        id: trailingSlot
        visible: children.length > 0
        implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
        implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        Layout.fillWidth: root.trailingFill
        Layout.alignment: Qt.AlignVCenter
        onChildrenChanged: root._fillTrailing()
        onWidthChanged: root._fillTrailing()
    }

    Item {
        visible: root.busy
        implicitWidth: Tokens.icon.md
        implicitHeight: Tokens.icon.md
        Layout.alignment: Qt.AlignVCenter
        Accessible.role: Accessible.Indicator
        Accessible.name: I18n.t("settings.saving")

        MIcon {
            id: saveGlyph
            anchors.centerIn: parent
            name: "view-refresh"
            size: Tokens.icon.md
            color: Colors.color.primary
            tint: true

            RotationAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: Motion.extraLongMs
                loops: Animation.Infinite
            }
        }

        onVisibleChanged: {
            if (!visible)
                saveGlyph.rotation = 0;
        }
    }

    MIconButton {
        visible: root.actionKey.length > 0 || root.actionIcon.length > 0
        iconName: root.actionIcon.length > 0 ? root.actionIcon : "list-add"
        key: root.actionKey
        tip: true
        onClicked: root.actionClicked()
    }

    MIconButton {
        close: true
        iconName: "window-close"
        key: "bar.close"
        onClicked: root.closed()
    }
    }

    // The title sits above the row so a left-button hold always moves
    // the window, including the padding around the word.
    MTitleDrag {
        x: row.x + titleCol.x
        y: row.y + titleCol.y
        width: titleCol.width
        height: row.height
        z: 2
    }
}
