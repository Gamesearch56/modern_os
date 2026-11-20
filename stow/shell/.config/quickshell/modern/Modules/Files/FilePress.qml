// Press a row to select it. A longer drag hands the paths to other
// programs as file URIs, so a browser upload field can accept them.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../Commons"
import "../../Widgets"
import "../../Services"

MouseArea {
    id: root

    property var entry: null
    property real markRadius: Tokens.radius.medium
    property bool _dragged: false
    property var _paths: []
    property string _uris: ""
    property string _plain: ""
    property string _label: ""
    readonly property string _path: String(root.entry && root.entry.path || "")
    readonly property bool _held: FilesDrag.active && (FilesDrag.paths || []).indexOf(root._path) >= 0
    readonly property bool _land: FilesDrag.active && !root._held && root.entry && root.entry.dir && FilesDrag.drop === root._path

    signal menu(real x, real y)
    signal picked(bool extra)
    signal activated()

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    preventStealing: true
    hoverEnabled: true
    cursorShape: Qt.ArrowCursor
    drag.axis: Drag.XAndYAxis
    drag.threshold: Tokens.spacing.md

    onPressed: (mouse) => {
        forceActiveFocus();
        root._dragged = false;
        ghost.x = 0;
        ghost.y = 0;
        if (mouse.button !== Qt.LeftButton) {
            drag.target = null;
            return;
        }
        drag.target = root._arm() ? ghost : null;
        if (drag.target)
            chip.grabToImage(result => { ghost.Drag.imageSource = result.url; });
    }
    onReleased: drag.target = null
    onClicked: (mouse) => {
        if (root._dragged)
            return;
        if (mouse.button === Qt.RightButton) {
            const at = root._at(mouse.x, mouse.y);
            root.menu(at.x, at.y);
            return;
        }
        root.picked((mouse.modifiers & Qt.ControlModifier) !== 0);
    }
    onDoubleClicked: {
        if (!root._dragged)
            root.activated();
    }

    Rectangle {
        anchors.fill: parent
        radius: root.markRadius
        color: "transparent"
        border.width: root._held || root._land ? Tokens.stroke.focus : 0
        border.color: Colors.color.primary
    }

    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: (drag) => {
            FilesDrag.offer(drag);
            FilesDrag.cover();
            root._aim();
        }
        onExited: {
            if (FilesDrag.active && FilesDrag.drop === root._path)
                FilesDrag.drop = root._here();
            FilesDrag.uncover();
        }
        onDropped: (drag) => {
            FilesDrag.offer(drag);
            root._aim();
            if (!FilesDrag.active)
                return;
            drag.accept(Qt.MoveAction);
            FilesDrag.land();
        }
    }

    Item {
        id: ghost
        width: chip.width
        height: chip.height
        opacity: 0

        Drag.active: root.drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.CopyAction
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.keys: ["text/uri-list"]
        Drag.mimeData: ({
            "text/uri-list": root._uris,
            "text/plain": root._plain
        })
        Drag.onDragStarted: {
            root._dragged = true;
            FilesDrag.begin(root._paths);
        }
        Drag.onDragFinished: (dropAction) => {
            ghost.x = 0;
            ghost.y = 0;
            if (FilesDrag.active)
                FilesDrag.end();
            if (dropAction === Qt.MoveAction)
                Files.refresh();
        }
    }

    // Clipped out of the tile. grabToImage still paints the card for the drag.
    Item {
        width: 0
        height: 0
        clip: true

        Rectangle {
            id: chip
            width: Tokens.spacing.xxl * 7
            height: Tokens.spacing.xxl + Tokens.spacing.md
            radius: Tokens.radius.medium
            color: Colors.color.surfaceContainerHigh
            border.width: Tokens.stroke.hairline
            border.color: Colors.color.outline

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.spacing.sm
                anchors.rightMargin: Tokens.spacing.sm
                spacing: Tokens.spacing.sm

                MIcon {
                    name: FilesThumbs.glyph(root.entry)
                    size: Tokens.icon.md
                    Layout.preferredWidth: Tokens.icon.md
                    Layout.preferredHeight: Tokens.icon.md
                }
                MText {
                    Layout.fillWidth: true
                    text: root._label
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: root._paths.length > 1
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.spacing.xs
                width: Tokens.spacing.xl
                height: Tokens.spacing.xl
                radius: Tokens.radius.full
                color: Colors.color.primary

                MText {
                    anchors.centerIn: parent
                    text: String(root._paths.length)
                    styleName: "labelSmall"
                    color: Colors.color.onPrimary
                }
            }
        }
    }

    function _arm(): bool {
        const path = String(root.entry && root.entry.path || "");
        if (path.charAt(0) !== "/")
            return false;
        const selected = Files.selected || [];
        const use = selected.indexOf(path) >= 0 ? selected : [path];
        const lines = [];
        const plain = [];
        for (let i = 0; i < use.length; i++) {
            const item = String(use[i] || "");
            if (item.charAt(0) !== "/")
                continue;
            lines.push(root._uri(item));
            plain.push(item);
        }
        if (!lines.length)
            return false;
        root._paths = plain;
        root._label = String(root.entry && root.entry.name || "");
        root._uris = lines.join("\r\n") + "\r\n";
        root._plain = plain.join("\n");
        return true;
    }

    function _here(): string {
        const path = String(Files.path || "");
        return Files.place === "folder" && path.charAt(0) === "/" ? path : "";
    }

    function _aim() {
        if (!FilesDrag.active)
            return;
        const folder = root.entry && root.entry.dir && root._path.charAt(0) === "/" && !root._held;
        FilesDrag.drop = folder ? root._path : root._here();
    }

    function _uri(path: string): string {
        const bits = path.split("/");
        let out = "file://";
        for (let i = 0; i < bits.length; i++) {
            if (!bits[i].length)
                continue;
            out += "/" + encodeURIComponent(bits[i]);
        }
        return out;
    }

    function _at(x: real, y: real): var {
        const host = Window.window ? Window.window.contentItem : root;
        return root.mapToItem(host, x, y);
    }
}
