// Image-first screenshot viewer. Scales to the window; no drag.
import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    readonly property bool open: Store.previewShot.length > 0

    visible: root.open || scrim.opacity > 0
    enabled: root.open
    z: 90

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: root.open ? Tokens.overlay.scrim : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: Motion.easingEmphasized
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: Store.closePreview()
        }
    }

    Image {
        id: img
        anchors.centerIn: parent
        width: parent.width * Tokens.overlay.previewFill
        height: parent.height * Tokens.overlay.previewFill
        source: Store.previewShot
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    MIconButton {
        visible: root.open
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.spacing.md
        close: true
        iconName: "window-close"
        key: "bar.close"
        onClicked: Store.closePreview()
    }
}
