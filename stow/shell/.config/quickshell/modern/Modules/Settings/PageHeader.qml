// Settings page chrome: group cap + section title. Close lives on the
// window header once — a second X here stacked with hyprbars/SSD.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root

    property var catalog

    spacing: Tokens.spacing.xxs
    Layout.fillWidth: true

    MText {
        key: "settings.nav." + (root.catalog.group(Settings.sectionId) || "session")
        styleName: "labelSmall"
        color: Colors.color.onSurfaceVariant
        font.capitalization: Font.AllUppercase
    }

    MText {
        key: "settings.sections." + Settings.sectionId
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }
}
