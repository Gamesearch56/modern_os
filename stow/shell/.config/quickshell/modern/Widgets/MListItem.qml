// One row in a list (launcher results, settings search, cheatsheet
// shortcuts, device lists). Icon + title + optional subtitle + trailing
// slot. Highlight follows keyboard focus, not just hover.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string iconName: ""
    property bool tintIcon: true
    property string titleKey: ""
    property string titleValue: ""
    property string subtitleKey: ""
    property string subtitleValue: ""
    property bool selected: false
    property bool enabled: true

    default property alias extra: trailing.data

    signal clicked()
    signal activated()

    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.md * 2
    implicitWidth: Tokens.spacing.xxl * 10
    opacity: root.enabled ? 1 : 0.38

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.small
        color: root.selected ? Colors.color.primaryContainer : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.md
        anchors.rightMargin: Tokens.spacing.md
        anchors.topMargin: Tokens.spacing.md
        anchors.bottomMargin: Tokens.spacing.md
        spacing: Tokens.spacing.md

        MIcon {
            visible: root.iconName.length > 0
            name: root.iconName
            size: Tokens.spacing.xl
            tint: root.tintIcon
            color: root.selected ? Colors.color.onPrimaryContainer : Colors.color.onSurface
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            MText {
                key: root.titleKey
                value: root.titleValue
                styleName: "bodyLarge"
                color: root.selected ? Colors.color.onPrimaryContainer : Colors.color.onSurface
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
            visible: children.length > 0
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
