import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    Model { id: model }

    MText {
        key: "settings.sections.system"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    DiagnosticsView {
        Layout.fillWidth: true
    }
}
