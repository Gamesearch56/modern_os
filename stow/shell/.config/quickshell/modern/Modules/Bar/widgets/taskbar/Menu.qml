import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root

    parent: Window.window ? Window.window.contentItem : parent
    anchors.fill: parent

    property string menuAddress: ""
    property bool menuBackground: false
    property string menuKind: "window"
    property var menuEntry: null
    property real menuRowY: 0
    property real menuRowH: 0

    signal closed()

    MouseArea {
        z: 20
        anchors.fill: parent
        onClicked: root.closed()
    }

    Item {
        id: menuCard
        z: 21
        width: Tokens.spacing.xxl * 7
        height: menuCol.implicitHeight + Tokens.spacing.xs * 2
        x: Math.max(Tokens.spacing.sm, parent.width - width - Tokens.spacing.sm)
        y: {
            const h = menuCard.height;
            const below = root.menuRowY + root.menuRowH;
            if (below + h + Tokens.spacing.xs <= root.height)
                return below;
            return Math.max(0, root.menuRowY - h);
        }

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radius.small
            color: Colors.color.surfaceContainerHigh
            opacity: Config.design.transparency ?? 0.85
            border.width: Tokens.stroke.hairline
            border.color: Colors.color.outlineVariant
        }

        ColumnLayout {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.spacing.xs
            spacing: 0

            MListItem {
                Layout.fillWidth: true
                compact: true
                iconName: "focus-windows-symbolic"
                titleKey: "bar.taskbarShow"
                onClicked: {
                    const entry = root.menuEntry;
                    root.closed();
                    Taskbar.activate(entry);
                    Popups.dismiss();
                    Taskbar.hide();
                }
            }
            MListItem {
                Layout.fillWidth: true
                compact: true
                visible: !root.menuBackground && root.menuKind === "window"
                iconName: "window-minimize-symbolic"
                titleKey: "bar.taskbarHide"
                onClicked: {
                    const addr = root.menuAddress;
                    root.closed();
                    Hypr.moveToBackground(addr);
                    Popups.dismiss();
                    Taskbar.hide();
                }
            }
            MListItem {
                Layout.fillWidth: true
                compact: true
                visible: root.menuKind === "window"
                iconName: "view-restore-symbolic"
                titleKey: "bar.taskbarFloat"
                onClicked: {
                    const addr = root.menuAddress;
                    root.closed();
                    Hypr.toggleFloating(addr);
                }
            }
            MListItem {
                Layout.fillWidth: true
                compact: true
                visible: root.menuKind === "window"
                iconName: "view-fullscreen-symbolic"
                titleKey: "bar.taskbarFullscreen"
                onClicked: {
                    const addr = root.menuAddress;
                    root.closed();
                    Hypr.toggleFullscreen(addr);
                }
            }
            MListItem {
                Layout.fillWidth: true
                compact: true
                visible: root.menuKind === "window"
                iconName: "window-close-symbolic"
                titleKey: "bar.close"
                destructive: true
                onClicked: {
                    const addr = root.menuAddress;
                    root.closed();
                    Hypr.closeWindow(addr);
                }
            }
        }
    }
}
