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
        // Toast banners sit 10px tighter than xl so the glyph hugs the title.
        readonly property real bannerIconText: 14
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
        readonly property real previewFill: 0.8
    }

    // Light surfaces sit near tone 98; the same alpha as dark chrome
    // reads as a sheet. Chrome.washOpacity boosts pass-through once
    // luminance clears liftFrom. Slider 1.0 stays fully opaque.
    readonly property QtObject glass: QtObject {
        readonly property real liftFrom: 0.25
        readonly property real passBoost: 3.2
        readonly property real minWash: 0.28
    }

    readonly property QtObject icon: QtObject {
        readonly property real xs: 16
        readonly property real sm: 20
        readonly property real md: 24
        readonly property real lg: 40
    }

    readonly property QtObject interaction: QtObject {
        readonly property real hover: 0.08
        readonly property real press: 0.12
        readonly property real focus: 0.12
        // Drag-box fill stays see-through so the names under it stay readable.
        readonly property real band: 0.32
        // A cut file stays visible, but clearly waiting to move.
        readonly property real cut: 0.45
        // A normally hidden name stays listed, but reads as faded.
        readonly property real hidden: 0.5
    }

    // Hairline rest stroke vs MD3 2dp focus/hover indicator.
    readonly property QtObject stroke: QtObject {
        readonly property real hairline: 1
        readonly property real focus: 2
    }

    readonly property QtObject window: QtObject {
        id: win
        readonly property real settingsWidth: root.spacing.xxl * 32 + root.spacing.lg
        readonly property real settingsHeight: root.spacing.xxl * 22 + root.spacing.lg
        readonly property real filesCell: root.spacing.xxl * 5
        // Wide enough for a full place name beside an icon, and for a
        // volume name beside the eject button.
        readonly property real filesPlaces: root.spacing.xxl * 9
        // Shell margins, the places column, the gap beside it, five
        // cells, and the md gaps between those cells. No leftover, so
        // the last column meets the pane edge. Keep windows.lua
        // modern-files size in sync or the first open jumps.
        readonly property real filesWidth: win.filesPlaces
                + root.spacing.md * 3
                + win.filesCell * 5
                + root.spacing.md * 4
        readonly property real filesHeight: root.spacing.xxl * 22
        readonly property real storeWidth: root.spacing.xxl * 32 + root.spacing.lg
        readonly property real storeHeight: root.spacing.xxl * 22 + root.spacing.lg
        readonly property real reportWidth: root.spacing.xxl * 24 + root.spacing.lg
        readonly property real reportHeight: root.spacing.xxl * 24 + root.spacing.lg + root.spacing.xs
        readonly property real overlayWidth: root.spacing.xxl * 24
        readonly property real overlayHeight: root.spacing.xxl * 20
        // Same frame the video preview uses for autofit.
        readonly property real quicklookFit: 0.8
        readonly property real chatWidth: root.spacing.xxl * 14
        readonly property real chatHeight: root.spacing.xxl * 18
        readonly property real providerWidth: 1200
        readonly property real providerHeight: 800
    }

    readonly property QtObject panel: QtObject {
        readonly property real popupMin: root.spacing.xxl * 10
        readonly property real cheatsheetNav: root.spacing.xxl * 8
        readonly property real powerWidth: root.spacing.xxl * 12
        readonly property real dialogWidth: root.spacing.xxl * 12
        readonly property real dialogWide: root.spacing.xxl * 18
        readonly property real launcherWidth: root.spacing.xxl * 16
        // Toasts drop below a typical app header bar so they don't hide
        // the window's own buttons in its top row.
        readonly property real toastTopClearance: root.spacing.xxl
    }

    // Workspace overview. swipeTravel is how far three fingers must
    // move to go from hidden to fully open; the reveal tracks that
    // distance instead of a timer. The frost itself is the compositor
    // blur on the quickshell layer, plus the surface wash.
    readonly property QtObject overview: QtObject {
        readonly property real swipeTravel: root.spacing.xxl * 9
        readonly property real labelGap: root.spacing.sm
        // Two caption lines (name, workspace) under the preview.
        readonly property real caption: root.spacing.xl + root.spacing.md
        // Tiles stay a preview, centered, instead of stretching to the
        // monitor. The cap is a maximum; a crowded grid still shrinks.
        readonly property real gap: root.spacing.xxl + root.spacing.lg
        readonly property real inset: root.spacing.xxl
        readonly property real maxWidth: root.spacing.xxl * 16
        readonly property real maxHeight: root.spacing.xxl * 10
    }

    readonly property QtObject recents: QtObject {
        readonly property real cardWidth: root.spacing.xxl * 11
        readonly property real cardHeight: root.spacing.xxl * 10
        readonly property real wellHeight: root.spacing.xxl * 7
        readonly property real gap: root.spacing.xl
        readonly property real inset: root.spacing.xl
        readonly property real insetY: root.spacing.sm
    }

    readonly property QtObject slider: QtObject {
        readonly property real trackHeight: 8
        readonly property real thumb: 20
    }

    // Horizontal step indicator. The node is the MD3 24dp target; the
    // track is the 2dp stroke so it stays visible between the circles.
    readonly property QtObject stepper: QtObject {
        readonly property real node: root.icon.md
        readonly property real track: root.stroke.focus
    }

    readonly property QtObject session: QtObject {
        readonly property real avatar: root.spacing.xxl * 4
    }

    readonly property QtObject store: QtObject {
        readonly property real heroHeight: root.spacing.xxl * 8
        readonly property real heroIcon: root.icon.lg + root.spacing.md * 2
        readonly property real tile: root.spacing.xxl * 3 + root.spacing.md
        readonly property real tileIcon: root.icon.lg + root.spacing.sm * 2
        readonly property real sectionGap: root.spacing.xl
    }

    function elevationFor(level: int): var {
        const raw = elevation[Math.max(0, Math.min(level, elevation.length - 1))];
        return {
            // Full strength at slider 1 read as a bright veil. The top
            // of the slider now sits near what the middle used to be.
            tintOpacity: Math.min(1, raw.tintOpacity * root.surfaceTint * 0.55),
            shadowOpacity: raw.shadowOpacity,
            shadowRadius: raw.shadowRadius
        };
    }
}
