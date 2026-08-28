// The only place duration/easing/spring numbers exist — see
// docs/MOTION.md for the full motion system this implements and the
// Hyprland-side mirror (stow/hypr/.config/hypr/modules/motion_tokens.lua
// + modules/animations.lua). Nothing else in the codebase should contain
// a literal millisecond value or bezier curve; scripts/lint-layers.sh
// greps for that and fails the build on a hit.
pragma Singleton

import Quickshell

Singleton {
    id: root

    // Raw MD3 control points, kept in sync BY HAND with
    // modules/motion_tokens.lua's `bezier` table (a build step was judged
    // more complexity than the drift risk, since these change rarely —
    // see docs/DECISIONS.md). Verified against the Material 3 motion
    // spec during development.
    readonly property var curveEmphasized: [0.2, 0.0, 0.0, 1.0]
    readonly property var curveEmphasizedDecelerate: [0.05, 0.7, 0.1, 1.0]
    readonly property var curveEmphasizedAccelerate: [0.3, 0.0, 0.8, 0.15]
    readonly property var curveStandard: [0.2, 0.0, 0.0, 1.0]

    // Ready to assign directly to `easing.bezierCurve` — QML's
    // BezierSpline format is [cx1, cy1, cx2, cy2, endX, endY, ...] and
    // must end at (1, 1); modules/motion_tokens.lua only needs the 4 raw
    // control-point numbers above, which is why they're kept separate.
    readonly property var easingEmphasized: curveEmphasized.concat([1.0, 1.0])
    readonly property var easingEmphasizedDecelerate: curveEmphasizedDecelerate.concat([1.0, 1.0])
    readonly property var easingEmphasizedAccelerate: curveEmphasizedAccelerate.concat([1.0, 1.0])
    readonly property var easingStandard: curveStandard.concat([1.0, 1.0])

    readonly property int durationShort: 100
    readonly property int durationMedium: 250
    readonly property int durationLong: 400
    readonly property int durationExtraLong: 600

    readonly property real scale: Config.motion.scale ?? 1.0 // 0 = off (accessibility/slow machine), 1.5 = slow-mo for demos

    // Always read duration through these, never the raw duration*
    // properties directly, so `config.json`'s motion.scale always applies.
    function short(): int { return Math.round(durationShort * root.scale); }
    function medium(): int { return Math.round(durationMedium * root.scale); }
    function long(): int { return Math.round(durationLong * root.scale); }
    function extraLong(): int { return Math.round(durationExtraLong * root.scale); }

    // Named SpringAnimation presets — real QML SpringAnimation property
    // names are `spring` (stiffness) and `damping` (0-1, lower = faster
    // settle), not the stiffness/tension naming other motion libraries
    // use. Starting points, not final — tune by eye once the shell
    // actually renders on screen. Usage:
    //   Behavior on scale { SpringAnimation { spring: Motion.springSnappy.spring; damping: Motion.springSnappy.damping } }
    readonly property var springSnappy: ({ spring: 3.5, damping: 0.4 })
    readonly property var springGentle: ({ spring: 2.2, damping: 0.5 })
    readonly property var springBouncy: ({ spring: 4.0, damping: 0.25 })
}
