// Says that the dock goes on past this end. While a pin is dragged out
// of a full dock the far end shows the trash and an arrow, because the
// trash sits after the last pin and starts off screen; holding the pin
// on this end scrolls there. Otherwise a small arrow, which scrolls on tap.
import QtQuick
import "../../Commons"
import "../../Services"
import "../../Widgets"

Item {
    id: root

    property var scroller: null
    property bool atEnd: true
    property bool vertical: false

    readonly property bool _more: !!root.scroller && (root.atEnd
        ? root.scroller.pos < root.scroller.span - 1
        : root.scroller.pos > 1)
    readonly property bool _toTrash: root.atEnd && !!root.scroller && root.scroller.dragging
    readonly property bool _motion: Motion.scale !== 0
    readonly property string _arrow: root.vertical
        ? (root.atEnd ? "go-down-symbolic" : "go-up-symbolic")
        : (root.atEnd ? "go-next-symbolic" : "go-previous-symbolic")

    width: root.vertical ? DockLayout.iconSize : pill.width
    height: root.vertical ? pill.height : DockLayout.iconSize
    visible: opacity > 0
    opacity: root._more && (root._toTrash || !Dock.dragActive) ? 1 : 0
    z: 5
    Accessible.role: Accessible.Button
    Accessible.name: I18n.t(root._toTrash ? "settings.dock.scrollToTrash" : "settings.dock.scrollMore")

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.mediumMs
            easing.type: Easing.InOutQuad
        }
    }

    Rectangle {
        id: pill
        readonly property real _thin: Tokens.spacing.xl
        readonly property real _long: root._toTrash ? DockLayout.iconSize : pill._thin
        anchors.centerIn: parent
        width: root.vertical ? pill._thin : pill._long
        height: root.vertical ? pill._long : pill._thin
        radius: Tokens.radius.full
        color: root._toTrash ? Colors.color.errorContainer : Colors.color.surfaceContainerHighest
        border.width: root._toTrash ? 0 : 1
        border.color: Colors.color.outlineVariant

        transform: Translate {
            id: bob
        }

        Grid {
            anchors.centerIn: parent
            rows: root.vertical ? 2 : 1
            columns: root.vertical ? 1 : 2
            spacing: 0

            MIcon {
                visible: root._toTrash
                name: "user-trash"
                size: Tokens.icon.sm
                color: Colors.color.onErrorContainer
                tint: true
            }
            MIcon {
                name: root._arrow
                size: Tokens.icon.sm
                color: root._toTrash ? Colors.color.onErrorContainer : Colors.color.onSurfaceVariant
                tint: true
            }
        }

        // Points the way to the trash; still while motion is turned off.
        SequentialAnimation {
            running: root._toTrash && root.visible && root._motion
            loops: Animation.Infinite
            onRunningChanged: if (!running) { bob.x = 0; bob.y = 0; }
            NumberAnimation {
                target: bob
                property: root.vertical ? "y" : "x"
                to: Tokens.spacing.xs
                duration: Motion.mediumMs
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: bob
                property: root.vertical ? "y" : "x"
                to: 0
                duration: Motion.mediumMs
                easing.type: Easing.InOutQuad
            }
        }
    }

    TapHandler {
        enabled: !Dock.dragActive && root._more
        onTapped: {
            // Most of a screen, so the last pin seen stays in view.
            const page = (root.vertical ? root.scroller.height : root.scroller.width) * 0.75;
            const d = root.atEnd ? -page : page;
            root.scroller.scrollBy(d, d);
        }
    }
}
