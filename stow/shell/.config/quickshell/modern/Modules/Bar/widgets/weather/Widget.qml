import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

RowLayout {
    spacing: Tokens.spacing.xs
    Component.onCompleted: Weather.watching = true
    Component.onDestruction: Weather.watching = false

    MIcon {
        name: Weather.iconName
        size: Tokens.spacing.lg
    }

    MText {
        key: Weather.available ? "" : "weather.unavailable"
        value: Weather.display
        styleName: "labelLarge"
    }
}
