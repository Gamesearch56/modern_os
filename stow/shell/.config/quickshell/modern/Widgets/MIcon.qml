// Freedesktop icon by name, sized from Tokens. `tint` colorizes
// symbolic icons onto a role. Papirus action SVGs are dark while
// status SVGs are already light — colorize from a full-bright source
// so both land on the same onSurface (or caller) role.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../Commons"

Item {
    id: root

    property string name: ""
    property int size: Tokens.icon.md
    property color color: Colors.color.onSurface
    property bool tint: true

    readonly property string _source: {
        if (root.name.length === 0)
            return "";
        const p = Quickshell.iconPath(root.name, true);
        if (!p || p.length === 0)
            return "";
        if (p.indexOf("://") !== -1 || p.indexOf("image:") === 0)
            return p;
        return p.charAt(0) === "/" ? ("file://" + p) : p;
    }

    implicitWidth: root.size
    implicitHeight: root.size

    IconImage {
        id: img
        visible: root._source.length > 0
        anchors.centerIn: parent
        width: root.size
        height: root.size
        implicitSize: root.size
        source: root._source
        mipmap: true
        asynchronous: false
        opacity: root.tint ? 0 : 1
        layer.enabled: root.tint
    }

    MultiEffect {
        anchors.fill: img
        visible: root.tint && img.visible
        source: img
        colorization: 1
        colorizationColor: root.color
        brightness: 1
        saturation: 0
    }
}
