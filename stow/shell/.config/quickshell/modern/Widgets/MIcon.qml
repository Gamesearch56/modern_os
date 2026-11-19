// Freedesktop icon by name, sized from Tokens. `tint` recolors onto a
// role. Symbolic glyphs are used as an alpha mask: Papirus status
// icons (bluetooth, volume, battery) are already light, and lifting
// them with brightness pushes them past the role color in a light
// theme. Full-color Papirus keeps luminance so inner shapes stay
// visible. Callers that change `color` on hover will flatten that
// look — freeze the role.
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
    property bool forceLift: false

    readonly property bool _file: {
        if (root.source.toString().length > 0)
            return true;
        const n = root.name;
        return n.indexOf("://") !== -1 || (n.length > 0 && n.charAt(0) === "/");
    }
    readonly property int _raster: Math.max(root.size * 2, Tokens.icon.lg)

    readonly property string _source: {
        if (root.source.toString().length > 0) {
            const s = root.source.toString();
            if (s.indexOf("://") !== -1 || s.indexOf("image:") === 0)
                return s;
            return s.charAt(0) === "/" ? ("file://" + s) : s;
        }
        if (root.name.indexOf("://") !== -1)
            return root.name;
        if (root.name.length > 0 && root.name.charAt(0) === "/")
            return "file://" + root.name;
        if (root.name.length === 0)
            return "";
        const checked = Quickshell.iconPath(root.name, true);
        const full = Quickshell.iconPath(root.name);
        let p = "";
        if (root.preferSymbolic)
            p = (checked && checked.length > 0) ? checked : full;
        else
            p = (full && full.length > 0) ? full : checked;
        if (!p || p.length === 0)
            return "";
        if (p.indexOf("://") !== -1 || p.indexOf("image:") === 0)
            return p;
        return p.charAt(0) === "/" ? ("file://" + p) : p;
    }

    readonly property bool _symbolicFile: {
        if (root.forceLift)
            return true;
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

    // Solid role color. Symbolic icons mask this, so a light status
    // glyph and a dark action glyph land on the same color.
    Rectangle {
        id: dye
        anchors.fill: parent
        color: root.color
        opacity: 0
        layer.enabled: root._colorize && root._symbolicFile
    }

    MultiEffect {
        anchors.fill: root._file ? fileImg : img
        visible: root._colorize && (root._file ? fileImg.visible : img.visible)
        source: root._symbolicFile ? dye : (root._file ? fileImg : img)
        colorization: root._symbolicFile ? 0 : 1
        colorizationColor: root.color
        brightness: 0
        saturation: 0
        maskEnabled: root._symbolicFile
        maskSource: root._file ? fileImg : img
        // Wide ramp so the icon's antialiased edge stays, instead of a
        // hard cut at the first non-zero alpha.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
