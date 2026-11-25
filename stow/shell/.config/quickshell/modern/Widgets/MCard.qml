// Elevated surface. The only component that draws a shadow — every
// panel/popup hosts its content in an MCard so elevation stays one
// place (docs/DESIGN.md). `level` is 0–5 from Tokens.elevation.
import QtQuick
import "../Commons"

Rectangle {
    id: root

    property int level: 1
    property real padding: Tokens.spacing.md
    property color borderColor: "transparent"
    property int borderWidth: 0
    property bool highlighted: false
    property alias content: inner.data
    default property alias extra: inner.data

    readonly property var _elev: {
        void Tokens.surfaceTint;
        return Tokens.elevationFor(root.level);
    }

    radius: Tokens.radius.medium
    color: Colors.color.surfaceContainer
    border.color: root.borderColor
    border.width: root.borderWidth
    clip: true

    // One offscreen texture per card; it only keeps fades grouped.
    layer.enabled: root._elev.shadowOpacity > 0 && !Chrome.lightEffects
    layer.effect: null

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Colors.color.primary
        opacity: root._elev.tintOpacity
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.padding
    }

    MFocusRing {
        radius: root.radius
        active: root.highlighted
    }
}
