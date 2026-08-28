// One row in a list (launcher results, settings search, cheatsheet
// shortcuts, device lists). Icon + title + optional subtitle + trailing
// slot. Highlight follows keyboard focus, not just hover.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string iconName: ""
    property string titleKey: ""
    property string titleValue: ""
    property string subtitleKey: ""
    property string subtitleValue: ""
    property bool selected: false
    property bool enabled: true

    signal clicked()
    signal activated()

    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.sm
    implicitWidth: Tokens.spacing.xxl * 10
    opacity: root.enabled ? 1 : 0.38

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.small
        color: root.selected ? Colors.color.secondaryContainer : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.md
        anchors.rightMargin: Tokens.spacing.md
        spacing: Tokens.spacing.md

        MIcon {
            visible: root.iconName.length > 0
            name: root.iconName
            size: Tokens.spacing.xl
            color: root.selected ? Colors.color.onSecondaryContainer : Colors.color.onSurface
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            MText {
                key: root.titleKey
                value: root.titleValue
                styleName: "bodyLarge"
                color: root.selected ? Colors.color.onSecondaryContainer : Colors.color.onSurface
                Layout.fillWidth: true
            }

            MText {
                visible: root.subtitleKey.length > 0 || root.subtitleValue.length > 0
                key: root.subtitleKey
                value: root.subtitleValue
                styleName: "bodySmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
        }

        Item {
            id: trailing
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onDoubleClicked: root.activated()
    }
}
