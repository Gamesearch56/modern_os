// FloatingWindow chrome: rounded surface + title bar + fill body.
// Settings and Overview share this; overlays use MOverlay.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string titleKey: ""
    property string titleValue: ""
    property string subtitleKey: ""
    property string subtitleValue: ""
    property string actionKey: ""
    property string actionIcon: ""
    property real titleColumnWidth: 0
    property real chromeOpacity: Config.design.transparency ?? 0.85
    property bool busy: false

    signal closed()
    signal actionClicked()

    default property alias body: contentSlot.data

    Rectangle {
        anchors.fill: parent
        color: Colors.color.surface
        radius: Tokens.radius.medium
        border.color: Colors.color.outlineVariant
        border.width: Tokens.stroke.hairline
        clip: true
        opacity: root.chromeOpacity
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.md
        spacing: Tokens.spacing.md

        MWindowChrome {
            Layout.fillWidth: true
            titleKey: root.titleKey
            titleValue: root.titleValue
            subtitleKey: root.subtitleKey
            subtitleValue: root.subtitleValue
            actionKey: root.actionKey
            actionIcon: root.actionIcon
            titleColumnWidth: root.titleColumnWidth
            busy: root.busy
            onClosed: root.closed()
            onActionClicked: root.actionClicked()
        }

        Item {
            id: contentSlot
            Layout.fillWidth: true
            Layout.fillHeight: true

            onChildrenChanged: {
                if (children.length === 1)
                    children[0].anchors.fill = contentSlot;
            }
        }
    }
}
