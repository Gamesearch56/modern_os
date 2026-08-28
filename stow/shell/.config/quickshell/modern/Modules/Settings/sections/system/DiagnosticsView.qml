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
    Rectangle {
        Layout.fillWidth: true
        height: Tokens.spacing.sm
        radius: Tokens.radius.full
        color: Colors.color.surfaceContainerHighest
        Rectangle {
            width: parent.width * Diagnostics.bootChart
            height: parent.height
            radius: parent.radius
            color: Colors.color.primary
        }
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
