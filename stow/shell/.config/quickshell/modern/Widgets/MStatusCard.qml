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
    property color iconColor: Colors.color.onSurface
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
        spacing: Tokens.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.lg

            MAvatar {
                visible: String(root.avatarSource).length > 0
                size: root.avatarSize
                source: root.avatarSource
                Layout.alignment: Qt.AlignVCenter
            }
            MIcon {
                visible: String(root.avatarSource).length === 0 && root.iconName.length > 0
                name: root.iconName
                size: Tokens.spacing.xxl * 2
                color: root.iconColor
                tint: root.iconTint
                preferSymbolic: root.preferSymbolic
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
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
                    visible: children.length > 0
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.sm
                    spacing: Tokens.spacing.xs
                }
            }

            ColumnLayout {
                id: trailingSlot
                visible: children.length > 0
                Layout.alignment: Qt.AlignVCenter
            }
        }

        ColumnLayout {
            id: extraSlot
            visible: children.length > 0
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm
        }
    }
}
