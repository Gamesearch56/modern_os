import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    signal closed()

    property string pendingRemove: ""
    readonly property bool confirming: root.pendingRemove.length > 0

    function cancelRemove() { root.pendingRemove = ""; }
    function moveBy(delta: int) { grid.moveBy(delta); }
    function activate() { grid.activate(); }
    readonly property int columns: grid.columns

    Component.onCompleted: {
        grid._pendingSync = true;
        grid.resetSelection();
    }

    MWindowShell {
        anchors.fill: parent
        titleKey: "wallpaper.title"
        subtitleKey: "wallpaper.hint"
        onClosed: root.closed()

        trailing: RowLayout {
            spacing: Tokens.spacing.xs

            MIconButton {
                iconName: "list-add-symbolic"
                key: "wallpaper.add"
                onClicked: Wallpaper.importWallpaper()
            }
            MIconButton {
                iconName: "edit-find-symbolic"
                key: "wallpaper.get"
                onClicked: Wallpaper.openProvider()
            }
            MIconButton {
                iconName: "folder-symbolic"
                key: "wallpaper.openFolder"
                onClicked: {
                    Wallpaper.hide();
                    Apps.openFolder(Wallpaper.libraryDir);
                }
            }
        }

        Item {
            PickerGrid {
                id: grid
                anchors.fill: parent
                visible: Wallpaper.images.length > 0
                onRemoveRequested: (path) => { root.pendingRemove = path; }
            }

            MEmptyState {
                visible: Wallpaper.images.length === 0
                anchors.fill: parent
                iconName: "folder-pictures-symbolic"
                titleKey: "wallpaper.empty"
            }
        }
    }

    MDialog {
        anchors.fill: parent
        open: root.confirming
        titleKey: "wallpaper.removeTitle"
        bodyKey: "wallpaper.removeBody"
        confirmKey: "wallpaper.remove"
        cancelKey: "powerMenu.cancel"
        destructive: true
        onConfirmed: {
            Wallpaper.remove(root.pendingRemove);
            root.pendingRemove = "";
        }
        onCancelled: root.cancelRemove()
    }
}
