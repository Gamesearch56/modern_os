import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

RowLayout {
    id: root
    spacing: Tokens.spacing.xs
    Component.onCompleted: Weather.watching = true
    Component.onDestruction: Weather.watching = false

    MIcon {
        name: Weather.iconName
        size: Tokens.icon.md
    }

    MText {
        key: Weather.available ? "" : "weather.unavailable"
        value: Weather.display
        styleName: "labelLarge"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.open = !popup.open
    }

    BarPopup {
        id: popup
        open: false
        width: Tokens.spacing.xxl * 10
        height: Tokens.spacing.xxl * 8
        y: root.height + Tokens.spacing.sm
        x: root.width - width

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.sm

            MText {
                key: "weather.detailTitle"
                styleName: "titleSmall"
            }
            MText {
                value: Weather.display
                styleName: "headlineSmall"
            }
            MText {
                key: Weather.available ? "weather.condition" : "weather.unavailable"
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
            }
            MButton {
                kind: "tonal"
                key: "weather.refresh"
                onClicked: Weather.refresh()
            }
        }
    }
}
