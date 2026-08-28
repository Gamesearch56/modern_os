// Freedesktop icon by name, sized from Tokens. `tint` colorizes
// symbolic icons onto a role (primary / onSurface). Full-color app
// icons set tint: false so Papirus artwork is left alone.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../Commons"

Item {
    id: root

    property string name: ""
    property int size: Tokens.spacing.lg
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
        layer.enabled: root.tint && visible
        layer.effect: MultiEffect {
            colorization: 1
            colorizationColor: root.color
        }
    }
}
