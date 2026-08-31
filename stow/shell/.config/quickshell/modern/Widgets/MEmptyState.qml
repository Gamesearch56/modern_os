// Centered empty pane: icon + title + hint. Parent must give this
// item fill width/height so it is not stuck at the bottom of a column.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string iconName: "dialog-information"
    property url iconSource: ""
    property int iconSize: Tokens.spacing.xxl
    property string titleKey: ""
    property string hintKey: ""
    property string actionKey: ""
    property bool tintIcon: true
    property bool preferSymbolic: true

    signal actionClicked()

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Tokens.spacing.xl * 2, Tokens.spacing.xxl * 12)
        spacing: Tokens.spacing.sm

        MIcon {
            Layout.alignment: Qt.AlignHCenter
            name: root.iconName
            source: root.iconSource
            size: root.iconSize
            color: Colors.color.primary
            tint: root.tintIcon
            preferSymbolic: root.preferSymbolic
        }

        MText {
            key: root.titleKey
            styleName: "titleMedium"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        MHint {
            visible: root.hintKey.length > 0
            key: root.hintKey
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        MButton {
            visible: root.actionKey.length > 0
            Layout.alignment: Qt.AlignHCenter
            kind: "tonal"
            key: root.actionKey
            onClicked: root.actionClicked()
        }
    }
}
