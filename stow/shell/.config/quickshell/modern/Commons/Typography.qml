// MD3 type scale + font family tokens. See docs/DESIGN.md's
// "Typography" section. Never a hardcoded family string or font size —
// always `Typography.family.*` / `Typography.style(name)`, sourced from
// `config.json`'s `typography` block (`Commons/Config.qml`).
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property real scale: Config.typography.scale ?? 1.0

    readonly property QtObject family: QtObject {
        readonly property string ui: Config.typography.ui ?? "Inter"
        readonly property string document: Config.typography.document ?? "Inter"
        readonly property string monospace: Config.typography.monospace ?? "JetBrainsMono Nerd Font"
    }

    // MD3 type scale reference values (px @ scale 1.0) — size,
    // lineHeight, weight, tracking (letter-spacing, px). Verified
    // against the official M3 type-scale-tokens spec during development.
    readonly property var _scale: ({
        displayLarge: { size: 57, lineHeight: 64, weight: 400, tracking: -0.25 },
        displayMedium: { size: 45, lineHeight: 52, weight: 400, tracking: 0 },
        displaySmall: { size: 36, lineHeight: 44, weight: 400, tracking: 0 },
        headlineLarge: { size: 32, lineHeight: 40, weight: 400, tracking: 0 },
        headlineMedium: { size: 28, lineHeight: 36, weight: 400, tracking: 0 },
        headlineSmall: { size: 24, lineHeight: 32, weight: 400, tracking: 0 },
        titleLarge: { size: 22, lineHeight: 28, weight: 500, tracking: 0 },
        titleMedium: { size: 16, lineHeight: 24, weight: 500, tracking: 0.15 },
        titleSmall: { size: 14, lineHeight: 20, weight: 500, tracking: 0.1 },
        bodyLarge: { size: 16, lineHeight: 24, weight: 400, tracking: 0.5 },
        bodyMedium: { size: 14, lineHeight: 20, weight: 400, tracking: 0.25 },
        bodySmall: { size: 12, lineHeight: 16, weight: 400, tracking: 0.4 },
        labelLarge: { size: 14, lineHeight: 20, weight: 500, tracking: 0.1 },
        labelMedium: { size: 12, lineHeight: 16, weight: 500, tracking: 0.5 },
        labelSmall: { size: 11, lineHeight: 16, weight: 500, tracking: 0.5 }
    })

    // Returns { pixelSize, lineHeight, weight, letterSpacing } scaled by
    // config.json's typography.scale (0.8-1.4), ready to spread onto a
    // Text's font.*/lineHeight properties:
    //   font.pixelSize: Typography.style("titleLarge").pixelSize
    //   font.weight: Typography.style("titleLarge").weight
    // MText (Widgets/MText.qml) wraps this so most call sites never call
    // it directly.
    function style(name: string): var {
        const base = root._scale[name];
        if (!base) {
            console.warn(`Typography.style: unknown style "${name}"`);
            return root._scale.bodyMedium;
        }
        return {
            pixelSize: Math.round(base.size * root.scale),
            lineHeight: Math.round(base.lineHeight * root.scale),
            weight: base.weight,
            letterSpacing: base.tracking * root.scale
        };
    }
}
