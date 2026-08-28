// Anchored popup surface. Hosts an MCard; open/close is a gentle
// spring on opacity+scale so panels feel interruptible (docs/MOTION.md).
// Caller owns positioning (`x`/`y`/`implicitWidth`).
import QtQuick
import "../Commons"

Item {
    id: root

    property bool open: false
    property int elevation: 2
    default property alias content: card.content

    visible: root.open || opacity > 0
    opacity: root.open ? 1 : 0
    scale: root.open ? 1 : 0.96
    transformOrigin: Item.Top

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.medium()
            easing.bezierCurve: Motion.easingEmphasizedDecelerate
        }
    }
    Behavior on scale {
        SpringAnimation {
            spring: Motion.springGentle.spring
            damping: Motion.springGentle.damping
        }
    }

    MCard {
        id: card
        anchors.fill: parent
        level: root.elevation
    }
}
