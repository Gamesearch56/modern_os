import QtQuick
import "../../Commons"
import "../../Services"
import "../../Widgets"

Item {
    id: root

    property bool vertical: false
    property string screenName: ""

    signal pinFocused()

    readonly property bool _dropHere: Dock.dragActive && Dock.hoverKind === "row"
        && Dock.hoverScreen === root.screenName
    readonly property int _dropAt: root._dropHere ? Dock.hoverIndex : -1
    readonly property bool _trash: Dock.trashShown
        && (Dock.dragScreen.length === 0 || Dock.dragScreen === root.screenName)
    readonly property bool _blocked: Dock.dragFromGrid && AppUninstall.blocked

    readonly property var ids: {
        void Config.generation;
        return Dock.apps();
    }
    readonly property real _gap: DockLayout.gap
    on_GapChanged: layout()
    onVerticalChanged: layout()

    // The trash sits past the last pin. Without it in the size, a full
    // column clips the target and scrolling never reaches it.
    implicitWidth: host.implicitWidth + (!root.vertical && root._trash ? trash.width + Tokens.spacing.md : 0)
    implicitHeight: host.implicitHeight + (root.vertical && root._trash ? trash.height + Tokens.spacing.md : 0)

    function layout() {
        let cursor = 0;
        let cross = 0;
        const n = pins.count;
        for (let i = 0; i < n; i++) {
            const item = pins.itemAt(i);
            if (!item)
                continue;
            if (root.vertical) {
                item.x = 0;
                item.y = Math.round(cursor);
                cursor += Math.round(item.implicitHeight) + root._gap;
                cross = Math.max(cross, item.implicitWidth);
            } else {
                item.x = Math.round(cursor);
                item.y = 0;
                cursor += Math.round(item.implicitWidth) + root._gap;
                cross = Math.max(cross, item.implicitHeight);
            }
        }
        if (n > 0)
            cursor -= root._gap;
        host.implicitWidth = Math.round(root.vertical ? cross : Math.max(cursor, 0));
        host.implicitHeight = Math.round(root.vertical ? Math.max(cursor, 0) : cross);
    }

    function indexAt(x: real, y: real): int {
        const n = pins.count;
        if (n === 0)
            return 0;
        const along = root.vertical ? y : x;
        for (let i = 0; i < n; i++) {
            const item = pins.itemAt(i);
            if (!item)
                continue;
            const mid = root.vertical ? item.y + item.height / 2 : item.x + item.width / 2;
            if (along < mid)
                return i;
        }
        return n;
    }

    function trashContains(x: real, y: real): bool {
        if (!trash.visible)
            return false;
        const slop = Tokens.spacing.sm;
        return x >= trash.x - slop && y >= trash.y - slop
            && x <= trash.x + trash.width + slop && y <= trash.y + trash.height + slop;
    }

    function _markAt(index: int): real {
        const n = pins.count;
        if (n === 0)
            return 0;
        if (index >= n) {
            const last = pins.itemAt(n - 1);
            if (!last)
                return 0;
            return root.vertical
                ? last.y + last.height + root._gap / 2
                : last.x + last.width + root._gap / 2;
        }
        const item = pins.itemAt(index);
        if (!item)
            return 0;
        return root.vertical ? item.y - root._gap / 2 : item.x - root._gap / 2;
    }

    Item {
        id: host

        Repeater {
            id: pins
            model: root.ids.length
            onItemAdded: Qt.callLater(root.layout)
            onItemRemoved: Qt.callLater(root.layout)

            DockPin {
                appId: String(root.ids[index] || "")
                vertical: root.vertical
                edge: DockLayout.position
                repeater: pins
                onFocused: root.pinFocused()
                onImplicitWidthChanged: root.layout()
                onImplicitHeightChanged: root.layout()
            }
        }
    }

    Rectangle {
        visible: root._dropAt >= 0
        width: root.vertical ? DockLayout.iconSize : Tokens.spacing.xs
        height: root.vertical ? Tokens.spacing.xs : Math.max(host.implicitHeight, DockLayout.iconSize)
        radius: Tokens.radius.full
        color: Colors.color.primary
        x: root.vertical ? 0 : root._markAt(root._dropAt) - width / 2
        y: root.vertical ? root._markAt(root._dropAt) - height / 2 : (host.implicitHeight - height) / 2
        z: 2
    }

    Item {
        id: trash
        visible: root._trash
        width: DockLayout.iconSize - Tokens.spacing.md
        height: width
        x: root.vertical ? (host.implicitWidth - width) / 2 : host.implicitWidth + Tokens.spacing.md
        y: root.vertical ? host.implicitHeight + Tokens.spacing.md : (host.implicitHeight - height) / 2
        z: 3
        Accessible.role: Accessible.Button
        Accessible.name: I18n.t(Dock.dragFromGrid ? "launcher.uninstall.trash" : "settings.dock.trash")

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root._blocked ? Colors.color.surfaceContainerHighest : Colors.color.errorContainer
        }

        MIcon {
            id: glyph
            anchors.centerIn: parent
            name: "user-trash"
            size: trash.width - Tokens.spacing.md
            color: root._blocked ? Colors.color.onSurface : Colors.color.onErrorContainer
            opacity: root._blocked ? Tokens.dimmedOpacity : 1
            tint: true
        }

        // Only a pin being unpinned wiggles; an uninstall target holds still.
        SequentialAnimation {
            running: trash.visible && Dock.dragFromDock
            loops: Animation.Infinite
            onRunningChanged: {
                if (!running)
                    glyph.rotation = 0;
            }
            NumberAnimation {
                target: glyph
                property: "rotation"
                to: Tokens.spacing.sm
                duration: Motion.shortMs
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: glyph
                property: "rotation"
                to: -Tokens.spacing.sm
                duration: Motion.shortMs
                easing.type: Easing.InOutQuad
            }
        }
    }
}
