import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

FocusScope {
    id: root
    focus: true

    parent: Window.window ? Window.window.contentItem : parent
    anchors.fill: parent

    property string menuAddress: ""
    property bool menuBackground: false
    property string menuKind: "window"
    property var menuEntry: null
    property real menuRowY: 0
    property real menuRowH: 0
    property int actionIndex: 0

    readonly property var actionIds: {
        void root.menuKind;
        void root.menuBackground;
        const k = ["show"];
        if (!root.menuBackground && root.menuKind === "window")
            k.push("hide");
        if (root.menuKind === "window") {
            k.push("float");
            k.push("full");
            k.push("split");
        }
        k.push("close");
        return k;
    }

    signal closed()
    signal closeApp()

    function _run() {
        const id = (root.actionIds || [])[root.actionIndex];
        const kids = menuCol.children;
        for (let i = 0; i < kids.length; i++) {
            if (kids[i] && kids[i].objectName === id) {
                kids[i].clicked();
                return;
            }
        }
    }

    Keys.onPressed: (event) => {
        const n = (root.actionIds || []).length;
        if (event.key === Qt.Key_Escape) {
            root.closed();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            if (n > 0)
                root.actionIndex = Math.min(n - 1, root.actionIndex + 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.actionIndex = Math.max(0, root.actionIndex - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root._run();
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        root.actionIndex = 0;
        root.forceActiveFocus();
    }

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
                objectName: "show"
                Layout.fillWidth: true
                compact: true
                tabFocus: false
                selected: (root.actionIds || [])[root.actionIndex] === "show"
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
                objectName: "hide"
                Layout.fillWidth: true
                compact: true
                tabFocus: false
                selected: (root.actionIds || [])[root.actionIndex] === "hide"
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
                objectName: "float"
                Layout.fillWidth: true
                compact: true
                tabFocus: false
                selected: (root.actionIds || [])[root.actionIndex] === "float"
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
                objectName: "full"
                Layout.fillWidth: true
                compact: true
                tabFocus: false
                selected: (root.actionIds || [])[root.actionIndex] === "full"
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
                objectName: "split"
                Layout.fillWidth: true
                compact: true
                tabFocus: false
                selected: (root.actionIds || [])[root.actionIndex] === "split"
                visible: root.menuKind === "window"
                iconName: "view-dual-symbolic"
                titleKey: "bar.taskbarSplit"
                onClicked: {
                    const addr = root.menuAddress;
                    root.closed();
                    Hypr.toggleSplit(addr);
                }
            }
            MListItem {
                objectName: "close"
                Layout.fillWidth: true
                compact: true
                tabFocus: false
                selected: (root.actionIds || [])[root.actionIndex] === "close"
                visible: true
                iconName: "window-close-symbolic"
                titleKey: "bar.close"
                destructive: true
                onClicked: root.closeApp()
            }
        }
    }
}
