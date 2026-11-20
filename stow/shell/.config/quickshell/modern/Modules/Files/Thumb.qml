import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property var entry: null
    property int size: Tokens.icon.lg
    property bool frame: false

    readonly property string _path: root.entry && root.entry.path ? String(root.entry.path) : ""
    readonly property string _src: FilesThumbs.source(root._path)
    readonly property bool _video: FilesThumbs.video(root.entry)
    readonly property bool _dir: !!(root.entry && (root.entry.dir === true || root.entry.kind === "dir"))
    readonly property real _tabH: root.frame ? Tokens.spacing.md : Tokens.spacing.xs

    implicitWidth: root.size
    implicitHeight: root.frame ? Tokens.spacing.xxl * 3 : root.size
    clip: true

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.small
        color: Colors.color.surfaceContainer
        visible: !root._dir && (root.frame || pic.status !== Image.Ready)
    }

    // A tab plus a filled body. Only the large tile has room for it —
    // the same shape at list size collapses into a clipped blob.
    Item {
        anchors.fill: parent
        visible: root.frame && root._dir && pic.status !== Image.Ready

        // Surface tones. A primary fill on every tile outshouts the names.
        Rectangle {
            width: root.frame ? Tokens.spacing.xxl * 2 : Tokens.spacing.lg
            height: root._tabH + Tokens.spacing.xs
            radius: Tokens.radius.small
            color: Colors.color.surfaceContainerHighest
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: parent.top
            anchors.topMargin: root._tabH
            radius: Tokens.radius.small
            color: Colors.color.surfaceContainerHigh

            MIcon {
                anchors.centerIn: parent
                visible: root.frame
                name: "folder"
                size: Tokens.icon.lg
                color: Colors.color.onSurfaceVariant
            }
        }
    }

    Image {
        id: pic
        anchors.fill: parent
        source: root._src
        // Fit the whole picture in the tile. A square sourceSize stretches
        // it before this can keep the shape.
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        mipmap: true
        sourceSize.width: Tokens.spacing.xxl * 8
        opacity: status === Image.Ready ? 1 : 0
    }

    MIcon {
        anchors.centerIn: parent
        visible: pic.status !== Image.Ready && (!root._dir || !root.frame)
        name: root._dir ? "folder" : FilesThumbs.glyph(root.entry)
        size: root.frame ? Tokens.icon.lg : root.size
        color: root._dir ? Colors.color.primary : Colors.color.onSurface
    }

    Rectangle {
        visible: root.entry && (root.entry.readable === false || root.entry.canRead === false)
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Tokens.spacing.xxs
        width: Tokens.spacing.lg
        height: Tokens.spacing.lg
        radius: Tokens.radius.full
        color: Colors.color.error

        MIcon {
            anchors.centerIn: parent
            name: "changes-prevent"
            size: Tokens.spacing.md
            color: Colors.color.onError
        }
    }

    Rectangle {
        visible: Files.place !== "favorites" && root._path.length > 0 && FilesPlaces.favorite(root._path)
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.spacing.xxs
        width: Tokens.spacing.lg
        height: Tokens.spacing.lg
        radius: Tokens.radius.full
        color: Colors.color.primary

        MIcon {
            anchors.centerIn: parent
            name: "starred"
            size: Tokens.spacing.md
            color: Colors.color.onPrimary
        }
    }

    Rectangle {
        visible: root.frame && root._video && pic.status === Image.Ready
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.spacing.xs
        width: Tokens.spacing.xl
        height: Tokens.spacing.xl
        radius: Tokens.radius.full
        color: Colors.color.primary

        MIcon {
            anchors.centerIn: parent
            name: "media-playback-start"
            size: Tokens.icon.xs
            color: Colors.color.onPrimary
        }
    }
}
