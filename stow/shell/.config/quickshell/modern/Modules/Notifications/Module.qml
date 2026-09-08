import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Services"

Scope {
    id: root

    readonly property bool idleHold: IdleInhibit.caffeine
        || (!!Config.power.inhibitOnFullscreen && Hypr.focusedFullscreen)
        || (!!Config.power.inhibitOnMedia && Media.anyPlaying)
    onIdleHoldChanged: IdleInhibit.setActive(idleHold)
    Component.onCompleted: {
        IdleInhibit.setActive(idleHold);
        void IdleDaemon.configGen;
    }

    Connections {
        target: Alarm
        function onFired() {
            Notifications.toast(I18n.t("alarm.fired"), "");
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: toastWin
            required property var modelData
            screen: modelData
            visible: !Notifications.panelOpen && Notifications.toasts.length > 0
            color: "transparent"
            implicitWidth: Tokens.spacing.xxl * 12
            implicitHeight: toastStack.implicitHeight
            anchors.top: Config.bar.position !== "bottom"
            anchors.bottom: Config.bar.position === "bottom"
            anchors.right: Config.bar.position !== "left"
            anchors.left: Config.bar.position === "left"
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            WlrLayershell.layer: WlrLayer.Overlay
            mask: Region {
                item: toastStack
            }
            margins.top: toastWin._edgeMargin(Config.bar.position === "top")
            margins.bottom: toastWin._edgeMargin(Config.bar.position === "bottom")
            margins.right: toastWin._edgeMargin(Config.bar.position === "right")
            margins.left: toastWin._edgeMargin(Config.bar.position === "left")

            function _edgeMargin(onBarEdge: bool): real {
                if (onBarEdge)
                    return BarLayout.windowInset;
                return Config.bar.endGap ?? Tokens.spacing.sm;
            }

            Toasts {
                id: toastStack
                anchors.top: Config.bar.position === "bottom" ? undefined : parent.top
                anchors.bottom: Config.bar.position === "bottom" ? parent.bottom : undefined
                anchors.right: Config.bar.position === "left" ? undefined : parent.right
                anchors.left: Config.bar.position === "left" ? parent.left : undefined
            }
        }
    }

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
        active: Notifications.panelOpen

        PanelWindow {
            id: overlay
            visible: Notifications.panelOpen
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
            margins.top: Config.bar.position === "top" ? overlay._barReserve : 0
            margins.bottom: Config.bar.position === "bottom" ? overlay._barReserve : 0
            margins.left: Config.bar.position === "left" ? overlay._barReserve : 0
            margins.right: Config.bar.position === "right" ? overlay._barReserve : 0

            readonly property real _barReserve: BarLayout.windowInset

            Panel {
                anchors.fill: parent
            }

            HyprlandFocusGrab {
                id: keyGrab
                windows: [overlay]
                onCleared: {
                    if (Notifications.panelOpen)
                        Notifications.hide();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
                onActivated: Notifications.hide()
            }

            Component.onCompleted: {
                Qt.callLater(() => {
                    if (!Notifications.panelOpen)
                        return;
                    keyGrab.active = true;
                });
            }
        }
    }
}
