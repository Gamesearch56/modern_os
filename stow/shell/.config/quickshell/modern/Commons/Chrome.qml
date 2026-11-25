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

    // Set by Hyprland only when the display is virtual. Desktop GPUs
    // leave it unset, so glass and blur stay as designed.
    readonly property bool softwareGpu: Quickshell.env("MODERN_SOFTWARE_GPU") === "1"

    // Settings -> Gaming -> Performance. Hyprland drops blur behind the
    // shell with the same key (modules/light_effects.lua), and a
    // see-through panel without frost is just hard to read.
    readonly property bool lightEffects: Config.gaming.autoOptimize === true

    readonly property real washOpacity: {
        // The speed switch is a solid panel on purpose. A virtual GPU
        // keeps this wash: its blur pass is black, and the software
        // scene graph still carries the alpha, so the wallpaper shows
        // through the same tint a desktop GPU frosts.
        if (root.lightEffects)
            return 1;
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
