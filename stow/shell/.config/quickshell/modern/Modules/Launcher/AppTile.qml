import QtQuick
import "../../Commons"
import "../../Services"
import "../../Widgets"

Item {
    id: root

    property string appId: ""
    property string iconName: ""
    property string title: ""
    property bool tint: false
    property bool current: false
    property bool showIcon: true

    signal clicked()

    Accessible.role: Accessible.Button
    Accessible.name: root.title
    Accessible.onPressAction: root.clicked()

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: root.current ? Chrome.tonal.bg : "transparent"
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: Colors.color.primary
        opacity: Chrome.stateLayer(ma.containsMouse && !root.current, ma.pressed)
    }

    Column {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.sm
        spacing: Tokens.spacing.xs

        Item {
            width: parent.width
            height: root.showIcon ? Tokens.icon.lg : 0
            visible: root.showIcon

            MIcon {
                anchors.centerIn: parent
                name: root.iconName.length > 0 ? root.iconName : "application-x-executable"
                size: Tokens.icon.lg
                tint: root.tint
                preferSymbolic: root.tint
                forceLift: root.tint
            }
        }

        MText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            value: root.title
            styleName: "labelMedium"
            color: root.current ? Chrome.tonal.fg : Colors.color.onSurface
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    MDragArea {
        id: ma
        anchors.fill: parent
        canDrag: DockLayout.enabled && root.appId.length > 0
        onTapped: root.clicked()
        onDragBegan: (x, y) => {
            const p = Dock.pointerToScreen(root, "top", x, y);
            const screen = root.Window.window && root.Window.window.screen ? root.Window.window.screen.name : "";
            Dock.beginDrag(root.appId, false, -1, p.x, p.y, screen);
        }
        onDragMoved: (x, y) => {
            const p = Dock.pointerToScreen(root, "top", x, y);
            Dock.moveDrag(p.x, p.y);
        }
        onDragDropped: (x, y) => {
            const p = Dock.pointerToScreen(root, "top", x, y);
            Dock.moveDrag(p.x, p.y);
            Dock.finish();
        }
        onDragCanceled: Dock.cancel()
    }
}
