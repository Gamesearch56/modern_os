// Fullscreen frosted wallpaper: pre-blurred source plus the same
// surface wash as island chrome (`design.transparency`).
import QtQuick
import "../Commons"

Item {
    id: root

    property var sources: []
    property real washOpacity: Config.design.transparency ?? 0.85
    property real scrimOpacity: Tokens.overlay.scrim
    property int _i: 0

    onSourcesChanged: root._i = 0

    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        source: {
            const list = root.sources || [];
            const i = Math.max(0, Math.min(root._i, list.length - 1));
            return list.length > 0 ? list[i] : "";
        }
        onStatusChanged: {
            if (status === Image.Error && root._i + 1 < (root.sources || []).length)
                root._i += 1;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.color.surface
        opacity: root.washOpacity
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: root.scrimOpacity
    }
}
