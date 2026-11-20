// Live MD3 palette from tokens.json. Wallpaper / theme-apply rewrite
// that file; FileView picks it up without restarting Quickshell.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    property string mode: "dark"
    property string sourceColor: "#8020e6"
    property var color: ({
        primary: "#74d7ca",
        onPrimary: "#003732",
        primaryContainer: "#005049",
        onPrimaryContainer: "#91f4e6",
        secondary: "#ecb8ce",
        onSecondary: "#482536",
        secondaryContainer: "#613b4d",
        onSecondaryContainer: "#ffd8e7",
        tertiary: "#e7b7e8",
        onTertiary: "#46234a",
        tertiaryContainer: "#5e3962",
        onTertiaryContainer: "#ffd5ff",
        error: "#ffb4ab",
        onError: "#690005",
        errorContainer: "#93000a",
        onErrorContainer: "#ffdad6",
        background: "#171118",
        onBackground: "#ebdfe9",
        surface: "#171118",
        onSurface: "#ebdfe9",
        surfaceVariant: "#4e4350",
        onSurfaceVariant: "#d2c2d2",
        surfaceDim: "#171118",
        surfaceBright: "#3e373f",
        surfaceContainerLowest: "#120c13",
        surfaceContainerLow: "#201a21",
        surfaceContainer: "#241d25",
        surfaceContainerHigh: "#2f282f",
        surfaceContainerHighest: "#3a323a",
        outline: "#9b8c9b",
        outlineVariant: "#4e4350",
        inverseSurface: "#ebdfe9",
        inverseOnSurface: "#352e36",
        inversePrimary: "#006a61",
        shadow: "#000000",
        scrim: "#000000"
    })

    // Fit marks stay green, orange, and red when the wallpaper changes.
    readonly property color fitGood: "#3DDC84"
    readonly property color fitMaybe: "#F5A524"
    readonly property color fitPoor: "#E5484D"

    // Palette generation often finishes while awww is still cropping.
    // Hold the new tokens until that crop's transition is on screen,
    // then move the colors across the same duration.
    property int transitionGen: 0
    property bool _hold: false
    property bool _window: false
    property bool _ended: false
    property string _pending: ""
    property string _markSeen: ""
    property double _startedAt: 0
    property int _windowMs: 0
    property real blend: 1
    property var _from: ({})
    property var _to: ({})

    FileView {
        id: file
        path: root.home + "/.config/modern/tokens.json"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            Qt.callLater(() => file.reload());
        }
        onLoaded: root._apply(text())
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound)
                Qt.callLater(() => file.reload());
        }
    }

    // The mark file is created by wallpaper-show when the transition
    // starts. Until that file exists there is nothing to watch.
    FileView {
        id: markFile
        path: Paths.stateHome + "/modern/wallpaper-transition"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._onMark(text())
    }

    Timer {
        interval: Motion.fileSettleMs
        repeat: true
        running: root._hold
        onTriggered: markFile.reload()
    }

    Timer {
        id: armTimer
        interval: Motion.followWatchMs
        repeat: false
        onTriggered: {
            if (!root._hold || root._window)
                return;
            root._ended = true;
            root._releasePending();
        }
    }

    NumberAnimation {
        id: blendAnim
        target: root
        property: "blend"
        from: 0
        to: 1
        easing.type: Easing.Linear
        onFinished: {
            if (root._pending.length > 0)
                root._releasePending();
        }
    }

    onBlendChanged: {
        if (blendAnim.running)
            root._paintBlend();
    }

    function refresh() {
        file.reload();
    }

    function armForWallpaper() {
        blendAnim.stop();
        root.transitionGen += 1;
        root._hold = true;
        root._window = false;
        root._ended = false;
        root._pending = "";
        root._markSeen = "";
        root._startedAt = 0;
        root._windowMs = 0;
        armTimer.restart();
        markFile.reload();
    }

    function _apply(raw: string) {
        if (!root._hold) {
            root._commit(raw);
            return;
        }
        // tokens.json is re-read twice as it lands. A second copy of the
        // same palette must not restart the crossfade.
        if (raw === root._pending && (blendAnim.running || !root._window))
            return;
        root._pending = raw;
        if (root._ended)
            root._releasePending();
        else if (root._window)
            root._begin(root._remaining());
    }

    function _onMark(raw: string) {
        if (!root._hold)
            return;
        const text = String(raw || "");
        if (text === root._markSeen)
            return;
        root._markSeen = text;
        const parts = text.trim().split(/\s+/);
        if (parts.length < 3 || parts[2] !== String(root.transitionGen))
            return;
        if (parts[0] === "start") {
            armTimer.stop();
            root._window = true;
            root._ended = false;
            root._windowMs = Math.max(0, Math.round(parseFloat(parts[1] || "0") * 1000));
            root._startedAt = Date.now();
            if (root._pending.length > 0)
                root._begin(root._windowMs);
            return;
        }
        if (parts[0] !== "done")
            return;
        root._window = false;
        root._ended = true;
        if (blendAnim.running) {
            blendAnim.stop();
            root.blend = 1;
            root._paintBlend();
        }
        root._releasePending();
    }

    function _remaining(): int {
        if (root._startedAt <= 0)
            return root._windowMs;
        return Math.max(0, root._windowMs - (Date.now() - root._startedAt));
    }

    function _begin(ms: int) {
        const parsed = root._parse(root._pending);
        if (!parsed)
            return;
        root._from = root.color;
        root._to = parsed.color;
        if (parsed.mode.length > 0)
            root.mode = parsed.mode;
        if (parsed.source.length > 0)
            root.sourceColor = parsed.source;
        if (ms <= 16 || Motion.scale === 0) {
            root._releasePending();
            return;
        }
        blendAnim.duration = ms;
        blendAnim.restart();
    }

    function _paintBlend() {
        const t = root.blend;
        const next = {};
        const dst = root._to || ({});
        const src = root._from || ({});
        for (const k in dst)
            next[k] = root._mix(src[k] || dst[k], dst[k], t);
        root.color = next;
    }

    function _releasePending() {
        const raw = root._pending;
        root._pending = "";
        root._hold = false;
        root._window = false;
        root._ended = false;
        armTimer.stop();
        blendAnim.stop();
        if (raw.length > 0)
            root._commit(raw);
    }

    function _parse(raw: string): var {
        try {
            const j = JSON.parse(raw);
            const next = {};
            const src = (j.color && typeof j.color === "object") ? j.color : {};
            for (const k in src)
                next[k] = src[k];
            return {
                mode: j.mode ? String(j.mode) : "",
                source: j.sourceColor ? String(j.sourceColor) : "",
                color: next
            };
        } catch (e) {
            return null;
        }
    }

    function _commit(raw: string) {
        const parsed = root._parse(raw);
        if (!parsed)
            return;
        if (parsed.mode.length > 0)
            root.mode = parsed.mode;
        if (parsed.source.length > 0)
            root.sourceColor = parsed.source;
        root.color = parsed.color;
    }

    function _mix(a, b, t) {
        const ca = Qt.color(String(a));
        const cb = Qt.color(String(b));
        const u = Math.max(0, Math.min(1, t));
        return Qt.rgba(
            ca.r + (cb.r - ca.r) * u,
            ca.g + (cb.g - ca.g) * u,
            ca.b + (cb.b - ca.b) * u,
            1
        );
    }
}
