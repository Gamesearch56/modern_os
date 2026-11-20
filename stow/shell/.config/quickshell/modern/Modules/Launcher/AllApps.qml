// The full app grid is a wide card. Its bottom arrow meets the button,
// and the card stays centered on that button. Reparenting onto the
// launcher overlay keeps it wider than the results column.
import QtQuick
import "../../Commons"
import "../../Widgets"

Item {
    id: root

    property bool open: false
    property bool armed: false
    property var model: []
    property int currentIndex: 0
    property bool showIcons: true
    property Item host: null

    signal toggled()
    signal activated(int index)
    signal retreated()

    readonly property int _count: root.model ? root.model.length : 0
    readonly property real _arrowW: Tokens.spacing.xxl
    readonly property real _arrowH: Tokens.spacing.lg
    readonly property real _cellW: Tokens.spacing.xxl * 4
    readonly property real _cellH: Tokens.spacing.xxl * 3 + Tokens.spacing.sm
    readonly property int columns: 8
    readonly property int _rows: 8
    readonly property real _pad: Tokens.spacing.md
    readonly property real _arrowGap: Tokens.spacing.sm
    readonly property Item _wrap: root.parent ? root.parent.parent : null
    // Follow the button, including the launcher's open animation.
    readonly property real _buttonTop: {
        void root.y;
        void (root.parent ? root.parent.y : 0);
        void (root._wrap ? root._wrap.y : 0);
        void (root._wrap ? root._wrap.scale : 1);
        void button.height;
        if (!root.host)
            return 0;
        return button.mapToItem(root.host, 0, 0).y;
    }
    readonly property real _buttonMid: {
        void root._buttonTop;
        void button.width;
        if (!root.host)
            return 0;
        return button.mapToItem(root.host, button.width / 2, 0).x;
    }

    implicitWidth: button.size
    implicitHeight: button.size

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surface
        opacity: Chrome.washOpacity
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: "transparent"
        border.color: Colors.color.outlineVariant
        border.width: Tokens.stroke.hairline
    }

    function step(dx: int, dy: int): int {
        const n = root._count;
        if (n === 0)
            return 0;
        const cols = Math.max(1, root.columns);
        let i = Math.max(0, Math.min(root.currentIndex, n - 1));
        if (dx < 0 && (i % cols) > 0)
            i -= 1;
        else if (dx > 0 && (i % cols) < cols - 1 && i + 1 < n)
            i += 1;
        if (dy < 0 && i >= cols)
            i -= cols;
        else if (dy > 0 && i + cols < n)
            i += cols;
        return i;
    }

    MIconButton {
        id: button
        anchors.centerIn: parent
        size: Tokens.spacing.xxl * 2 * 0.8 - 2
        iconSize: Tokens.icon.lg * 0.8 - 2
        iconName: "view-app-grid-symbolic"
        key: "launcher.allApps"
        tip: !root.open
        tipEdge: "bottom"
        checked: root.open
        highlighted: root.armed && !root.open
        glyphColor: root.open ? Chrome.tonal.fg : Colors.color.onSurface
        onClicked: root.toggled()
        Keys.onUpPressed: (event) => {
            root.retreated();
            event.accepted = true;
        }
    }

    Item {
        id: pop
        parent: root.host || root
        z: 8
        width: root.columns * root._cellW + root._pad * 2
        height: {
            const wanted = root._pad * 3 + Tokens.spacing.lg + root._rows * root._cellH + root._arrowH;
            if (!root.host)
                return wanted;
            const room = root._buttonTop - root._arrowGap - Tokens.spacing.xl;
            return Math.min(wanted, Math.max(root._cellH * 2 + root._pad * 2, room));
        }
        visible: root.open || opacity > 0.01
        opacity: Motion.overlayOpacity(root.open)
        scale: Motion.overlayScale(root.open)
        transformOrigin: Item.Bottom
        x: {
            if (!root.host)
                return 0;
            const raw = root._buttonMid - width / 2;
            const limit = Math.max(Tokens.spacing.md, root.host.width - width - Tokens.spacing.md);
            return Math.max(Tokens.spacing.md, Math.min(raw, limit));
        }
        y: root.host ? root._buttonTop - height - root._arrowGap : 0

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: root.open
                    ? Motion.easingEmphasizedDecelerate
                    : Motion.easingEmphasizedAccelerate
            }
        }
        Behavior on scale {
            enabled: Motion.overlaysZoom
            SpringAnimation {
                spring: Motion.springBouncy.spring
                damping: Motion.springBouncy.damping
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root._arrowH - Tokens.stroke.hairline
            radius: Tokens.radius.medium
            color: Colors.color.surface
            opacity: 1 - (1 - Chrome.washOpacity) * Tokens.glass.panelPass
        }

        Canvas {
            id: arrow
            width: root._arrowW
            height: root._arrowH
            y: parent.height - height
            x: {
                const tip = root._buttonMid - pop.x;
                const raw = tip - width / 2;
                return Math.max(Tokens.spacing.lg, Math.min(raw, parent.width - width - Tokens.spacing.lg));
            }
            z: 2
            property color ink: Colors.color.surface
            property color line: Colors.color.outlineVariant
            property real wash: 1 - (1 - Chrome.washOpacity) * Tokens.glass.panelPass
            onInkChanged: requestPaint()
            onLineChanged: requestPaint()
            onWashChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = Qt.rgba(arrow.ink.r, arrow.ink.g, arrow.ink.b, arrow.wash);
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(width / 2, height);
                ctx.lineTo(width, 0);
                ctx.closePath();
                ctx.fill();
                ctx.strokeStyle = arrow.line;
                ctx.lineWidth = Tokens.stroke.hairline;
                ctx.beginPath();
                ctx.moveTo(Tokens.stroke.hairline, 0);
                ctx.lineTo(width / 2, height - Tokens.stroke.hairline);
                ctx.lineTo(width - Tokens.stroke.hairline, 0);
                ctx.stroke();
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root._arrowH - Tokens.stroke.hairline
            radius: Tokens.radius.medium
            color: "transparent"
            border.color: Colors.color.outlineVariant
            border.width: Tokens.stroke.hairline
            z: 1
        }

        MouseArea {
            anchors.fill: parent
            z: 0
            onClicked: {}
        }

        MText {
            id: heading
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.spacing.md
            key: "launcher.allApps"
            styleName: "labelSmall"
            color: Colors.color.onSurfaceVariant
            font.capitalization: Font.AllUppercase
        }

        GridView {
            id: grid
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: heading.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: root._pad
            anchors.rightMargin: root._pad
            anchors.topMargin: root._pad
            anchors.bottomMargin: root._arrowH + root._pad
            visible: root._count > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            cellWidth: root._cellW
            cellHeight: root._cellH
            model: root._count
            currentIndex: root.currentIndex
            highlightFollowsCurrentItem: false
            keyNavigationEnabled: false
            cacheBuffer: cellHeight * 2

            delegate: Item {
                required property int index
                readonly property var hit: root.model[index] || ({})
                width: grid.cellWidth
                height: grid.cellHeight

                AppTile {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.xs
                    iconName: hit.icon || ""
                    title: hit.name || ""
                    tint: hit.tint === true
                    current: root.currentIndex === index
                    showIcon: root.showIcons
                    onClicked: root.activated(index)
                }
            }

            onCurrentIndexChanged: {
                if (grid.currentIndex >= 0 && root._count > 0)
                    grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
            }
        }

        MEmptyState {
            visible: root._count === 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: heading.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.spacing.md
            anchors.bottomMargin: root._arrowH + Tokens.spacing.md
            iconName: "edit-find-symbolic"
            titleKey: "launcher.noResults"
        }
    }
}
