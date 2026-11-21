// Signal strength as four rising bars. level 0–4; below 0 hides it.
import QtQuick
import "../Commons"

Item {
    id: root

    property int level: -1
    property string label: ""
    readonly property int _bars: 4
    readonly property real _barW: Tokens.spacing.xs
    readonly property real _gap: Tokens.spacing.xxs

    visible: root.level >= 0
    implicitWidth: root._bars * root._barW + (root._bars - 1) * root._gap
    implicitHeight: Tokens.icon.xs
    Accessible.role: Accessible.Indicator
    Accessible.name: root.label

    Repeater {
        model: root._bars
        Rectangle {
            required property int index
            x: index * (root._barW + root._gap)
            width: root._barW
            height: root.implicitHeight * (index + 1) / root._bars
            y: root.implicitHeight - height
            radius: Tokens.radius.full
            color: index < root.level ? Colors.color.primary : Colors.color.outlineVariant

            Behavior on color {
                ColorAnimation {
                    duration: Motion.shortMs
                    easing.bezierCurve: Motion.easingStandard
                }
            }
        }
    }
}
