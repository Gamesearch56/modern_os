// Shared filled / tonal / nav-selected role maps so Widgets never
// disagree on which MD3 pair a chrome variant uses.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property var filled: ({
        bg: Colors.color.primary,
        fg: Colors.color.onPrimary
    })

    readonly property var tonal: ({
        bg: Colors.color.primaryContainer,
        fg: Colors.color.onPrimaryContainer
    })

    readonly property var navSelected: ({
        bg: Colors.color.primary,
        fg: Colors.color.onPrimary
    })

    readonly property var navIdle: ({
        bg: "transparent",
        fg: Colors.color.onSurface
    })

    readonly property color washColor: {
        void Colors.color;
        return Colors.color.surface;
    }

    readonly property real surfaceLuminance: {
        const c = root.washColor;
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }

    readonly property real washOpacity: {
        void Config.design.transparency;
        void Tokens.glass;
        const t = Config.design.transparency ?? 0.85;
        const lift = Math.max(0, root.surfaceLuminance - Tokens.glass.liftFrom);
        const pass = (1 - t) * (1 + lift * Tokens.glass.passBoost);
        return Math.max(Tokens.glass.minWash, Math.min(1, 1 - pass));
    }

    function stateLayer(hover: bool, press: bool): real {
        if (press)
            return Tokens.interaction.press;
        if (hover)
            return Tokens.interaction.hover;
        return 0;
    }
}
