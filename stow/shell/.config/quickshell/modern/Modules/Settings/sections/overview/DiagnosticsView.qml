import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    spacing: Tokens.spacing.md

    MText {
        key: "diagnostics.hardware"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }
    MText {
        value: Diagnostics.hardware
        styleName: "bodyMedium"
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }

    MText {
        key: "diagnostics.software"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }
    MText {
        value: Diagnostics.software
        styleName: "bodyMedium"
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }

    MText {
        key: "diagnostics.bootTime"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }
    MLinearProgress {
        Layout.fillWidth: true
        value: Diagnostics.bootChart
    }
    MText {
        value: Diagnostics.bootSeconds
        styleName: "bodySmall"
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
