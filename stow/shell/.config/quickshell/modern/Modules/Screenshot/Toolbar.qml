import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

// Glass mode strip — same surface + transparency + hairline as the
// control panel. Lives on the screenshot layer so it does not frost
// the crop; compositor blur stays off for grim.
Item {
    id: root

    readonly property real _barReserve: {
        if (Config.bar.position !== "top")
            return Tokens.spacing.xl;
        const h = Config.bar.height || Tokens.spacing.xxl;
        const edge = Config.bar.style === "floating" ? (Config.bar.edgeGap ?? Tokens.spacing.sm) : 0;
        return h + edge * 2 + Tokens.spacing.sm;
    }

    implicitWidth: card.width
    implicitHeight: card.height + root._barReserve

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: root._barReserve
        width: inner.implicitWidth + Tokens.spacing.md * 2
        height: inner.implicitHeight + Tokens.spacing.md * 2
        color: Colors.color.surface
        radius: Tokens.radius.medium
        border.color: Colors.color.outlineVariant
        border.width: Tokens.stroke.hairline
        opacity: Config.design.transparency ?? 0.85
        scale: Motion.overlayScale(Screenshot.hudOpen)
        transformOrigin: Item.Top

        Behavior on scale {
            enabled: Motion.overlaysZoom
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: Screenshot.hudOpen ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            id: inner
            anchors.centerIn: parent
            spacing: Tokens.spacing.sm

            MButton {
                kind: Screenshot.mode === "region" ? "tonal" : "text"
                key: "screenshot.region"
                onClicked: Screenshot.mode = "region"
            }
            MButton {
                kind: Screenshot.mode === "window" ? "tonal" : "text"
                key: "screenshot.window"
                onClicked: Screenshot.capture("window")
            }
            MButton {
                kind: Screenshot.mode === "full" ? "tonal" : "text"
                key: "screenshot.full"
                onClicked: Screenshot.capture("full")
            }
            MIconButton {
                close: true
                iconName: "window-close"
                key: "bar.close"
                onClicked: Screenshot.cancelHud()
            }
        }
    }
}
