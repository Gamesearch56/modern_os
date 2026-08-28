// Non-color, non-motion design tokens — spacing, shape (corner radius)
// and elevation. See docs/DESIGN.md's "Shape"/"Elevation" sections.
// Colors live in the matugen-generated Colors.qml (docs/THEMING.md);
// motion lives in Motion.qml (docs/MOTION.md). Splitting these three
// keeps each one regenerable/hand-edited independently without merge
// conflicts or accidentally overwriting hand-written values.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property real cornerScale: Config.design.cornerRounding ?? 1.0

    // Base MD3 shape scale (px at cornerScale 1.0). Multiply, don't
    // replace, so a user's rounding preference scales every corner
    // proportionally instead of only affecting some components.
    readonly property QtObject radius: QtObject {
        readonly property real small: 8 * root.cornerScale
        readonly property real medium: 16 * root.cornerScale
        readonly property real large: 28 * root.cornerScale
        readonly property real full: 9999 // pill shapes — never scaled, always fully round
    }

    // 4px base spacing unit (MD3's standard grid). Widgets/Modules
    // should compose these rather than writing bare pixel numbers.
    readonly property QtObject spacing: QtObject {
        readonly property real xxs: 2
        readonly property real xs: 4
        readonly property real sm: 8
        readonly property real md: 12
        readonly property real lg: 16
        readonly property real xl: 24
        readonly property real xxl: 32
    }

    // MD3 tonal elevation: a surfaceTint opacity mixed over the base
    // surface color, plus a subtle, optional shadow. level0 is "resting
    // on the background", level5 is the highest (e.g. a modal dialog).
    // Applied via MCard's background — no other component draws its own
    // shadow (docs/DESIGN.md).
    readonly property real surfaceTint: Config.design.surfaceTint ?? 1.0

    readonly property var elevation: [
        { tintOpacity: 0.0, shadowOpacity: 0.0, shadowRadius: 0 },
        { tintOpacity: 0.10, shadowOpacity: 0.08, shadowRadius: 3 },
        { tintOpacity: 0.16, shadowOpacity: 0.1, shadowRadius: 6 },
        { tintOpacity: 0.22, shadowOpacity: 0.12, shadowRadius: 10 },
        { tintOpacity: 0.24, shadowOpacity: 0.14, shadowRadius: 14 },
        { tintOpacity: 0.28, shadowOpacity: 0.16, shadowRadius: 20 }
    ]

    readonly property QtObject overlay: QtObject {
        readonly property real scrim: 0.32
        readonly property real lock: 0.48
    }

    function elevationFor(level: int): var {
        const raw = elevation[Math.max(0, Math.min(level, elevation.length - 1))];
        return {
            tintOpacity: Math.min(1, raw.tintOpacity * root.surfaceTint),
            shadowOpacity: raw.shadowOpacity,
            shadowRadius: raw.shadowRadius
        };
    }
}
