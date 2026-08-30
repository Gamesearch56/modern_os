import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

Item {
    id: root

    property var actions: []
    property int focusIndex: 0

    signal chosen(int index)
    signal closed()

    property bool _entered: false
    readonly property bool _shown: root._entered

    Component.onCompleted: root._entered = true

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: root._shown ? Tokens.overlay.scrim : 0

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: Motion.easingEmphasized
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    Item {
        id: wrap
        width: card.width
        height: card.height
        anchors.centerIn: parent
        scale: Motion.overlayScale(root._shown)
        opacity: Motion.overlayOpacity(root._shown)
        transformOrigin: Item.Center

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: root._shown
                    ? Motion.easingEmphasizedDecelerate
                    : Motion.easingEmphasizedAccelerate
            }
        }
        Behavior on scale {
            enabled: Motion.overlaysZoom
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: root._shown
                    ? Motion.easingEmphasizedDecelerate
                    : Motion.easingEmphasizedAccelerate
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Rectangle {
            id: card
            width: Tokens.spacing.xxl * 12
            implicitHeight: inner.implicitHeight + Tokens.spacing.lg * 2
            height: implicitHeight
            color: Colors.color.surface
            radius: Tokens.radius.medium
            border.color: Colors.color.outlineVariant
            border.width: Tokens.stroke.hairline
            clip: true
            opacity: Config.design.transparency ?? 0.85

            MIconButton {
                z: 1
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Tokens.spacing.sm
                close: true
                iconName: "window-close"
                key: "bar.close"
                onClicked: root.closed()
            }

            ColumnLayout {
                id: inner
                width: parent.width - Tokens.spacing.lg * 2
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: Tokens.spacing.lg
                spacing: Tokens.spacing.xl

                Header {
                    Layout.fillWidth: true
                }

                Actions {
                    Layout.fillWidth: true
                    actions: root.actions
                    focusIndex: root.focusIndex
                    onChosen: (i) => root.chosen(i)
                }
            }
        }
    }
}
