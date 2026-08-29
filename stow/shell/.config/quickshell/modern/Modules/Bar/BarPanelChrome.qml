// Shared bar-popup frame: headline + optional trailing actions + close,
// then caller-supplied body. Matches the AI panel / control-panel well.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root

    property string titleKey: ""
    property alias actions: actionRow.data

    spacing: Tokens.spacing.md
    Layout.fillWidth: true
    Layout.fillHeight: true

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm

        MText {
            key: root.titleKey
            styleName: "headlineMedium"
            Layout.fillWidth: true
        }

        RowLayout {
            id: actionRow
            spacing: Tokens.spacing.xs
        }

        MIconButton {
            close: true
            iconName: "window-close"
            key: "bar.close"
            onClicked: Popups.dismiss()
        }
    }
}
