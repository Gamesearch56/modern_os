import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    Connections {
        target: Screenshot
        function onCaptured(path) {
            Notifications.toast(I18n.t("screenshot.saved"), path);
        }
    }

    LazyLoader {
        active: Screenshot.hudOpen

        PanelWindow {
            visible: Screenshot.hudOpen
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            Item {
                id: hud
                anchors.fill: parent

                property real x0: 0
                property real y0: 0
                property real x1: 0
                property real y1: 0
                property bool dragging: false

                Rectangle {
                    anchors.fill: parent
                    color: Colors.color.scrim
                    opacity: Tokens.overlay.scrim
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: (m) => {
                        hud.dragging = true;
                        hud.x0 = m.x;
                        hud.y0 = m.y;
                        hud.x1 = m.x;
                        hud.y1 = m.y;
                    }
                    onPositionChanged: (m) => {
                        if (hud.dragging) {
                            hud.x1 = m.x;
                            hud.y1 = m.y;
                        }
                    }
                    onReleased: {
                        hud.dragging = false;
                        const x = Math.round(Math.min(hud.x0, hud.x1));
                        const y = Math.round(Math.min(hud.y0, hud.y1));
                        const w = Math.round(Math.abs(hud.x1 - hud.x0));
                        const h = Math.round(Math.abs(hud.y1 - hud.y0));
                        if (w < Tokens.spacing.xxs || h < Tokens.spacing.xxs) {
                            Screenshot.cancelHud();
                            return;
                        }
                        Screenshot.finishRegion(x + "," + y + " " + w + "x" + h);
                    }
                }

                Rectangle {
                    visible: hud.dragging
                    x: Math.min(hud.x0, hud.x1)
                    y: Math.min(hud.y0, hud.y1)
                    width: Math.abs(hud.x1 - hud.x0)
                    height: Math.abs(hud.y1 - hud.y0)
                    color: "transparent"
                    border.color: Colors.color.primary
                    border.width: Tokens.spacing.xxs
                    radius: Tokens.radius.small
                }

                MText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Tokens.spacing.xl
                    key: "screenshot.dragHint"
                    styleName: "labelLarge"
                    color: Colors.color.onSurface
                }

                RowLayout {
                    z: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Tokens.spacing.xl
                    spacing: Tokens.spacing.sm

                    MChip {
                        key: "screenshot.region"
                        checked: Screenshot.mode === "region"
                        onClicked: Screenshot.mode = "region"
                    }
                    MChip {
                        key: "screenshot.window"
                        checked: Screenshot.mode === "window"
                        onClicked: Screenshot.capture("window")
                    }
                    MChip {
                        key: "screenshot.full"
                        checked: Screenshot.mode === "full"
                        onClicked: Screenshot.capture("full")
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Screenshot.cancelHud()
            }
        }
    }
}
