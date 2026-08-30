import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MCard {
    id: root

    Layout.fillWidth: true
    level: 0
    implicitHeight: body.implicitHeight + Tokens.spacing.md * 2
    Layout.preferredHeight: implicitHeight

    readonly property string _titleKey: {
        if (Update.checking && Update.pending.length === 0)
            return "settings.update.checking";
        if (Update.pending.length > 0)
            return "settings.update.available";
        return "settings.update.upToDate";
    }

    ColumnLayout {
        id: body
        width: parent.width
        spacing: Tokens.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.md

            MIcon {
                name: "system-software-update"
                size: Tokens.spacing.xxl * 2
                color: Colors.color.onSurface
                tint: true
                preferSymbolic: true
                Layout.alignment: Qt.AlignVCenter
            }
            MText {
                key: root._titleKey
                params: ({ n: String(Update.pending.length) })
                styleName: "titleLarge"
                Layout.fillWidth: true
            }
            MButton {
                kind: "tonal"
                key: "settings.mirrorsUpdate"
                iconName: "view-refresh"
                busy: Update.mirrorsRunning
                enabled: !Update.running
                Layout.alignment: Qt.AlignVCenter
                onClicked: Update.refreshMirrors()
            }
        }

        MLinearProgress {
            visible: Update.checking
            Layout.fillWidth: true
            indeterminate: true
        }
    }
}
