import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Services"

Scope {
    readonly property bool idleHold: IdleInhibit.caffeine
        || (!!Config.power.inhibitOnFullscreen && Hypr.focusedFullscreen)
        || (!!Config.power.inhibitOnMedia && Media.playing)
    onIdleHoldChanged: IdleInhibit.setActive(idleHold)
    Component.onCompleted: {
        IdleInhibit.setActive(idleHold);
        void IdleDaemon.dimSec;
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
            implicitHeight: Tokens.spacing.xxl * 16
            anchors.top: Config.bar.position !== "bottom"
            anchors.bottom: Config.bar.position === "bottom"
            anchors.right: Config.bar.position !== "left"
            anchors.left: Config.bar.position === "left"
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            WlrLayershell.layer: WlrLayer.Overlay
            margins.top: toastWin._edgeMargin(Config.bar.position === "top")
            margins.bottom: toastWin._edgeMargin(Config.bar.position === "bottom")
            margins.right: toastWin._edgeMargin(Config.bar.position === "right")
            margins.left: toastWin._edgeMargin(Config.bar.position === "left")

            function _edgeMargin(onBarEdge: bool): real {
                if (onBarEdge) {
                    const h = Config.bar.height || Tokens.spacing.xxl;
                    const edge = Config.bar.style === "floating"
                        ? (Config.bar.edgeGap ?? Tokens.spacing.sm) : 0;
                    return h + edge * 2 + Tokens.spacing.sm;
                }
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

    LazyLoader {
        active: Notifications.panelOpen

        PanelWindow {
            id: overlay
            visible: Notifications.panelOpen
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            margins.top: Config.bar.position === "top" ? overlay._barReserve : 0
            margins.bottom: Config.bar.position === "bottom" ? overlay._barReserve : 0
            margins.left: Config.bar.position === "left" ? overlay._barReserve : 0
            margins.right: Config.bar.position === "right" ? overlay._barReserve : 0

            readonly property real _barReserve: {
                const h = Config.bar.height || Tokens.spacing.xxl;
                const edge = Config.bar.style === "floating" ? (Config.bar.edgeGap ?? Tokens.spacing.sm) : 0;
                return h + edge * 2;
            }

            Panel {
                anchors.fill: parent
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Notifications.hide()
            }
        }
    }
}
