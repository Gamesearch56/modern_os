import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

// Compact stop chrome while wf-recorder runs. Must not be fullscreen —
// a pick HUD would steal clicks and dim the video.
Scope {
    id: root

    required property var screen

    readonly property real _barReserve: Config.bar.position !== "top"
        ? Tokens.spacing.xl : BarLayout.windowInset

    PanelWindow {
        id: barWin
        screen: root.screen
        visible: Recording.active
        color: "transparent"
        implicitHeight: strip.height
        anchors.top: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        focusable: Recording.active
        aboveWindows: true
        WlrLayershell.namespace: "modern-recording"
        WlrLayershell.layer: WlrLayer.Overlay

        Item {
            id: strip
            width: barWin.width
            height: card.height + root._barReserve

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

                MouseArea {
                    anchors.fill: parent
                }

                RowLayout {
                    id: inner
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.sm

                    MButton {
                        kind: "destructive"
                        key: "recording.stop"
                        iconName: "media-playback-stop"
                        onClicked: Recording.stop()
                    }
                }
            }
        }

        Shortcut {
            sequence: "Escape"
            enabled: Recording.active
            onActivated: Recording.stop()
        }
    }

    PanelWindow {
        id: hintWin
        screen: root.screen
        visible: Recording.active
        color: "transparent"
        implicitHeight: hint.height + Tokens.spacing.xl * 2
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        WlrLayershell.namespace: "modern-recording"
        WlrLayershell.layer: WlrLayer.Overlay

        Rectangle {
            id: hint
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.spacing.xl
            width: hintLabel.implicitWidth + Tokens.spacing.md * 2
            height: hintLabel.implicitHeight + Tokens.spacing.sm * 2
            color: Colors.color.surface
            radius: Tokens.radius.full
            border.color: Colors.color.outlineVariant
            border.width: Tokens.stroke.hairline
            opacity: Config.design.transparency ?? 0.85

            MouseArea {
                anchors.fill: parent
            }

            MText {
                id: hintLabel
                anchors.centerIn: parent
                key: "recording.stopHint"
                styleName: "labelLarge"
            }
        }

        Shortcut {
            sequence: "Escape"
            enabled: Recording.active
            onActivated: Recording.stop()
        }
    }
}
