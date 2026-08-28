// Freedesktop icon by name, sized from Tokens. Widgets never pick a
// color by hex — `color` is reserved for a future symbolic tint once
// IconImage exposes one. Prefer `name` over a raw URL so icon-theme
// switches apply. Empty/missing names stay blank (no Qt error texture).
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../Commons"

Item {
    id: root

    property string name: ""
    property int size: Tokens.spacing.lg
    property color color: Colors.color.onSurface

    readonly property string _source: {
        if (root.name.length === 0)
            return "";
        const p = Quickshell.iconPath(root.name);
        if (!p || p.length === 0)
            return "";
        if (p.indexOf("://") !== -1 || p.indexOf("image:") === 0)
            return p;
        return p.charAt(0) === "/" ? ("file://" + p) : p;
    }

    implicitWidth: root.size
    implicitHeight: root.size

    IconImage {
        visible: root._source.length > 0
        anchors.centerIn: parent
        width: root.size
        height: root.size
        implicitSize: root.size
        source: root._source
        mipmap: true
        asynchronous: false
    }
}
