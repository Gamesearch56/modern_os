pragma Singleton

import Quickshell
import QtQuick

// The dock never stores an edge. It sits opposite the bar, and a live
// preview drops away once the saved value matches.

Singleton {
    id: root

    property real liveIconSize: -1
    property real livePad: -1
    property real liveGap: -1
    property int liveEnabled: -1
    property int liveAutoHide: -1
    property int liveShowNames: -1
    property string liveTheme: ""
    property string liveHover: ""

    // Drop a preview only after the saved value has caught up. Clearing it
    // on every reload snapped the dock off before that write was visible.
    property int _generation: Config.generation
    on_GenerationChanged: Qt.callLater(root._settle)

    function _settle() {
        const node = Config.dock;
        if (!node)
            return;
        if (root.liveEnabled >= 0 && (root.liveEnabled === 1) === (node.enabled === true))
            root.liveEnabled = -1;
        if (root.liveAutoHide >= 0 && (root.liveAutoHide === 1) === (node.autoHide === true))
            root.liveAutoHide = -1;
        if (root.liveShowNames >= 0 && (root.liveShowNames === 1) === (node.showNames === true))
            root.liveShowNames = -1;
        if (root.liveTheme.length > 0 && root.liveTheme === String(node.theme || "floating"))
            root.liveTheme = "";
        if (root.liveHover.length > 0 && root.liveHover === String(node.hover || "zoom"))
            root.liveHover = "";
        const size = Number(node.iconSize);
        if (root.liveIconSize >= 0 && Math.round(root.liveIconSize) === Math.round(size))
            root.liveIconSize = -1;
        const pad = Number(node.pad);
        if (root.livePad >= 0 && Math.round(root.livePad) === Math.round(pad))
            root.livePad = -1;
        const gap = Number(node.gap);
        if (root.liveGap >= 0 && Math.round(root.liveGap) === Math.round(gap))
            root.liveGap = -1;
    }

    function opposite(edge: string): string {
        if (edge === "bottom")
            return "top";
        if (edge === "left")
            return "right";
        if (edge === "right")
            return "left";
        return "bottom";
    }

    // A config written before the dock existed has no dock object yet.
    readonly property bool enabled: {
        void Config.generation;
        const node = Config.dock;
        const saved = !!(node && node.enabled === true);
        if (root.liveEnabled < 0)
            return saved;
        const live = root.liveEnabled === 1;
        return live === saved ? saved : live;
    }
    readonly property real iconSize: {
        void Config.generation;
        const node = Config.dock;
        const raw = node && node.iconSize !== undefined ? Number(node.iconSize) : Tokens.spacing.xl * 2;
        const saved = raw > 0 ? raw : Tokens.icon.lg;
        if (root.liveIconSize >= 0 && Math.round(root.liveIconSize) !== Math.round(saved))
            return root.liveIconSize;
        return saved;
    }
    readonly property bool autoHide: {
        void Config.generation;
        const node = Config.dock;
        const saved = !!(node && node.autoHide === true);
        if (root.liveAutoHide < 0)
            return saved;
        const live = root.liveAutoHide === 1;
        return live === saved ? saved : live;
    }
    readonly property bool showNames: {
        void Config.generation;
        const node = Config.dock;
        const saved = !!(node && node.showNames === true);
        if (root.liveShowNames < 0)
            return saved;
        const live = root.liveShowNames === 1;
        return live === saved ? saved : live;
    }
    readonly property string theme: {
        void Config.generation;
        const node = Config.dock;
        const saved = node && node.theme ? String(node.theme) : "floating";
        if (root.liveTheme.length > 0 && root.liveTheme !== saved)
            return root.liveTheme;
        return saved;
    }
    readonly property string hover: {
        void Config.generation;
        const node = Config.dock;
        const saved = node && node.hover ? String(node.hover) : "zoom";
        if (root.liveHover.length > 0 && root.liveHover !== saved)
            return root.liveHover;
        return saved;
    }
    readonly property real pad: {
        void Config.generation;
        const node = Config.dock;
        const raw = node && node.pad !== undefined ? Number(node.pad) : Tokens.spacing.sm;
        const saved = raw >= 0 ? raw : Tokens.spacing.sm;
        if (root.livePad >= 0 && Math.round(root.livePad) !== Math.round(saved))
            return root.livePad;
        return saved;
    }
    readonly property real gap: {
        void Config.generation;
        const node = Config.dock;
        const raw = node && node.gap !== undefined ? Number(node.gap) : Tokens.spacing.sm;
        const saved = raw >= 0 ? raw : Tokens.spacing.sm;
        if (root.liveGap >= 0 && Math.round(root.liveGap) !== Math.round(saved))
            return root.liveGap;
        return saved;
    }
    readonly property string position: root.opposite(BarLayout.position)
    readonly property bool vertical: root.position === "left" || root.position === "right"
    readonly property real nameBand: root.showNames && !root.vertical
        ? Typography.style("labelMedium").lineHeight + Tokens.spacing.sm : 0
    readonly property real cross: root.pad * 2 + root.iconSize + root.nameBand
    // Same gap Hyprland leaves around windows, above and below the dock.
    readonly property real screenGap: {
        void Config.generation;
        const node = Config.windows;
        const raw = node && node.gapsOut !== undefined ? Number(node.gapsOut) : 10;
        return raw >= 0 ? raw : 10;
    }
    readonly property real peek: Tokens.spacing.xs
    readonly property real windowPad: Tokens.spacing.xxs + Tokens.stroke.hairline
    readonly property real exclusive: !root.enabled || root.autoHide
        ? 0 : Math.max(0, root.cross + root.windowPad - (Config.windows.gapsOut ?? 10))
}
