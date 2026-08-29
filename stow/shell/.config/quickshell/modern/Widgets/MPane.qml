// Filled surfaceContainer well. Settings sidebar and overlay bodies
// share this so picker windows match the Settings chrome.
import QtQuick
import "../Commons"

Rectangle {
    id: root

    property real padding: Tokens.spacing.sm
    default property alias extra: inner.data

    radius: Tokens.radius.medium
    color: Colors.color.surfaceContainer
    clip: true

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
