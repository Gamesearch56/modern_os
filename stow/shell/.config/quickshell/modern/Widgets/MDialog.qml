// Modal dialog: scrim + centered MCard. `titleKey` / `bodyKey` are
// I18n paths. Confirm/cancel buttons emit signals; the caller decides
// what they do (power-off confirm, user-delete confirm).
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property bool open: false
    property string titleKey: ""
    property string bodyKey: ""
    property var bodyParams: ({})
    property string confirmKey: "powerMenu.confirmTitle"
    property string cancelKey: "powerMenu.cancel"
    property bool destructive: false

    signal confirmed()
    signal cancelled()

    visible: root.open || scrim.opacity > 0
    z: 100

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: root.open ? 0.5 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.medium()
                easing.bezierCurve: Motion.easingEmphasized
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancelled()
        }
    }

    MCard {
        id: card
        level: 5
        width: Math.min(parent.width - Tokens.spacing.xxl, Tokens.spacing.xxl * 12)
        anchors.centerIn: parent
        scale: root.open ? 1 : 0.92
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.medium()
                easing.bezierCurve: Motion.easingEmphasizedDecelerate
            }
        }
        Behavior on scale {
            SpringAnimation {
                spring: Motion.springGentle.spring
                damping: Motion.springGentle.damping
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.md

            MText {
                key: root.titleKey
                styleName: "headlineSmall"
                Layout.fillWidth: true
            }

            MText {
                key: root.bodyKey
                params: root.bodyParams
                styleName: "bodyMedium"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Tokens.spacing.sm

                MButton {
                    kind: "text"
                    key: root.cancelKey
                    onClicked: root.cancelled()
                }

                MButton {
                    kind: "filled"
                    key: root.confirmKey
                    onClicked: root.confirmed()
                }
            }
        }
    }

    Keys.onEscapePressed: root.cancelled()
}
