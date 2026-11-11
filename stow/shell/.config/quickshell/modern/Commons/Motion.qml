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
    readonly property int durationConfigWrite: 200
    // Store load-more footer — wall clock so the bar is readable.
    readonly property int durationStorePage: 1000
    // Wall-clock hide for recording chrome — not MD3 motion, never scaled.
    readonly property int durationRecordingChrome: 3000
    // NetworkManager wifi rescan — not MD3 motion, never scaled.
    readonly property int durationWifiScan: 8000
    // BlueZ inquiry restart — not MD3 motion, never scaled.
    readonly property int durationBluetoothScan: 8000
    // Finished update stays on screen at 100% before the shell restarts.
    readonly property int durationUpdateSettle: 2500
    // After the link is up, before the one login update check. Wall clock.
    readonly property int durationBootSettle: 12000
    // Re-read of a file another process is still rewriting — never scaled.
    readonly property int durationFileSettle: 400
    // Overlays fade out before a problem report's screenshots — wall clock.
    readonly property int durationReportCapture: 350
    // External process watchdog (ddcutil / hyprctl / theme-apply) — wall clock.
    readonly property int durationProcessWatch: 20000
    readonly property int durationFollowWatch: 30000

    readonly property real scale: Config.motion.scale ?? 1.0 // 0 = off (accessibility/slow machine), 1.5 = slow-mo for demos
    readonly property string overlay: Config.motion.overlay ?? "fadeZoom"

    // Bindable scaled durations — `duration: Motion.short()` does not
    // re-evaluate when scale changes; `Motion.shortMs` does.
    readonly property int shortMs: Math.round(durationShort * root.scale)
    readonly property int mediumMs: Math.round(durationMedium * root.scale)
    readonly property int longMs: Math.round(durationLong * root.scale)
    readonly property int extraLongMs: Math.round(durationExtraLong * root.scale)
    readonly property int configWriteMs: Math.round(durationConfigWrite * (root.scale === 0 ? 1 : root.scale))
    readonly property int storePageMs: root.durationStorePage
    readonly property int recordingChromeMs: root.durationRecordingChrome
    readonly property int wifiScanMs: root.durationWifiScan
    readonly property int bluetoothScanMs: root.durationBluetoothScan
    readonly property int updateSettleMs: root.durationUpdateSettle
    readonly property int bootSettleMs: root.durationBootSettle
    readonly property int fileSettleMs: root.durationFileSettle
    readonly property int processWatchMs: root.durationProcessWatch
    readonly property int reportCaptureMs: root.durationReportCapture
    readonly property int followWatchMs: root.durationFollowWatch
    readonly property bool overlaysFade: root.scale !== 0 && root.overlay !== "zoom"
    readonly property bool overlaysZoom: root.scale !== 0 && root.overlay !== "fade"

    // Always read duration through these, never the raw duration*
    // properties directly, so `config.json`'s motion.scale always applies.
    function short(): int { return root.shortMs; }
    function medium(): int { return root.mediumMs; }
    function long(): int { return root.longMs; }
    function extraLong(): int { return root.extraLongMs; }

    // Overlay enter/exit — Modules/Widgets call these instead of
    // branching on motion.overlay. scale 0 is instant (opacity stays
    // 1 while open; the loader unmounts on close).
    function overlayOpacity(open: bool): real {
        return open ? 1 : 0;
    }

    function overlayScale(open: bool): real {
        if (root.scale === 0 || root.overlay === "fade")
            return 1;
        return open ? 1 : 0.92;
    }

    function overlayFades(): bool {
        return root.overlaysFade;
    }

    function overlayZooms(): bool {
        return root.overlaysZoom;
    }

    // Inverse of the closed overlay scale (~0.92 → ~1.087). Search
    // fields use this as a focused bump so motion.overlay still owns
    // the number; fade-only / scale-0 stays at 1.
    function overlayFocusScale(): real {
        const closed = root.overlayScale(false);
        return closed > 0 ? 1 / closed : 1;
    }

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
