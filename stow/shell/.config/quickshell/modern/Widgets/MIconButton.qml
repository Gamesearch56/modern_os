// Circular icon-only button. Used for bar launcher/settings/power and
// transport controls. `checked` paints with primaryContainer so toggles
// (mute, shuffle) share one primitive with click-to-fire buttons.
import QtQuick
import "../Commons"

Item {
    id: root

    property string iconName: ""
    property string key: ""
    property bool checked: false
    property bool enabled: true
    property int size: Tokens.spacing.xxl

    signal clicked()
    signal middleClicked()
    signal rightClicked()
    signal wheel(real steps)

    implicitWidth: root.size
    implicitHeight: root.size
    opacity: root.enabled ? 1 : 0.38

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Tokens.radius.full
        color: root.checked ? Colors.color.primaryContainer : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    MIcon {
        anchors.centerIn: parent
        name: root.iconName
        size: Math.round(root.size * 0.55)
        color: root.checked ? Colors.color.onPrimaryContainer : Colors.color.onSurface
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                root.middleClicked();
            else if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
        onWheel: (w) => root.wheel(w.angleDelta.y > 0 ? 1 : -1)
        onPressed: bg.scale = 0.92
        onReleased: bg.scale = 1
        onCanceled: bg.scale = 1
    }

    Behavior on scale {
        SpringAnimation {
            spring: Motion.springSnappy.spring
            damping: Motion.springSnappy.damping
        }
    }
}
