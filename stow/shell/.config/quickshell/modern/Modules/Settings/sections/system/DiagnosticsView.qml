// Boot/journal snapshot embed. Sets Diagnostics.watching so the Service
// timer runs only while this view is in the tree (Settings > System).
import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    Component.onCompleted: Diagnostics.watching = true
    Component.onDestruction: Diagnostics.watching = false

    MText {
        key: "diagnostics.bootTime"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: Diagnostics.bootSeconds
        styleName: "bodyMedium"
        familyRole: "monospace"
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }

    MText {
        key: "diagnostics.journalErrors"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    MText {
        value: Diagnostics.journalErrors
        styleName: "bodySmall"
        familyRole: "monospace"
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }

    MButton {
        kind: "tonal"
        key: "settings.refresh"
        onClicked: Diagnostics.refresh()
    }
}
