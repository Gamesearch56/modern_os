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

    Connections {
        target: BluetoothLink
        function onSettled(ok, address) {
            if (ok || !BluetoothLink.errorKey.length)
                return;
            Notifications.toast(I18n.t("settings.bluetooth.connectFailedTitle"), I18n.t(BluetoothLink.errorKey));
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
                + Tokens.panel.toastTopClearance
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
            // Fullscreen transparent layers go black on a virtual GPU.
            // The card stays; a desktop GPU keeps the click-outside layer.
            readonly property bool _soft: Chrome.softwareGpu
            readonly property real _cardW: Tokens.spacing.xxl * 16 + (Config.bar.endGap ?? Tokens.spacing.md)
            anchors.top: overlay._soft ? Config.bar.position !== "bottom" : true
            anchors.bottom: overlay._soft ? Config.bar.position === "bottom" : true
            anchors.left: overlay._soft ? Config.bar.position === "left" : true
            anchors.right: overlay._soft ? Config.bar.position !== "left" : true
            implicitWidth: overlay._soft ? overlay._cardW : 0
            implicitHeight: overlay._soft ? Math.min(overlay.screen ? overlay.screen.height : Tokens.spacing.xxl * 24, Tokens.spacing.xxl * 24) : 0
            margins.top: overlay._soft && Config.bar.position === "top" ? overlay._barReserve : 0
            margins.bottom: overlay._soft && Config.bar.position === "bottom" ? overlay._barReserve : 0
            margins.left: overlay._soft && Config.bar.position === "left" ? overlay._barReserve : 0
            margins.right: overlay._soft && Config.bar.position === "right" ? overlay._barReserve : 0
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            aboveWindows: true
            WlrLayershell.layer: WlrLayer.Overlay
            readonly property real _barReserve: BarLayout.windowInset

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
                onClicked: Notifications.hide()
            }

            Item {
                anchors.fill: parent
                anchors.topMargin: overlay._soft ? 0 : (Config.bar.position === "top" ? overlay._barReserve : 0)
                anchors.bottomMargin: overlay._soft ? 0 : (Config.bar.position === "bottom" ? overlay._barReserve : 0)
                anchors.leftMargin: overlay._soft ? 0 : (Config.bar.position === "left" ? overlay._barReserve : 0)
                anchors.rightMargin: overlay._soft ? 0 : (Config.bar.position === "right" ? overlay._barReserve : 0)

                Panel {
                    anchors.fill: parent
                    monitorDesc: Hypr.monitorDescription(overlay.screen)
                }
            }

            HyprlandFocusGrab {
                id: keyGrab
                windows: Popups.grabWindows(overlay, overlay.screen)
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
