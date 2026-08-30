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

    readonly property real _barReserve: Config.bar.position !== "top"
        ? Tokens.spacing.xl : BarLayout.windowInset

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

            MIconButton {
                iconName: "camera-photo"
                key: "screenshot.capture"
                checked: Screenshot.tool === "screenshot"
                onClicked: Screenshot.tool = "screenshot"
            }
            MIconButton {
                iconSource: Qt.resolvedUrl("video-camera.svg")
                key: "recording.start"
                checked: Screenshot.tool === "recording"
                onClicked: Screenshot.tool = "recording"
            }
            MButton {
                kind: Screenshot.mode === "region" ? "tonal" : "text"
                key: "screenshot.region"
                onClicked: Screenshot.mode = "region"
            }
            MButton {
                kind: Screenshot.mode === "window" ? "tonal" : "text"
                key: "screenshot.window"
                onClicked: {
                    Screenshot.mode = "window";
                    if (Screenshot.tool === "recording") {
                        Screenshot.cancelHud();
                        Recording.start("window", "", "");
                        return;
                    }
                    Screenshot.capture("window");
                }
            }
            MButton {
                kind: Screenshot.mode === "full" ? "tonal" : "text"
                key: "screenshot.full"
                onClicked: {
                    Screenshot.mode = "full";
                    if (Screenshot.tool === "recording") {
                        Screenshot.cancelHud();
                        Recording.start("full", "", "");
                        return;
                    }
                    Screenshot.capture("full");
                }
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
