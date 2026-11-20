// Bar strip vs Hyprland exclusive zone. gaps_out must not stack under
// the bar; overlays use windowInset so they share the tiled window top.
// windowPad is the extra gap between that line and the bar strip.
// Nested bar numbers do not notify when config.json reloads, so every
// reader goes through these properties. A drag sets live* first; once
// the saved value catches up, the preview drops away.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property real liveHeight: -1
    property real liveEdge: -1
    property real liveEnd: -1
    property string livePosition: ""
    property int liveAutoHide: -1

    readonly property real height: {
        void Config.generation;
        const saved = Number(Config.bar.height || 36);
        if (root.liveHeight >= 0 && Math.round(root.liveHeight) !== Math.round(saved))
            return root.liveHeight;
        return saved;
    }
    readonly property real edgeGap: {
        void Config.generation;
        const saved = Number(Config.bar.edgeGap ?? 8);
        if (root.liveEdge >= 0 && Math.round(root.liveEdge) !== Math.round(saved))
            return root.liveEdge;
        return saved;
    }
    readonly property real endGap: {
        void Config.generation;
        const saved = Number(Config.bar.endGap ?? 8);
        if (root.liveEnd >= 0 && Math.round(root.liveEnd) !== Math.round(saved))
            return root.liveEnd;
        return saved;
    }
    readonly property string position: {
        void Config.generation;
        const saved = String(Config.bar.position || "top");
        if (root.livePosition.length > 0 && root.livePosition !== saved)
            return root.livePosition;
        return saved;
    }
    readonly property bool autoHide: {
        void Config.generation;
        const saved = Config.bar.autoHide === true;
        if (root.liveAutoHide < 0)
            return saved;
        const live = root.liveAutoHide === 1;
        return live === saved ? saved : live;
    }

    readonly property real edge: root.edgeGap
    readonly property real strip: root.height + root.edge * 2
    readonly property real windowPad: Tokens.spacing.xxs + Tokens.stroke.hairline
    readonly property real exclusive: root.autoHide
        ? 0 : Math.max(0, root.strip + root.windowPad - (Config.windows.gapsOut ?? 10))
    readonly property real windowInset: root.strip + root.windowPad
    readonly property real popupGap: root.edge + root.windowPad
    readonly property bool vertical: root.position === "left" || root.position === "right"
}
