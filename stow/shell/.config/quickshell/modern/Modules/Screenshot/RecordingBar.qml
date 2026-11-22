import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

// Compact stop chrome while wf-recorder runs. Must not be fullscreen —
// a pick HUD would steal clicks and dim the video. After a few seconds
// the chrome hides; a thin top/bottom band brings it back on hover.
Scope {
    id: root

    required property var screen

    readonly property real _barReserve: BarLayout.position !== "top"
        ? Tokens.spacing.xl : BarLayout.windowInset
    readonly property real _hot: Tokens.spacing.xl
    // The dock sits on the bottom by default. A full-width overlay there
    // takes every click meant for a pin.
    readonly property bool _dockBottom: DockLayout.enabled && !DockLayout.autoHide
        && DockLayout.position === "bottom"
    readonly property real _dockClear: root._dockBottom ? DockLayout.cross + Tokens.spacing.md : 0
    property bool chromeOpen: true
    property bool topHot: false
    property bool bottomHot: false
    readonly property bool edgeHot: root.topHot || root.bottomHot

    onEdgeHotChanged: {
        if (root.edgeHot) {
            hideLeave.stop();
            root.chromeOpen = true;
            return;
        }
        if (!hideAfterStart.running)
            hideLeave.restart();
    }

    Timer {
        id: hideAfterStart
        interval: Motion.recordingChromeMs
        onTriggered: {
            if (!root.edgeHot)
                root.chromeOpen = false;
        }
    }

    Timer {
        id: hideLeave
        interval: Math.max(Motion.extraLongMs, 1)
        onTriggered: {
            if (!root.edgeHot)
                root.chromeOpen = false;
        }
    }

    Component.onCompleted: hideAfterStart.start()

    PanelWindow {
        id: barWin
        screen: root.screen
        visible: Recording.active
        color: "transparent"
        implicitHeight: Math.max(strip.height, root._hot)
        anchors.top: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        // Keyboard stays with the app being recorded. Stop is the button
        // and the screenshot keys, which the compositor still receives.
        focusable: false
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        aboveWindows: true
        WlrLayershell.namespace: "modern-recording"
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region {
            item: root.chromeOpen ? card : hotTop
        }

        Item {
            id: strip
            width: barWin.width
            height: Math.max(card.height + root._barReserve, root._hot)

            HoverHandler {
                onHoveredChanged: root.topHot = hovered
            }

            Item {
                id: hotTop
                width: parent.width
                height: root._hot
            }

            RecordingChrome {
                id: card
                open: root.chromeOpen
                origin: Item.Top
                anchors.horizontalCenter: parent.horizontalCenter
                y: root._barReserve
                width: inner.implicitWidth + Tokens.spacing.md * 2
                height: inner.implicitHeight + Tokens.spacing.md * 2
                radius: Tokens.radius.medium

                RowLayout {
                    id: inner
                    z: 1
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.sm

                    MButton {
                        kind: "destructive"
                        key: "recording.stop"
                        iconName: "media-playback-stop"
                        enabled: root.chromeOpen
                        // The chrome must not join the focus chain. A focused
                        // stop button would take Return and Space.
                        tabFocus: false
                        onClicked: Recording.stop()
                    }
                }
            }
        }
    }

    PanelWindow {
        id: hintWin
        screen: root.screen
        visible: Recording.active
        color: "transparent"
        implicitHeight: Math.max(hint.height + Tokens.spacing.xl * 2 + root._dockClear, root._hot)
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        aboveWindows: true
        WlrLayershell.namespace: "modern-recording"
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region {
            item: root.chromeOpen ? hint : (root._dockBottom ? noInput : hotBottom)
        }

        Item {
            id: hintBand
            anchors.fill: parent

            HoverHandler {
                onHoveredChanged: root.bottomHot = hovered
            }

            Item {
                id: hotBottom
                width: parent.width
                height: root._hot
                anchors.bottom: parent.bottom
            }

            Item {
                id: noInput
                width: 0
                height: 0
            }

            RecordingChrome {
                id: hint
                open: root.chromeOpen
                origin: Item.Bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Tokens.spacing.xl + root._dockClear
                width: hintLabel.implicitWidth + Tokens.spacing.md * 2
                height: hintLabel.implicitHeight + Tokens.spacing.sm * 2
                radius: Tokens.radius.full

                MText {
                    id: hintLabel
                    anchors.centerIn: parent
                    key: "recording.stopHint"
                    styleName: "labelLarge"
                }
            }
        }
    }
}
