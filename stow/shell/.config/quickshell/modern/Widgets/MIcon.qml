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

    // System apps share one plate. The glyph is only the picture; the
    // colors come from the active theme, not from the icon file.
    readonly property string _systemGlyph: SystemIcons.glyph(root.name)
    readonly property bool _system: root._systemGlyph.length > 0
    readonly property color _ink: root._system ? Colors.color.onPrimaryContainer : root.color
    readonly property string _lookup: {
        if (!root._system)
            return root.name;
        // The icon theme keeps the list it had when the shell started.
        // A glyph added later resolves to an empty image, so the plate
        // shows with no mark. The installed file is the one we ship.
        const home = String(Quickshell.env("HOME") || "");
        return home + "/.local/share/icons/hicolor/scalable/apps/" + root._systemGlyph + ".svg";
    }
    readonly property bool _file: {
        if (root.source.toString().length > 0)
            return true;
        const n = root._lookup;
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
        if (root._lookup.indexOf("://") !== -1)
            return root._lookup;
        if (root._lookup.length > 0 && root._lookup.charAt(0) === "/")
            return "file://" + root._lookup;
        if (root._lookup.length === 0)
            return "";
        const checked = Quickshell.iconPath(root._lookup, true);
        const full = Quickshell.iconPath(root._lookup);
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
        const n = root._lookup.toLowerCase();
        const s = root._source.toLowerCase();
        return root._system || n.indexOf("-symbolic") !== -1 || s.indexOf("-symbolic") !== -1 || s.indexOf("/symbolic/") !== -1;
    }
    readonly property bool _colorize: root.tint || root._system

    implicitWidth: root.size
    implicitHeight: root.size

    Rectangle {
        visible: root._system
        anchors.fill: parent
        radius: Math.min(Tokens.radius.small, root.width / 4)
        color: Colors.color.primaryContainer
    }

    Image {
        id: fileImg
        visible: root._file && root._source.length > 0
        anchors.centerIn: parent
        width: root._system ? root.size - Tokens.spacing.sm : root.size
        height: width
        source: root._file ? root._source : ""
        fillMode: Image.PreserveAspectFit
        sourceSize.width: root._raster
        sourceSize.height: root._raster
        asynchronous: false
        mipmap: true
        opacity: root._colorize ? 0 : 1
        // A later scale (dock zoom) magnifies whatever was rasterized.
        // Keep this buffer at the 2x source, not the resting size.
        layer.enabled: root._colorize
        layer.smooth: true
        layer.mipmap: true
        layer.textureSize: Qt.size(root._raster, root._raster)
    }

    IconImage {
        id: img
        visible: !root._file && root._source.length > 0
        anchors.centerIn: parent
        width: root._system ? root.size - Tokens.spacing.sm : root.size
        height: width
        implicitSize: width
        source: root._file ? "" : root._source
        mipmap: true
        asynchronous: false
        opacity: root._colorize ? 0 : 1
        // IconImage otherwise decodes at the displayed size, so a zoom
        // magnifies a 1x pixmap. Request the same 2x source as file icons.
        backer.sourceSize.width: root._raster
        backer.sourceSize.height: root._raster
        layer.enabled: root._colorize
        layer.smooth: true
        layer.mipmap: true
        layer.textureSize: Qt.size(root._raster, root._raster)
    }

    // Solid role color. Symbolic icons mask this, so a light status
    // glyph and a dark action glyph land on the same color.
    Rectangle {
        id: dye
        anchors.fill: parent
        color: root._ink
        opacity: 0
        layer.enabled: root._colorize && root._symbolicFile
    }

    MultiEffect {
        anchors.fill: root._file ? fileImg : img
        visible: root._colorize && (root._file ? fileImg.visible : img.visible)
        source: root._symbolicFile ? dye : (root._file ? fileImg : img)
        colorization: root._symbolicFile ? 0 : 1
        colorizationColor: root._ink
        brightness: 0
        saturation: 0
        maskEnabled: root._symbolicFile
        maskSource: root._file ? fileImg : img
        // Dark keeps the wide ramp these status icons were drawn with.
        // Light sits under Papirus's 35% "off" ink, or that gray stays
        // brighter than the rest of a light bar.
        maskThresholdMin: Colors.mode === "light" ? 0.12 : 0.5
        maskSpreadAtMin: Colors.mode === "light" ? 0.12 : 1
    }
}
