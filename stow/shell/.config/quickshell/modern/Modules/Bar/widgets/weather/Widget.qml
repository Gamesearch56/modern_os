import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

RowLayout {
    spacing: Tokens.spacing.xs
    Component.onCompleted: Weather.watching = true

    MIcon {
        name: "weather-few-clouds"
        size: Tokens.spacing.lg
    }

    MText {
        key: Weather.available ? "" : "weather.unavailable"
        value: Weather.display
        styleName: "labelLarge"
    }
}
