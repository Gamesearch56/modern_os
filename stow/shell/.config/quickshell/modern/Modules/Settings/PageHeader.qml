// Settings page chrome: caps group, title, user, close.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

RowLayout {
    id: root

    property var catalog

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.xxs

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

    MText {
        value: User.displayName
        styleName: "labelLarge"
        color: Colors.color.onSurfaceVariant
    }

    MIconButton {
        close: true
        iconName: "window-close"
        onClicked: Settings.close()
    }
}
