// Same icon-and-name grid as the all-applications window, so an app
// can be dragged onto the dock field.
import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"

Item {
    id: root

    property var board: null
    property var installed: []
    property string query: ""

    readonly property real _cellW: Tokens.spacing.xxl * 4
    readonly property real _cellH: Tokens.spacing.xxl * 3 + Tokens.spacing.sm
    readonly property real _pad: Tokens.spacing.md
    readonly property int _rows: 4
    readonly property var shown: {
        const needle = root.query.trim().toLowerCase();
        const all = root.installed || [];
        if (!needle.length)
            return all;
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const name = String(all[i].name || "").toLowerCase();
            if (name.indexOf(needle) !== -1)
                out.push(all[i]);
        }
        return out;
    }
    readonly property int _count: root.shown.length

    implicitHeight: headingRow.implicitHeight + root._pad * 3 + root._cellH * root._rows

    // The card covers the page, so a wheel over the icons has to reach
    // the page once the grid is at that end. Otherwise the only page
    // scroll is the thin margin around the card.
    function _pageFlick() {
        let p = root.parent;
        while (p) {
            if (p.flickableDirection !== undefined && p.contentHeight !== undefined)
                return p;
            p = p.parent;
        }
        return null;
    }

    function _wheelPixels(w) {
        if (w.pixelDelta && w.pixelDelta.y !== 0)
            return w.pixelDelta.y;
        return w.angleDelta.y / 8;
    }

    function _nudge(flick, pixels) {
        if (!flick || flick.interactive === false)
            return 0;
        const maxY = Math.max(0, flick.contentHeight - flick.height);
        const before = flick.contentY;
        const next = Math.max(0, Math.min(maxY, before - pixels));
        if (Math.abs(next - before) < 0.5)
            return 0;
        if (flick.cancelFlick)
            flick.cancelFlick();
        flick.contentY = next;
        return before - next;
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: Colors.color.surface
        opacity: 1 - (1 - Chrome.washOpacity) * Tokens.glass.panelPass
    }
    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: "transparent"
        border.color: Colors.color.outlineVariant
        border.width: Tokens.stroke.hairline
    }

    RowLayout {
        id: headingRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.spacing.md
        height: implicitHeight
        spacing: Tokens.spacing.md

        MText {
            key: "settings.dock.installed"
            styleName: "labelSmall"
            color: Colors.color.onSurfaceVariant
            font.capitalization: Font.AllUppercase
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        MSearchField {
            id: search
            placeholderKey: "settings.dock.search"
            Layout.preferredWidth: Tokens.spacing.xxl * 6
            Layout.alignment: Qt.AlignVCenter
            onTextEdited: root.query = search.text
        }
    }

    GridView {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headingRow.bottom
        anchors.bottom: parent.bottom
        anchors.margins: root._pad
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        cellWidth: root._cellW
        cellHeight: root._cellH
        model: root._count
        cacheBuffer: cellHeight * 2

        // Owns the wheel so the grid does not swallow a notch it cannot use.
        WheelHandler {
            blocking: true
            onWheel: (w) => {
                const pixels = root._wheelPixels(w);
                if (pixels === 0) {
                    w.accepted = false;
                    return;
                }
                const used = root._nudge(grid, pixels);
                const left = pixels - used;
                if (Math.abs(left) > 0.5)
                    root._nudge(root._pageFlick(), left);
                w.accepted = true;
            }
        }

        delegate: Item {
            id: cell
            required property int index
            readonly property var hit: root.shown[index] || ({})
            readonly property string appId: String(cell.hit.id || "")
            width: grid.cellWidth
            height: grid.cellHeight
            opacity: root.board && root.board._dragId === cell.appId && root.board._dragFrom < 0
                ? Tokens.interaction.cut : 1
            Accessible.role: Accessible.Button
            Accessible.name: String(cell.hit.name || "")

            Rectangle {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.xs
                radius: Tokens.radius.medium
                color: Colors.color.primary
                opacity: Chrome.stateLayer(grab.containsMouse, grab.pressed)
            }
            Column {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.sm
                spacing: Tokens.spacing.xs
                Item {
                    width: parent.width
                    height: Tokens.icon.lg
                    MIcon {
                        anchors.centerIn: parent
                        name: String(cell.hit.icon || "application-x-executable")
                        size: Tokens.icon.lg
                        tint: false
                        preferSymbolic: false
                    }
                }
                MText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    value: String(cell.hit.name || "")
                    styleName: "labelMedium"
                    color: Colors.color.onSurface
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
            MDragArea {
                id: grab
                anchors.fill: parent
                canDrag: cell.appId.length > 0 && !!root.board
                onDragBegan: (x, y, lx, ly) => root.board.begin(cell.appId, -1, x, y, grab, lx, ly)
                onDragMoved: (x, y, lx, ly) => root.board.move(x, y, grab, lx, ly)
                onDragDropped: (x, y) => root.board.end(x, y)
                onDragCanceled: root.board.cancel()
            }
        }
    }
}
