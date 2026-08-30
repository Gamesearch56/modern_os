import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

Item {
    id: root

    property string query: ""
    property string categoryId: "applications"

    signal queryEdited(string text)
    signal picked(string id)
    signal closed()

    property bool _entered: false
    readonly property bool _shown: root._entered

    Component.onCompleted: root._entered = true

    function focusSearch() {
        nav.focusSearch();
    }

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
            width: Tokens.spacing.xxl * 24
            height: Math.min(Tokens.spacing.xxl * 20, root.height - Tokens.spacing.xl)
            color: Colors.color.surfaceContainer
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
                anchors.fill: parent
                anchors.margins: Tokens.spacing.lg
                spacing: Tokens.spacing.xl

                Header {
                    Layout.fillWidth: true
                    Layout.rightMargin: Tokens.spacing.xxl
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.xxl

                    Nav {
                        id: nav
                        Layout.preferredWidth: Tokens.spacing.xxl * 8
                        Layout.fillHeight: true
                        categoryId: root.categoryId
                        onQueryEdited: (t) => root.queryEdited(t)
                        onPicked: (id) => root.picked(id)
                    }

                    Binds {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        query: root.query
                        categoryId: root.categoryId
                    }
                }
            }
        }
    }
}
