import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Services"

PanelWindow {
    id: root

    readonly property bool vertical: DockLayout.vertical
    readonly property string _edge: DockLayout.position
    readonly property bool _auto: DockLayout.autoHide
    readonly property bool _cover: Hypr.focusedFullscreen
    readonly property bool _hold: Launcher.open
    readonly property bool _shown: DockLayout.enabled && !root._cover && (!root._auto || root._peek || root._hold)
    readonly property real _full: DockLayout.cross
    // Wide enough that the pointer can catch a tucked-away dock.
    readonly property real _hot: Tokens.spacing.lg
    readonly property bool _edgeOnly: root._auto && !root._shown && !root._slidingOut
    readonly property string _screenKey: root.screen ? String(root.screen.name) : ""

    property bool _peek: false
    property bool _slidingOut: false
    property real _slide: 0
    // Off until the saved auto-hide choice is known, so a hidden strip
    // starts hidden instead of sliding away after the shell starts.
    property bool _settled: false
    readonly property bool _loaded: Config.loaded

    // The launcher is a full-screen overlay. Stay above it so a pin can
    // be grabbed, but give the pointer back while a launcher drag is
    // crossing the strip — otherwise that drag is cancelled on the way in.
    // None of that applies while the dock itself is off.
    WlrLayershell.layer: DockLayout.enabled && (Launcher.open || Dock.dragActive) ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "modern-dock"
    // aboveWindows false forces the bottom layer, under every window.
    // Auto-hide then reveals into a strip the windows already cover.
    aboveWindows: DockLayout.enabled
    readonly property bool _yield: Dock.dragActive && !Dock.dragFromDock
    mask: Region {
        x: root._edgeOnly && root._edge === "right" ? Math.max(0, root._full - root._hot) : 0
        y: root._edgeOnly && root._edge === "bottom" ? Math.max(0, root._full - root._hot) : 0
        width: root._yield ? 0 : (root.vertical
            ? (root._edgeOnly ? root._hot : root._full)
            : Math.max(root.width, root.screen ? root.screen.width : 0))
        height: root._yield ? 0 : (root.vertical
            ? Math.max(root.height, root.screen ? root.screen.height : 0)
            : (root._edgeOnly ? root._hot : root._full))
    }

    anchors.top: root._edge !== "bottom"
    anchors.bottom: root._edge !== "top"
    anchors.left: root._edge !== "right"
    anchors.right: root._edge !== "left"
    // Stay full size while tucked away. Shrinking the surface to a hairline
    // drops the pointer and the dock never comes back.
    implicitHeight: root.vertical ? 0 : root._full
    implicitWidth: root.vertical ? root._full : 0
    // Normal remembers the last number. A reload commits the schema
    // default, and a later 0 is never sent. Ignore is a different mode,
    // so the compositor actually drops the strip.
    readonly property bool _reserve: DockLayout.enabled && !root._cover && !root._auto
    readonly property real _zone: root._reserve ? DockLayout.exclusive : 0
    function _applyZone() {
        if (!root._reserve) {
            root.exclusionMode = ExclusionMode.Ignore;
            return;
        }
        root.exclusionMode = ExclusionMode.Ignore;
        root.exclusiveZone = Math.round(Math.max(0, root._zone));
    }
    on_ZoneChanged: Qt.callLater(root._applyZone)
    visible: Config.loaded && DockLayout.enabled && !root._cover
    color: "transparent"
    // Stay focusable while the launcher is open. Turning keyboard
    // interactivity off here destroys the grab and Super+Space closes it.
    focusable: DockLayout.enabled && (Launcher.open || !Dock.dragActive)

    Behavior on _slide {
        enabled: root._settled
        NumberAnimation {
            duration: Motion.extraLongMs
            easing.bezierCurve: Motion.easingEmphasizedDecelerate
        }
    }

    on_ShownChanged: {
        if (root._shown) {
            hideSettle.stop();
            root._slidingOut = false;
            root._slide = 0;
        } else {
            root._slidingOut = true;
            root._slide = 1;
            hideSettle.restart();
        }
    }
    on_AutoChanged: {
        if (!root._auto) {
            hideTimer.stop();
            hideSettle.stop();
            root._peek = false;
            root._slidingOut = false;
            root._slide = 0;
        } else if (hover.hovered || root._hold) {
            hideTimer.stop();
            root._peek = true;
        } else
            root._peek = false;
    }
    on_HoldChanged: {
        if (root._hold) {
            hideTimer.stop();
            root._peek = true;
        } else if (root._auto && !hover.hovered)
            hideTimer.restart();
    }

    Component.onCompleted: {
        Popups.registerDock(root);
        if (!root._shown)
            root._slide = 1;
        Qt.callLater(root._applyZone);
        if (root._loaded)
            root._settle();
    }
    on_LoadedChanged: if (root._loaded) Qt.callLater(root._settle)
    function _settle() {
        root._slidingOut = false;
        root._slide = root._shown ? 0 : 1;
        root._settled = true;
    }
    Component.onDestruction: Popups.unregisterDock(root)

    function _inBand(x: real, y: real): bool {
        const s = root.screen;
        if (!s)
            return false;
        const slop = Tokens.spacing.xl;
        const band = root._full;
        if (root._edge === "bottom")
            return y >= s.height - band - slop && y <= s.height + slop && x >= -slop && x <= s.width + slop;
        if (root._edge === "top")
            return y >= -slop && y <= band + slop && x >= -slop && x <= s.width + slop;
        if (root._edge === "left")
            return x >= -slop && x <= band + slop && y >= -slop && y <= s.height + slop;
        return x >= s.width - band - slop && x <= s.width + slop && y >= -slop && y <= s.height + slop;
    }

    // Drag coordinates are compositor-global when the source window
    // knows its screen, and screen-local when it does not. Either one
    // that lands in this strip is the pointer.
    function _screenLocal(): var {
        const o = Dock.screenOrigin(root.screen);
        const global = Qt.point(Dock.dragX - o.x, Dock.dragY - o.y);
        if (root._inBand(global.x, global.y))
            return global;
        if (root._inBand(Dock.dragX, Dock.dragY))
            return Qt.point(Dock.dragX, Dock.dragY);
        return null;
    }

    function _windowPoint(local: point): point {
        const s = root.screen;
        const band = root._full;
        if (!s)
            return local;
        if (root._edge === "bottom")
            return Qt.point(local.x, local.y - (s.height - band));
        if (root._edge === "right")
            return Qt.point(local.x - (s.width - band), local.y);
        return local;
    }

    function _syncHit() {
        const key = root._screenKey;
        if (!Dock.dragActive || !root.visible || (Dock.dragScreen.length > 0 && Dock.dragScreen !== key)) {
            Dock.clearRow(key);
            Dock.clearTrash(key);
            return;
        }
        const local = root._screenLocal();
        if (!local) {
            Dock.clearRow(key);
            Dock.clearTrash(key);
            return;
        }
        const w = root._windowPoint(local);
        const along = scroller.mapFromItem(surface, w.x, w.y);
        scroller.track(along.x, along.y);
        const at = scroller.mapPoint(surface, w.x, w.y);
        if (scroller.trashContains(at.x, at.y)) {
            Dock.claim(key, "trash", -1);
            return;
        }
        Dock.clearTrash(key);
        Dock.claim(key, "row", scroller.indexAt(at.x, at.y));
    }

    Connections {
        target: Dock
        function onDragXChanged() { root._syncHit(); }
        function onDragYChanged() { root._syncHit(); }
        function onDragActiveChanged() { root._syncHit(); }
    }

    Timer {
        id: hideTimer
        interval: Math.max(Motion.mediumMs, 1)
        onTriggered: {
            if (!root._auto || root._hold || hover.hovered)
                return;
            root._peek = false;
        }
    }
    Timer {
        id: hideSettle
        interval: Math.max(Motion.extraLongMs, 1)
        onTriggered: {
            if (!root._shown)
                root._slidingOut = false;
        }
    }

    Item {
        id: surface
        anchors.fill: parent

        Rectangle { anchors.fill: parent; z: -1; visible: Chrome.softwareGpu; color: Colors.color.surface; opacity: Chrome.washOpacity }

        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop();
                    root._peek = true;
                } else if (root._auto && !root._hold) {
                    hideTimer.restart();
                }
            }
        }

        Item {
            id: chrome
            width: parent.width
            height: parent.height
            x: root.vertical ? root._slide * (root._edge === "right" ? root._full : -root._full) : 0
            y: root.vertical ? 0 : root._slide * (root._edge === "bottom" ? root._full : -root._full)

            FocusScope {
                id: scope
                anchors.fill: parent

                DockScroller {
                    id: scroller
                    anchors.fill: parent
                    // A side column otherwise runs into the screen edge.
                    // The same gap windows use, above the first icon and below the last.
                    anchors.topMargin: root.vertical ? DockLayout.screenGap : 0
                    anchors.bottomMargin: root.vertical ? DockLayout.screenGap : 0
                    vertical: root.vertical
                    screenName: root._screenKey
                    onPinFocused: {
                        hideTimer.stop();
                        root._peek = true;
                    }
                }

                // The gaps between pins and the screen margins scroll too; a
                // pin forwards its own wheel. A MouseArea on top would force
                // its arrow cursor over the pins' hand.
                WheelHandler {
                    target: null
                    onWheel: (event) => scroller.scrollWheel(event)
                }

                onActiveFocusChanged: {
                    if (activeFocus) {
                        hideTimer.stop();
                        root._peek = true;
                    } else if (root._auto && !hover.hovered) {
                        hideTimer.restart();
                    }
                }
            }
        }

        LaunchBusy { anchors.fill: parent }
    }
}
