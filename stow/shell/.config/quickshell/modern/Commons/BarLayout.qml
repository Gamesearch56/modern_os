// Bar strip vs Hyprland exclusive zone. gaps_out must not stack under
// the bar; overlays use windowInset so they share the tiled window top.
// windowPad is the extra gap between that line and the bar strip.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property real edge: Config.bar.style === "floating"
        ? (Config.bar.edgeGap ?? Tokens.spacing.sm) : 0
    readonly property real strip: (Config.bar.height || Tokens.spacing.xxl) + root.edge * 2
    readonly property real windowPad: Tokens.spacing.xxs + Tokens.stroke.hairline
    readonly property real exclusive: Config.bar.autoHide
        ? 0 : Math.max(0, root.strip + root.windowPad - (Config.windows.gapsOut ?? 10))
    readonly property real windowInset: root.strip + root.windowPad
    readonly property real popupGap: root.edge + root.windowPad
    // Side bars are too narrow for labels; widgets show icons (cover for media).
    readonly property bool vertical: Config.bar.position === "left" || Config.bar.position === "right"
}
