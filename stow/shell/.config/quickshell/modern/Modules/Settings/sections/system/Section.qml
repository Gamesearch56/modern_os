import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    DiagnosticsView {
        Layout.fillWidth: true
    }

    MButton {
        kind: "filled"
        key: "settings.systemUpdate"
        iconName: "system-software-update"
        onClicked: Update.start()
    }

    MCard {
        visible: Update.open
        Layout.fillWidth: true
        level: 2

        ColumnLayout {
            spacing: Tokens.spacing.sm
            MWindowChrome {
                Layout.fillWidth: true
                titleKey: "settings.systemUpdate"
                onClosed: Update.close()
            }
            MText {
                value: Update.log
                styleName: "bodySmall"
                familyRole: "monospace"
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                Layout.fillWidth: true
            }
        }
    }
}
