import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    signal closed()

    property bool _entered: false
    readonly property bool _shown: root._entered

    Component.onCompleted: {
        root._entered = true;
        grid._pendingSync = true;
        grid.syncFromCurrent();
    }

    function moveBy(delta: int) { grid.moveBy(delta); }
    function activate() { grid.activate(); }
    readonly property int columns: grid.columns

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: root._shown ? Tokens.overlay.scrim : 0

        Behavior on opacity {
            enabled: Motion.overlayFades()
            NumberAnimation {
                duration: Motion.medium()
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
            enabled: Motion.overlayFades()
            NumberAnimation {
                duration: Motion.medium()
                easing.bezierCurve: root._shown
                    ? Motion.easingEmphasizedDecelerate
                    : Motion.easingEmphasizedAccelerate
            }
        }
        Behavior on scale {
            enabled: Motion.overlayZooms()
            NumberAnimation {
                duration: Motion.medium()
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
            width: Tokens.spacing.xxl * 22
            implicitHeight: inner.implicitHeight + Tokens.spacing.lg * 2
            height: Math.min(implicitHeight, root.height - Tokens.spacing.xl)
            color: Colors.color.surface
            radius: Tokens.radius.medium
            border.color: Colors.color.outlineVariant
            border.width: Tokens.stroke.hairline
            clip: true
            opacity: Config.design.transparency ?? 0.85

            RowLayout {
                z: 1
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Tokens.spacing.sm
                spacing: Tokens.spacing.xs

                MIconButton {
                    iconName: "list-add-symbolic"
                    key: "wallpaper.add"
                    onClicked: Wallpaper.importWallpaper()
                }
                MIconButton {
                    iconName: "folder-symbolic"
                    key: "wallpaper.openFolder"
                    onClicked: {
                        Wallpaper.hide();
                        Apps.openFolder(Wallpaper.libraryDir);
                    }
                }
                MIconButton {
                    close: true
                    iconName: "window-close"
                    key: "bar.close"
                    onClicked: root.closed()
                }
            }

            ColumnLayout {
                id: inner
                width: parent.width - Tokens.spacing.lg * 2
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: Tokens.spacing.lg
                spacing: Tokens.spacing.md

                Header {
                    Layout.fillWidth: true
                    Layout.rightMargin: Tokens.spacing.xxl * 3 + Tokens.spacing.sm
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Wallpaper.images.length === 0
                        ? Tokens.spacing.xxl * 8
                        : Math.min(grid.contentHeight, Tokens.spacing.xxl * 16)

                    PickerGrid {
                        id: grid
                        anchors.fill: parent
                        visible: Wallpaper.images.length > 0
                    }

                    MEmptyState {
                        visible: Wallpaper.images.length === 0
                        anchors.fill: parent
                        iconName: "folder-pictures-symbolic"
                        titleKey: "wallpaper.empty"
                    }
                }
            }
        }
    }
}
