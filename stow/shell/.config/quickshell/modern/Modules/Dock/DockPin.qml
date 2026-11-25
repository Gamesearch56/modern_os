import QtQuick
import "../../Commons"
import "../../Services"
import "../../Widgets"

Item {
    id: root

    // The repeater only writes this when it is required. A plain property
    // stays 0, so the trash would always remove the first application.
    required property int index
    property string appId: ""
    property bool vertical: false
    property string edge: "bottom"
    property var repeater: null

    readonly property string label: Dock.labelFor(root.appId)
    // A trailing "(Launcher)" is the desktop file's disambiguator, not
    // something that belongs under the icon.
    readonly property string _caption: {
        const cut = root.label.replace(/\s*\([^)]*\)\s*$/, "").trim();
        return cut.length ? cut : root.label;
    }
    readonly property real _icon: DockLayout.iconSize
    // A side dock is an icon column. Captions belong under a top or bottom row.
    readonly property bool _named: DockLayout.showNames && !root._side
    readonly property bool _side: root.edge === "left" || root.edge === "right"
    readonly property real _gap: root._named ? Tokens.spacing.xs : 0
    // Side docks share one caption column. A top or bottom dock stays on
    // the icon column, so a long name cannot widen that application.
    readonly property real _nameLimit: Tokens.spacing.xxl * 4
    readonly property real _nameW: !root._named ? 0 : (root._side ? root._nameLimit : root._icon)
    readonly property real _nameH: root._named ? Typography.style("labelMedium").lineHeight : 0
    readonly property string _hover: DockLayout.hover
    readonly property bool _hot: tipHover.hovered && !Dock.dragActive
    readonly property bool _motion: Motion.scale !== 0 && root._hover !== "none"
    readonly property real _nudge: root._hot && root._hover === "lift" && root._motion ? Tokens.spacing.sm : 0
    readonly property real _scale: {
        if (Motion.scale === 0)
            return 1;
        if (root._pressing)
            return Motion.dockPress;
        if (root._hot && root._motion && (root._hover === "zoom" || root._hover === "bounce"))
            return Motion.dockPop;
        return 1;
    }
    property bool _pressing: false

    signal focused()

    function _scroll(w) {
        let item = root.parent;
        while (item && !item.scrollWheel)
            item = item.parent;
        if (item)
            item.scrollWheel(w);
    }

    function _open() {
        if (root._pressing)
            return;
        if (Motion.shortMs < 1) {
            Dock.launch(root.appId);
            return;
        }
        root._pressing = true;
        clickWait.interval = Motion.shortMs;
        clickWait.restart();
    }

    implicitWidth: Math.round((root._named && root._side ? root._icon + root._gap + root._nameW : root._icon) + Tokens.spacing.sm)
    implicitHeight: Math.round((root._named && !root._side ? root._icon + root._gap + root._nameH : root._icon) + Tokens.spacing.sm)
    opacity: Dock.dragActive && Dock.dragFromDock && Dock.dragIndex === root.index
        ? Tokens.interaction.cut : 1
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.onPressAction: root._open()

    function _peer(delta: int) {
        const rep = root.repeater;
        if (!rep)
            return;
        const next = root.index + delta;
        const item = rep.itemAtIndex ? rep.itemAtIndex(next) : rep.itemAt(next);
        if (item)
            item.forceActiveFocus();
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root._open();
            event.accepted = true;
            return;
        }
        const back = root._side ? event.key === Qt.Key_Up : event.key === Qt.Key_Left;
        const forward = root._side ? event.key === Qt.Key_Down : event.key === Qt.Key_Right;
        if (!back && !forward)
            return;
        root._peer(forward ? 1 : -1);
        event.accepted = true;
    }

    onActiveFocusChanged: {
        if (activeFocus)
            root.focused();
    }

    Item {
        id: iconBox
        width: root._icon
        height: root._icon
        x: {
            const nudge = root.edge === "left" ? root._nudge : root.edge === "right" ? -root._nudge : 0;
            const raw = !root._named || !root._side
                ? (root.width - root._icon) / 2 + nudge
                : (root.edge === "right"
                    ? root.width - Tokens.spacing.xs - root._icon : Tokens.spacing.xs) + nudge;
            return Math.round(raw);
        }
        y: {
            const base = root._side || !root._named
                ? (root.height - root._icon) / 2
                : (root.height - root._icon - root._gap - root._nameH) / 2;
            const nudge = root.edge === "bottom" ? -root._nudge : root.edge === "top" ? root._nudge : 0;
            return Math.round(base + nudge);
        }
        transform: Scale {
            origin.x: iconBox.width / 2
            origin.y: iconBox.height / 2
            xScale: root._scale
            yScale: root._scale
            Behavior on xScale {
                SpringAnimation {
                    spring: root._hover === "bounce" ? Motion.springBouncy.spring : Motion.springSnappy.spring
                    damping: root._hover === "bounce" ? Motion.springBouncy.damping : Motion.springGentle.damping
                }
            }
            Behavior on yScale {
                SpringAnimation {
                    spring: root._hover === "bounce" ? Motion.springBouncy.spring : Motion.springSnappy.spring
                    damping: root._hover === "bounce" ? Motion.springBouncy.damping : Motion.springGentle.damping
                }
            }
        }
        Behavior on x {
            NumberAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingEmphasized
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingEmphasized
            }
        }

        Rectangle {
            visible: DockLayout.theme === "inventory"
            anchors.fill: parent
            anchors.margins: -Tokens.spacing.xs
            radius: Tokens.radius.small
            color: Colors.color.surfaceContainerHigh
        }

        MIcon {
            id: glyph
            anchors.centerIn: parent
            name: Dock.iconFor(root.appId)
            size: root._icon
            tint: false
            preferSymbolic: false
            // The spring scales this texture. It has to be the icon's
            // 2x pixmap, or the zoom enlarges a resting-size picture.
            layer.enabled: root._hover === "zoom" || root._hover === "bounce"
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(glyph._raster, glyph._raster)
        }
        Rectangle {
            anchors.fill: parent
            radius: Tokens.radius.medium
            color: Colors.color.primary
            opacity: {
                if (root._hover !== "color" || Motion.scale === 0)
                    return 0;
                if (root._pressing)
                    return Tokens.interaction.cut;
                if (root._hot)
                    return Tokens.interaction.band;
                return 0;
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.shortMs
                    easing.bezierCurve: Motion.easingStandard
                }
            }
        }

        Rectangle {
            visible: DockLayout.theme === "beam"
            z: 2
            radius: Tokens.radius.full
            color: Colors.color.primary
            width: root._side ? Tokens.stroke.focus * 2 : root._icon * 0.6
            height: root._side ? root._icon * 0.6 : Tokens.stroke.focus * 2
            x: root.edge === "left" ? Tokens.spacing.xxs
                : (root.edge === "right" ? parent.width - width - Tokens.spacing.xxs : (parent.width - width) / 2)
            y: root.edge === "top" ? Tokens.spacing.xxs
                : (root.edge === "bottom" ? parent.height - height - Tokens.spacing.xxs : (parent.height - height) / 2)
        }
    }

    Timer {
        id: clickWait
        repeat: false
        onTriggered: {
            root._pressing = false;
            Dock.launch(root.appId);
        }
    }

    MText {
        id: nameText
        visible: root._named
        value: root._caption
        // QtRendering keeps one texture and slides it when a pin moves.
        // On this HDR panel that slide turns the gray edge into color,
        // and the screenshot stores the gray pixel so the fringe is missing.
        // NativeRendering paints the glyphs again at the pixel they land on.
        styleName: "labelMedium"
        font.letterSpacing: 0
        font.kerning: false
        font.hintingPreference: Font.PreferFullHinting
        renderType: Text.NativeRendering
        color: Colors.color.onSurface
        width: root._nameW
        height: root._nameH
        horizontalAlignment: root._side ? Text.AlignLeft : Text.AlignHCenter
        elide: Text.ElideRight
        Accessible.ignored: true
        x: {
            const raw = !root._side ? (root.width - root._nameW) / 2
                : (root.edge === "right" ? iconBox.x - root._gap - root._nameW
                    : iconBox.x + root._icon + root._gap);
            return Math.round(raw);
        }
        y: Math.round(root._side ? (root.height - root._nameH) / 2 : iconBox.y + root._icon + root._gap)
    }

    MDragArea {
        anchors.fill: parent
        // Locked until the launcher is open, so a click still launches.
        canDrag: Launcher.open
        onTapped: root._open()
        onWheel: (w) => root._scroll(w)
        onDragBegan: (x, y) => {
            const p = Dock.pointerToScreen(root, root.edge, x, y);
            const screen = root.Window.window && root.Window.window.screen ? root.Window.window.screen.name : "";
            Dock.beginDrag(root.appId, true, root.index, p.x, p.y, screen);
        }
        onDragMoved: (x, y) => {
            const p = Dock.pointerToScreen(root, root.edge, x, y);
            Dock.moveDrag(p.x, p.y);
        }
        onDragDropped: (x, y) => {
            const p = Dock.pointerToScreen(root, root.edge, x, y);
            Dock.moveDrag(p.x, p.y);
            Dock.finish();
        }
        onDragCanceled: Dock.cancel()
    }

    HoverHandler {
        id: tipHover
    }
}
