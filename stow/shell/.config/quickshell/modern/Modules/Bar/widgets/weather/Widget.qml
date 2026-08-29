import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: row.implicitWidth + Tokens.spacing.sm
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.xs
    Component.onCompleted: Weather.watching = true
    Component.onDestruction: Weather.watching = false

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.xs

        MIcon {
            name: Weather.iconName
            size: Tokens.icon.md
        }

        MText {
            key: Weather.available ? "" : "weather.unavailable"
            value: Weather.display
            styleName: "labelLarge"
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.open = !popup.open
    }

    BarPopup {
        id: popup
        open: false
        anchorItem: root
        implicitWidth: Tokens.spacing.xxl * 10
        implicitHeight: Tokens.spacing.xxl * 14
        hAlign: Qt.AlignRight

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.sm

            MText {
                key: "weather.detailTitle"
                styleName: "headlineSmall"
            }
            MText {
                value: Weather.display
                styleName: "headlineSmall"
            }
            MText {
                key: Weather.conditionKey
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
            }
            MListItem {
                visible: Weather.available
                Layout.fillWidth: true
                titleKey: "weather.feelsLike"
                MText {
                    value: Weather.available ? (Math.round(Weather.feelsLike) + "°") : ""
                    styleName: "labelLarge"
                }
            }
            MListItem {
                visible: Weather.available
                Layout.fillWidth: true
                titleKey: "weather.humidity"
                MText {
                    value: Weather.available ? (Math.round(Weather.humidity) + "%") : ""
                    styleName: "labelLarge"
                }
            }
            MListItem {
                visible: Weather.available
                Layout.fillWidth: true
                titleKey: "weather.wind"
                MText {
                    key: Weather.imperial ? "weather.windMph" : "weather.windKmh"
                    params: { speed: Math.round(Weather.windSpeed) }
                    styleName: "labelLarge"
                }
            }
            MButton {
                kind: "tonal"
                key: "weather.refresh"
                onClicked: Weather.refresh(true)
            }
        }
    }
}
