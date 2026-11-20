// Layer-shell host for the taskbar panel while a fullscreen game covers
// the bar. Same reason as AiOverlay: xdg-popups cannot sit above exclusive
// fullscreen; Overlay can.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Widgets"
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
        active: Taskbar.open && Taskbar.coverFullscreen

        PanelWindow {
            id: win
            visible: Taskbar.open
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

            readonly property bool _barBottom: BarLayout.position === "bottom"
            readonly property bool _barLeft: BarLayout.position === "left"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Taskbar.hide()
            }

            MPanelSurface {
                id: card
                width: Tokens.spacing.xxl * 14
                height: Math.min(Tokens.spacing.xxl * 14, parent.height - Tokens.spacing.xl)
                anchors.left: win._barLeft ? parent.left : undefined
                anchors.right: !win._barLeft ? parent.right : undefined
                anchors.leftMargin: BarLayout.endGap ?? Tokens.spacing.md
                anchors.rightMargin: BarLayout.endGap ?? Tokens.spacing.md
                y: win._barBottom ? (parent.height - height) : 0
                scale: Motion.overlayScale(Taskbar.open)

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
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.md
                    source: Qt.resolvedUrl("widgets/taskbar/Panel.qml")
                    onLoaded: {
                        if (!item)
                            return;
                        if (item.barScreen !== undefined)
                            item.barScreen = Qt.binding(() => win.screen);
                        if (item.focusFirst)
                            Qt.callLater(() => item.focusFirst());
                    }
                }
            }

            HyprlandFocusGrab {
                id: keyGrab
                windows: Popups.grabWindows(win, win.screen)
                onCleared: {
                    if (Taskbar.open)
                        Taskbar.hide();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
                onActivated: Taskbar.hide()
            }

            Connections {
                target: Popups
                function onCloseRequested() { Taskbar.hide(); }
            }

            Component.onCompleted: {
                Popups.opened(win);
                Qt.callLater(() => {
                    if (!Taskbar.open)
                        return;
                    keyGrab.active = true;
                });
            }
            Component.onDestruction: Popups.closed(win)
        }
    }
}
