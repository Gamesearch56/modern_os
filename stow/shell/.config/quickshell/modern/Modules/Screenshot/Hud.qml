import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

// One region overlay per output. Mouse coords are local to this
// surface. screenshot.sh adds hyprctl's monitor x/y so grim -g is
// compositor-global (grim forbids combining -o and -g).
// Namespace is not "quickshell" so decoration.blur does not frost the crop.
PanelWindow {
    id: root

    visible: Screenshot.hudOpen && !Recording.active
    color: "transparent"
    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    focusable: Screenshot.hudOpen && !Recording.active
    WlrLayershell.namespace: "modern-screenshot"

    Item {
        id: hud
        anchors.fill: parent

        property real x0: 0
        property real y0: 0
        property real x1: 0
        property real y1: 0
        property bool dragging: false
        readonly property real selX: Math.min(hud.x0, hud.x1)
        readonly property real selY: Math.min(hud.y0, hud.y1)
        readonly property real selW: Math.abs(hud.x1 - hud.x0)
        readonly property real selH: Math.abs(hud.y1 - hud.y0)

        function outputName() {
            const scr = root.screen;
            const mon = Hypr.monitorForScreen(scr);
            if (mon && mon.name)
                return String(mon.name);
            if (scr && scr.name)
                return String(scr.name);
            return "";
        }

        component DimBand: Rectangle {
            color: Colors.color.scrim
            opacity: Tokens.overlay.scrim
        }

        DimBand {
            x: 0
            y: 0
            width: hud.width
            height: hud.dragging ? hud.selY : hud.height
        }
        DimBand {
            visible: hud.dragging
            x: 0
            y: hud.selY
            width: hud.selX
            height: hud.selH
        }
        DimBand {
            visible: hud.dragging
            x: hud.selX + hud.selW
            y: hud.selY
            width: hud.width - hud.selX - hud.selW
            height: hud.selH
        }
        DimBand {
            visible: hud.dragging
            x: 0
            y: hud.selY + hud.selH
            width: hud.width
            height: hud.height - hud.selY - hud.selH
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
                const x = Math.round(hud.selX);
                const y = Math.round(hud.selY);
                const w = Math.round(hud.selW);
                const h = Math.round(hud.selH);
                if (w < Tokens.spacing.xxs || h < Tokens.spacing.xxs) {
                    Screenshot.cancelHud();
                    return;
                }
                const geom = x + "," + y + " " + w + "x" + h;
                const output = hud.outputName();
                if (Screenshot.tool === "recording") {
                    Screenshot.cancelHud();
                    Recording.start("region", geom, output);
                    return;
                }
                Screenshot.finishRegion(geom, output);
            }
        }

        Rectangle {
            visible: hud.dragging
            x: hud.selX
            y: hud.selY
            width: hud.selW
            height: hud.selH
            color: "transparent"
            border.color: Colors.color.primary
            border.width: Tokens.spacing.xxs
            radius: Tokens.radius.small
        }

        Rectangle {
            visible: !hud.dragging
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

            MText {
                id: hintLabel
                anchors.centerIn: parent
                key: "screenshot.dragHint"
                styleName: "labelLarge"
            }
        }

        Toolbar {
            z: 2
            visible: !hud.dragging
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: Screenshot.hudOpen && !Recording.active
        onActivated: Screenshot.cancelHud()
    }
}
