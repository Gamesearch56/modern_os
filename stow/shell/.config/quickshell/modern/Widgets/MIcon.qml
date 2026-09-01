// Freedesktop icon by name, sized from Tokens. `tint` recolors onto a
// role. Symbolic glyphs are lifted (brightness 1). Full-color Papirus
// keeps luminance (brightness 0) so inner shapes stay visible. Callers
// that change `color` on hover will flatten that look — freeze the role.
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
    readonly property int _raster: Math.max(root.size * 2, Tokens.icon.lg)

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

    readonly property bool _symbolicFile: {
        const n = root.name.toLowerCase();
        const s = root._source.toLowerCase();
        return n.indexOf("-symbolic") !== -1 || s.indexOf("-symbolic") !== -1 || s.indexOf("/symbolic/") !== -1;
    }
    readonly property bool _colorize: root.tint

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
        sourceSize.width: root._raster
        sourceSize.height: root._raster
        asynchronous: false
        opacity: root._colorize ? 0 : 1
        layer.enabled: root._colorize
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
        opacity: root._colorize ? 0 : 1
        layer.enabled: root._colorize
    }

    MultiEffect {
        anchors.fill: root._file ? fileImg : img
        visible: root._colorize && (root._file ? fileImg.visible : img.visible)
        source: root._file ? fileImg : img
        colorization: 1
        colorizationColor: root.color
        brightness: root._symbolicFile ? 1 : 0
        saturation: 0
    }
}
