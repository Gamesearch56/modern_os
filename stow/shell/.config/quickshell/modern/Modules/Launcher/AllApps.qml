// The full app grid hangs above its own button. Reparenting the card
// onto the launcher column keeps clicks on the grid, and the arrow
// stays aimed at the button when the list above it changes height.
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
    property real popupHeight: Tokens.spacing.xxl * 8

    signal toggled()
    signal activated(int index)
    signal retreated()

    readonly property int _count: root.model ? root.model.length : 0
    readonly property real _arrowW: Tokens.spacing.xl
    readonly property real _arrowH: Tokens.spacing.md
    readonly property int columns: Math.max(3, Math.floor((pop.width > 0 ? pop.width : Tokens.spacing.xxl * 16) / (Tokens.spacing.xxl * 4)))

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
        width: root.host ? root.host.width : 0
        height: Math.max(Tokens.spacing.xxl * 4, root.popupHeight)
        visible: root.open || opacity > 0.01
        opacity: Motion.overlayOpacity(root.open)
        scale: Motion.overlayScale(root.open)
        transformOrigin: Item.Bottom
        x: {
            void button.x;
            if (!root.host)
                return 0;
            const mid = button.mapToItem(root.host, button.width / 2, 0).x;
            return mid - width / 2;
        }
        y: {
            void button.y;
            void root.popupHeight;
            if (!root.host)
                return 0;
            return button.mapToItem(root.host, 0, 0).y - height - Tokens.spacing.xs;
        }

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
            opacity: Chrome.washOpacity
        }

        Canvas {
            id: arrow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: root._arrowW
            height: root._arrowH
            z: 2
            property color ink: Colors.color.surface
            property color line: Colors.color.outlineVariant
            property real wash: Chrome.washOpacity
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
            anchors.leftMargin: Tokens.spacing.sm
            anchors.rightMargin: Tokens.spacing.sm
            anchors.topMargin: Tokens.spacing.sm
            anchors.bottomMargin: root._arrowH + Tokens.spacing.sm
            visible: root._count > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            cellWidth: Math.max(1, Math.floor(width / root.columns))
            cellHeight: Tokens.spacing.xxl * 2 + Tokens.spacing.xl
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
                    anchors.margins: Tokens.spacing.xxs
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
