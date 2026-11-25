import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

RowLayout {
    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    MDivider { Layout.fillWidth: true }
    MText {
        key: "store.newResults"
        styleName: "titleSmall"
        color: Colors.color.primary
    }
    MDivider { Layout.fillWidth: true }
}
