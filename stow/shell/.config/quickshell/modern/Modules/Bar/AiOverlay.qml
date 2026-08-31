// Layer-shell host for the AI panel while a fullscreen game covers the
// bar. BarPopup is an xdg-popup of the bar, so exclusive fullscreen
// hides it; Overlay sits above the game like the launcher.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Services"

Scope {
    id: root
    function _focusedScreen(): var {
        const n = Hypr.focusedMonitorName();
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === n)
                return screens[i];
        }
        return screens.length ? screens[0] : null;
    }

    LazyLoader {
        active: Ai.panelOpen && Ai.coverFullscreen

        PanelWindow {
            id: win
            visible: Ai.panelOpen
            screen: root._focusedScreen()
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            aboveWindows: true
            WlrLayershell.layer: WlrLayer.Overlay

            readonly property bool _barBottom: Config.bar.position === "bottom"
            readonly property bool _barLeft: Config.bar.position === "left"

            MouseArea {
                anchors.fill: parent
                onClicked: Ai.hide()
            }

            Item {
                id: card
                width: Tokens.window.chatWidth
                height: Math.min(Tokens.window.chatHeight, parent.height - Tokens.spacing.xl)
                anchors.left: win._barLeft ? parent.left : undefined
                anchors.right: !win._barLeft ? parent.right : undefined
                anchors.leftMargin: Config.bar.endGap ?? Tokens.spacing.md
                anchors.rightMargin: Config.bar.endGap ?? Tokens.spacing.md
                y: win._barBottom ? (parent.height - height) : 0
                scale: Motion.overlayScale(Ai.panelOpen)

                Behavior on scale {
                    enabled: Motion.overlaysZoom
                    NumberAnimation {
                        duration: Motion.mediumMs
                        easing.bezierCurve: Motion.easingEmphasizedDecelerate
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Loader {
                    id: panelLoader
                    anchors.fill: parent
                    source: Qt.resolvedUrl("widgets/ai/Panel.qml")
                    onLoaded: {
                        if (panelLoader.item && panelLoader.item.focusInput)
                            Qt.callLater(() => panelLoader.item.focusInput());
                        if (panelLoader.item && panelLoader.item._scrollEnd)
                            Qt.callLater(() => panelLoader.item._scrollEnd());
                    }
                }
            }

            HyprlandFocusGrab {
                id: keyGrab
                windows: [win]
                onCleared: {
                    if (Ai.panelOpen)
                        Ai.hide();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
                onActivated: Ai.hide()
            }

            Connections {
                target: Popups
                function onCloseRequested() { Ai.hide(); }
            }

            Component.onCompleted: {
                Popups.opened(win);
                Qt.callLater(() => {
                    if (!Ai.panelOpen)
                        return;
                    keyGrab.active = true;
                });
            }
            Component.onDestruction: Popups.closed(win)
        }
    }
}
