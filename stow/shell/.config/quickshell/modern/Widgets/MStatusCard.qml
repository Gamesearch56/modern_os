// Settings hero: icon or avatar, title, subtitle, optional in-column
// detail (chips), trailing actions, and extra below the header row.
import QtQuick
import QtQuick.Layouts
import "../Commons"

MCard {
    id: root

    property string iconName: ""
    property url avatarSource: ""
    property int avatarSize: Tokens.spacing.xxl * 3
    property string titleKey: ""
    property var titleParams: ({})
    property string titleValue: ""
    property string subtitleKey: ""
    property string subtitleValue: ""
    property bool preferSymbolic: true
    property color iconColor: Colors.color.primary
    property bool iconTint: true

    default property alias extra: extraSlot.data
    property alias detail: detailSlot.data
    property alias trailing: trailingSlot.data

    Layout.fillWidth: true
    level: 0
    implicitHeight: body.implicitHeight + Tokens.spacing.md * 2
    Layout.preferredHeight: implicitHeight

    ColumnLayout {
        id: body
        width: parent.width
        // Empty slots stay in the tree. Hiding one makes a child that
        // appears later (the store button after the first probe) stay
        // invisible: Qt does not notify visibleChanged while the parent
        // column is hidden.
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: extraSlot.implicitHeight > 0 ? Tokens.spacing.md : 0
            spacing: 0

            MAvatar {
                visible: String(root.avatarSource).length > 0
                size: root.avatarSize
                source: root.avatarSource
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: visible ? Tokens.spacing.lg : 0
            }
            MIcon {
                visible: String(root.avatarSource).length === 0 && root.iconName.length > 0
                name: root.iconName
                size: Tokens.spacing.xxl * 2
                color: root.iconColor
                tint: root.iconTint
                preferSymbolic: root.preferSymbolic
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: visible ? Tokens.spacing.lg : 0
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.xs

                MText {
                    key: root.titleKey
                    params: root.titleParams
                    value: root.titleValue
                    styleName: "titleLarge"
                    Layout.fillWidth: true
                }
                MText {
                    visible: root.subtitleKey.length > 0 || root.subtitleValue.length > 0
                    key: root.subtitleKey
                    value: root.subtitleValue
                    styleName: "bodyMedium"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                ColumnLayout {
                    id: detailSlot
                    Layout.fillWidth: true
                    Layout.topMargin: implicitHeight > 0 ? Tokens.spacing.sm : 0
                    spacing: Tokens.spacing.xs
                }
            }

            ColumnLayout {
                id: trailingSlot
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: implicitWidth > 0 ? Tokens.spacing.lg : 0
            }
        }

        ColumnLayout {
            id: extraSlot
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm
        }
    }
}
