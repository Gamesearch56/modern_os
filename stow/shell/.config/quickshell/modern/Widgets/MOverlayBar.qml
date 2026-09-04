// Overlay card title row. Drag is layer-local (MTitleDrag.systemMove false).
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string titleKey: ""
    property string titleValue: ""
    property string subtitleKey: ""
    property string actionKey: ""
    property string actionIcon: ""
    property bool closeVisible: true
    property Item space: null
    property alias headerExtra: extraRow.data
    readonly property alias offsetX: titleDrag.offsetX
    readonly property alias offsetY: titleDrag.offsetY

    signal closed()
    signal actionClicked()

    implicitHeight: head.implicitHeight

    MTitleDrag {
        id: titleDrag
        anchors.fill: parent
        z: -1
        systemMove: false
        space: root.space
    }

    RowLayout {
        id: head
        anchors.fill: parent
        spacing: Tokens.spacing.sm

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs

            MText {
                key: root.titleKey
                value: root.titleValue
                styleName: "headlineSmall"
                Layout.fillWidth: true
            }
            MText {
                visible: root.subtitleKey.length > 0
                key: root.subtitleKey
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        RowLayout {
            id: extraRow
            spacing: Tokens.spacing.xs
            visible: children.length > 0
        }

        MButton {
            visible: root.actionKey.length > 0
            kind: "text"
            key: root.actionKey
            iconName: root.actionIcon
            onClicked: root.actionClicked()
        }

        MIconButton {
            visible: root.closeVisible
            close: true
            iconName: "window-close"
            key: "bar.close"
            onClicked: root.closed()
        }
    }
}
