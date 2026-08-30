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
                anchors.fill: parent
                anchors.margins: Tokens.spacing.lg
                spacing: Tokens.spacing.xl

                Header {
                    Layout.fillWidth: true
                    Layout.rightMargin: Tokens.spacing.xxl * 3 + Tokens.spacing.sm
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

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
