import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

ColumnLayout {
    id: root

    spacing: Tokens.spacing.sm

    MText {
        key: "wallpaper.title"
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    MText {
        key: "wallpaper.hint"
        styleName: "bodyMedium"
        color: Colors.color.onSurfaceVariant
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
