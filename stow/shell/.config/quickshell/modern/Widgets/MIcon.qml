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
    property url source: ""
    property int size: Tokens.icon.md
    property color color: Colors.color.onSurface
    property bool tint: true

    readonly property bool _file: root.source.toString().length > 0

    readonly property bool _robot: root.name === "robot"

    readonly property string _source: {
        if (root._robot)
            return "";
        if (root._file)
            return root.source.toString();
        if (root.name.length === 0)
            return "";
        const symbolic = Quickshell.iconPath(root.name, true);
        const p = (symbolic && symbolic.length > 0) ? symbolic : Quickshell.iconPath(root.name);
        if (!p || p.length === 0)
            return "";
        if (p.indexOf("://") !== -1 || p.indexOf("image:") === 0)
            return p;
        return p.charAt(0) === "/" ? ("file://" + p) : p;
    }

    implicitWidth: root.size
    implicitHeight: root.size

    MRobotIcon {
        visible: root._robot
        anchors.centerIn: parent
        size: root.size
        color: root.color
    }

    Image {
        id: fileImg
        visible: !root._robot && root._file && root._source.length > 0
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
        visible: !root._robot && !root._file && root._source.length > 0
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
        visible: !root._robot && root.tint && (root._file ? fileImg.visible : img.visible)
        source: root._file ? fileImg : img
        colorization: 1
        colorizationColor: root.color
        brightness: root._file ? 0 : 1
        saturation: 0
    }
}
