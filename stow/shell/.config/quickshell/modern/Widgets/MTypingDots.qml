// Three-dot wait pulse. Used instead of a fake "writing…" message.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Row {
    id: root

    property bool running: true

    spacing: Tokens.spacing.xs
    Accessible.role: Accessible.Status
    Accessible.name: I18n.t("ai.generating")

    Repeater {
        model: 3

        Rectangle {
            required property int index
            width: Tokens.spacing.sm
            height: Tokens.spacing.sm
            radius: Tokens.radius.full
            color: Colors.color.primary
            opacity: Tokens.overlay.scrim

            SequentialAnimation on opacity {
                running: root.running && root.visible
                loops: Animation.Infinite

                PauseAnimation {
                    duration: index * Motion.shortMs
                }
                NumberAnimation {
                    from: Tokens.overlay.scrim
                    to: 1
                    duration: Motion.mediumMs
                    easing.bezierCurve: Motion.easingStandard
                }
                NumberAnimation {
                    from: 1
                    to: Tokens.overlay.scrim
                    duration: Motion.mediumMs
                    easing.bezierCurve: Motion.easingStandard
                }
                PauseAnimation {
                    duration: (2 - index) * Motion.shortMs
                }
            }
        }
    }
}
