// SUPER+Tab and the three-finger swipe share one reveal amount.
// Hyprland's gesture callbacks write `modernoverview,…` on the event
// socket; a finished swipe cannot follow the fingers, so this listens
// to the live delta instead of an open/hide command.
pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property real progress: 0
    property bool tracking: false
    property int settleMs: Motion.mediumMs
    property var screen: null
    readonly property bool open: root.progress > 0 || root.tracking

    property real _base: 0
    property real _velocity: 0

    function present() { root._go(1); }
    function dismiss() { root._go(0); }
    function show() { root.present(); }
    function hide() { root.dismiss(); }
    function toggle() { root._go(root.progress < 0.5 ? 1 : 0); }

    function _go(target: real) {
        if (root.tracking)
            return;
        root._rememberScreen();
        root.settleMs = Motion.mediumMs;
        root.progress = target;
    }

    function _travel(): real {
        return Math.max(1, Tokens.overview.swipeTravel);
    }

    function _rememberScreen() {
        if (root.screen)
            return;
        const name = Hypr.focusedMonitorName();
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name) {
                root.screen = screens[i];
                return;
            }
        }
        root.screen = screens.length ? screens[0] : null;
    }

    function _body(event: var): string {
        if (!event)
            return "";
        const marker = "modernoverview";
        const data = String(event.data || "");
        const name = String(event.name || "");
        if (data.indexOf(marker) === 0)
            return data.slice(marker.length + 1);
        if (name.indexOf(marker) === 0)
            return name.slice(marker.length + 1);
        return "";
    }

    // velocity is finger pixels per second, positive when the fingers move up.
    function _settleFor(velocity: real) {
        const perShort = Math.abs(velocity) * Motion.shortMs / 1000;
        const rate = Math.min(1, perShort / root._travel());
        const span = Math.max(0, Motion.mediumMs - Motion.shortMs);
        root.settleMs = Math.round(Motion.mediumMs - span * rate);
    }

    function _finish(cancelled: bool, velocity: real) {
        root._velocity = velocity;
        const coast = (velocity / 1000) * Motion.mediumMs / root._travel();
        const projected = cancelled ? root._base : root.progress + coast;
        root._settleFor(cancelled ? 0 : velocity);
        root.tracking = false;
        root.progress = projected >= 0.5 ? 1 : 0;
    }

    function _gesture(event) {
        const body = root._body(event);
        if (!body.length)
            return;
        const parts = body.split(",");
        const kind = parts[0];
        if (kind === "begin") {
            root._rememberScreen();
            root._base = root.progress;
            root._velocity = 0;
            root.tracking = true;
            return;
        }
        if (kind === "move") {
            const traveled = Number(parts[1]) || 0;
            root._velocity = Number(parts[2]) || 0;
            root.progress = Math.max(0, Math.min(1, root._base + traveled / root._travel()));
            return;
        }
        if (kind === "end")
            root._finish(parts[1] === "1", Number(parts[2]) || root._velocity);
    }

    onProgressChanged: {
        if (root.progress <= 0 && !root.tracking)
            root.screen = null;
    }

    Behavior on progress {
        enabled: !root.tracking && Motion.scale !== 0
        NumberAnimation {
            duration: root.settleMs
            easing.bezierCurve: Motion.easingEmphasizedDecelerate
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) { root._gesture(event); }
    }

    IpcHandler {
        target: "overview"
        function toggle() { root.toggle(); }
        function show() { root.show(); }
        // `qs ipc call overview show` is read as qs's own `show` command
        // (it lists the target); callers use open.
        function open() { root.show(); }
        function hide() { root.hide(); }
    }
}
