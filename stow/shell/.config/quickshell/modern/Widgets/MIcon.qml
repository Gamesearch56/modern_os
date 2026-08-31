// Freedesktop icon by name, sized from Tokens. `tint` recolors onto a
// role. Symbolic glyphs (bar, chrome) are often dark grey — lift them
// with brightness 1 so they land on onSurface. Full-color Settings nav
// icons keep luminance (brightness 0) so inner shapes stay visible.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../Commons"

Item {
    id: root

    property string name: ""
    property url source: ""
    property int size: Tokens.icon.md
    property color color: Colors.color.onSurface
    property bool tint: true
    property bool preferSymbolic: true

    readonly property bool _file: root.source.toString().length > 0

    readonly property string _source: {
        if (root._file)
            return root.source.toString();
        if (root.name.length === 0)
            return "";
        const symbolic = Quickshell.iconPath(root.name, true);
        const full = Quickshell.iconPath(root.name);
        let p = "";
        if (root.preferSymbolic)
            p = (symbolic && symbolic.length > 0) ? symbolic : full;
        else
            p = (full && full.length > 0) ? full : symbolic;
        if (!p || p.length === 0)
            return "";
        if (p.indexOf("://") !== -1 || p.indexOf("image:") === 0)
            return p;
        return p.charAt(0) === "/" ? ("file://" + p) : p;
    }

    // Brightness 1 flattens full-color Papirus badges (inner arrows
    // become the same as the disc). Only lift true symbolic glyphs.
    readonly property bool _symbolicFile: {
        const s = root._source.toLowerCase();
        return s.indexOf("-symbolic") !== -1 || s.indexOf("/symbolic") !== -1;
    }

    implicitWidth: root.size
    implicitHeight: root.size

    Image {
        id: fileImg
        visible: root._file && root._source.length > 0
        anchors.centerIn: parent
        width: root.size
        height: root.size
        source: root._file ? root._source : ""
        fillMode: Image.PreserveAspectFit
        sourceSize.width: root.size
        sourceSize.height: root.size
        asynchronous: false
        opacity: root.tint ? 0 : 1
        layer.enabled: root.tint
    }

    IconImage {
        id: img
        visible: !root._file && root._source.length > 0
        anchors.centerIn: parent
        width: root.size
        height: root.size
        implicitSize: root.size
        source: root._file ? "" : root._source
        mipmap: true
        asynchronous: false
        opacity: root.tint ? 0 : 1
        layer.enabled: root.tint
    }

    MultiEffect {
        anchors.fill: root._file ? fileImg : img
        visible: root.tint && (root._file ? fileImg.visible : img.visible)
        source: root._file ? fileImg : img
        colorization: 1
        colorizationColor: root.color
        brightness: root._symbolicFile ? 1 : 0
        saturation: 0
    }
}
